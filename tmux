set -g history-limit 50000
set -g mouse on

# Make splitting and resizing panes, and moving around emulate the vim
# directional keys
bind | split-window -h
bind _ split-window -v
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# Remove the escape key delay. This will speed up vim interaction in most
# cases.
set -sg escape-time 0


# For easy reload of the tmux config
bind-key r source-file ~/.tmux.conf

#
# Colors and status line adapted from:
# http://zanshin.net/2013/09/05/my-tmux-configuration/
#

# make tmux display things in 256 colors
set -g default-terminal "screen-256color"

# ----------------------
# set some pretty colors
# ----------------------

# colorize messages in the command line
set-option -g message-style bg=black,fg=brightred

# ----------------------
# Status Bar
# -----------------------
set-option -g status on                # turn the status bar on
set -g status-interval 5               # set update frequencey (default 15 seconds)
set -g status-justify centre           # center window list for clarity

# visual notification of activity in other windows
setw -g monitor-activity on
set -g visual-activity on

# set color for status bar
set-option -g status-style bg=colour235,fg=yellow,dim

# set window list colors - red for active and cyan for inactive
set-window-option -g window-status-style fg=brightblue,bg=colour236,dim

set-window-option -g window-status-current-style fg=brightred,bg=colour236,bright

# show host name and IP address on left side of status bar
set -g status-left-length 70
set -g status-left "#[fg=yellow]#(echo ${USER}) : #[fg=green]#h"

# show session name, window & pane number, date and time on right side of
# status bar
set -g status-right-length 60
set -g status-right "#[fg=blue]#S #I:#P #[fg=green]%k:%M:%S (#(date -u | awk '{print $4}') UTC)"
