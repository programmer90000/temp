#!/bin/bash

# This works better in tmux 3.2+
SESSION_ID=$(tmux display-message -p '#{session_id}')

# Store mouse position in a tmux option right when clicked
tmux set -g @menu_mouse_x #{mouse_x} 2>/dev/null || true
tmux set -g @menu_mouse_y #{mouse_y} 2>/dev/null || true

# Get the stored position
MOUSE_X=$(tmux show -gv @menu_mouse_x 2>/dev/null || echo "10")
MOUSE_Y=$(tmux show -gv @menu_mouse_y 2>/dev/null || echo "5")

STATE_FILE="/tmp/tmux-menu-$SESSION_ID"

if [ -f "$STATE_FILE" ]; then
    tmux kill-pane -t '{menu}' 2>/dev/null
    rm -f "$STATE_FILE"
    exit 0
fi

echo "1" > "$STATE_FILE"

tmux display-popup \
    -w 20 \
    -h 6 \
    -x $MOUSE_X \
    -y $MOUSE_Y \
    -E "
        selected=0
        opts=('Copy' 'Paste')
        
        while true; do
            clear
            echo
            for i in \${!opts[@]}; do
                if [ \$i -eq \$selected ]; then
                    echo '  ▶ \${opts[\$i]}'
                else
                    echo '    \${opts[\$i]}'
                fi
            done
            echo
            
            # Read key
            IFS= read -rsn1 key
            [[ \$key == \"\" ]] && key=\"ENTER\"
            
            # Arrow keys
            if [[ \$key == \$'\\x1b' ]]; then
                read -rsn2 seq
                case \$seq in
                    '[A') selected=\$((selected - 1)); continue ;;
                    '[B') selected=\$((selected + 1)); continue ;;
                esac
            fi
            
            # Handle selection
            case \$key in
                'ENTER')
                    case \$selected in
                        0) tmux copy-mode ;;
                        1) tmux paste-buffer ;;
                    esac
                    break
                    ;;
                *)
                    break
                    ;;
            esac
            
            # Keep selected in bounds
            if [ \$selected -lt 0 ]; then selected=0; fi
            if [ \$selected -ge \${#opts[@]} ]; then selected=\$((\${#opts[@]} - 1)); fi
        done
        rm -f '$STATE_FILE'
    "

rm -f "$STATE_FILE" 2>/dev/null
