#!/bin/bash

# Get mouse position relative to pane
# Note: tmux 3.2+ can get mouse position with #{mouse_x} and #{mouse_y}
MOUSE_X=$(tmux display-message -p '#{mouse_x}')
MOUSE_Y=$(tmux display-message -p '#{mouse_y}')

# State tracking
STATE_DIR="/tmp/tmux-menu"
mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/state-$(tmux display-message -p '#{session_id}-#{window_id}-#{pane_id}')"

# Function to clean up
cleanup() {
    rm -f "$STATE_FILE"
    exit 0
}

# If menu already showing, close it
if [ -f "$STATE_FILE" ]; then
    tmux kill-pane -t '{menu}' 2>/dev/null
    rm -f "$STATE_FILE"
    exit 0
fi

# Mark as showing
echo "1" > "$STATE_FILE"

# Calculate popup position (centered around mouse)
# Adjust these values to change popup size
POPUP_WIDTH=20
POPUP_HEIGHT=6

# Create the popup - using -d to pass initial position
tmux display-popup \
    -w $POPUP_WIDTH \
    -h $POPUP_HEIGHT \
    -x $((MOUSE_X - POPUP_WIDTH/2)) \
    -y $((MOUSE_Y - POPUP_HEIGHT/2)) \
    -E "
        # Trap signals to ensure cleanup
        trap 'exit 0' INT TERM
        
        # Menu items
        menu_items=('Copy' 'Paste')
        selected=0
        
        # Function to display menu
        display_menu() {
            clear
            for i in \${!menu_items[@]}; do
                if [ \$i -eq \$selected ]; then
                    echo \"▶ \${menu_items[\$i]}\"
                else
                    echo \"  \${menu_items[\$i]}\"
                fi
            done
        }
        
        # Initial display
        display_menu
        
        # Main loop
        while true; do
            # Read single key (including arrows)
            IFS= read -rsn1 key
            
            # Handle escape sequences (arrows)
            if [[ \$key == \$'\\x1b' ]]; then
                read -rsn2 -t 0.1 key2
                key=\$key\$key2
            fi
            
            case \$key in
                # Up arrow
                \$'\\x1b[A')
                    selected=\$(( (selected - 1 + \${#menu_items[@]}) % \${#menu_items[@]} ))
                    display_menu
                    ;;
                    
                # Down arrow
                \$'\\x1b[B')
                    selected=\$(( (selected + 1) % \${#menu_items[@]} ))
                    display_menu
                    ;;
                    
                # Enter/Return
                \"\")
                    # Execute action based on selection
                    case \$selected in
                        0)  # Copy
                            tmux copy-mode
                            # If in copy mode already, copy selection
                            if tmux display-message -p '#{pane_in_mode}' | grep -q '1'; then
                                tmux send-keys -X copy-selection-and-cancel
                            fi
                            ;;
                        1)  # Paste
                            tmux paste-buffer
                            ;;
                    esac
                    cleanup
                    ;;
                    
                # Any other key or mouse click outside will close
                *)
                    cleanup
                    ;;
            esac
        done
    "

# Cleanup after popup closes
rm -f "$STATE_FILE"
