#!/bin/bash

# We need to capture mouse position BEFORE opening the popup
# This is tricky because tmux clears mouse position after event

# Better approach: Use window/pane-relative positioning
SESSION_ID=$(tmux display-message -p '#{session_id}')
WINDOW_ID=$(tmux display-message -p '#{window_id}')
PANE_ID=$(tmux display-message -p '#{pane_id}')

STATE_FILE="/tmp/tmux-menu-$SESSION_ID-$WINDOW_ID-$PANE_ID"

# Close if already open
if [ -f "$STATE_FILE" ]; then
    tmux kill-pane -t '{menu}' 2>/dev/null
    rm -f "$STATE_FILE"
    exit 0
fi

# Mark as open
echo "1" > "$STATE_FILE"

# We'll use the current pane's position as reference
# Get pane top-left coordinates
PANE_X=$(tmux display-message -p '#{pane_left}')
PANE_Y=$(tmux display-message -p '#{pane_top}')

# Estimate mouse position (center of pane as fallback)
MOUSE_X=$((PANE_X + 10))
MOUSE_Y=$((PANE_Y + 5))

# Small menu size
MENU_WIDTH=20
MENU_HEIGHT=6

# Calculate position (try to keep within pane bounds)
FINAL_X=$MOUSE_X
FINAL_Y=$MOUSE_Y

# Create popup
tmux display-popup \
    -w $MENU_WIDTH \
    -h $MENU_HEIGHT \
    -x $FINAL_X \
    -y $FINAL_Y \
    -E "
        # Simple menu with arrow navigation
        selected=0
        options=('Copy' 'Paste')
        
        show_menu() {
            clear
            printf '\\n'
            for i in \${!options[@]}; do
                if [ \$i -eq \$selected ]; then
                    printf '  \\033[1;36m▶ %s\\033[0m\\n' \"\${options[\$i]}\"
                else
                    printf '    %s\\n' \"\${options[\$i]}\"
                fi
            done
            printf '\\n'
        }
        
        show_menu
        
        while IFS= read -rsn1 key; do
            # Check for escape sequences (arrows)
            if [[ \$key == \$'\\x1b' ]]; then
                read -rsn2 -t 0.1 seq
                case \$seq in
                    '[A')  # Up arrow
                        selected=\$(( (selected - 1 + \${#options[@]}) % \${#options[@]} ))
                        show_menu
                        continue
                        ;;
                    '[B')  # Down arrow
                        selected=\$(( (selected + 1) % \${#options[@]} ))
                        show_menu
                        continue
                        ;;
                esac
            fi
            
            # Enter key
            if [[ -z \$key ]]; then
                case \$selected in
                    0)
                        # Enter copy mode or copy selection
                        if tmux display-message -p '#{pane_in_mode}' | grep -q '1'; then
                            tmux send-keys -X copy-selection-and-cancel
                        else
                            tmux copy-mode
                        fi
                        ;;
                    1)
                        tmux paste-buffer
                        ;;
                esac
                break
            fi
            
            # Any other key closes
            break
        done
        
        # Cleanup
        rm -f '$STATE_FILE' 2>/dev/null
    "

# Cleanup if popup didn't clean itself
rm -f "$STATE_FILE" 2>/dev/null
