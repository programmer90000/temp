#!/bin/bash

# Get current pane dimensions
PANE_WIDTH=$(tmux display-message -p "#{pane_width}")
PANE_HEIGHT=$(tmux display-message -p "#{pane_height}")

# Menu position (centered)
MENU_WIDTH=30
MENU_HEIGHT=4
MENU_X=$(( (PANE_WIDTH - MENU_WIDTH) / 2 ))
MENU_Y=$(( (PANE_HEIGHT - MENU_HEIGHT) / 2 ))

# Create a temporary window for the menu
tmux display-menu -T "#[align=centre]Select Option" \
    -x $MENU_X -y $MENU_Y \
    "" \
    "Option 1" "" "run-shell 'echo \"Option 1 selected\"'" \
    "Option 2" "" "run-shell 'echo \"Option 2 selected\"'" 
