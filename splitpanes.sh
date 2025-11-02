#!/bin/bash
# Name: splitpanes.sh
# Author: R.J.Toscani
# Date: 12th of October 2025
# Description:
# Splitting of selected file-manager window-pane into two side-by-side panes showing
# same directory, sharing same total area and position as a pair as before splitting.
# Repeated splitting is supported. Each pair of split panes is actually two new windows
# replacing their parent window.
# The program takes the (current) directory (within the active file manager window)
# as an argument. The active file manager window itself is being derived by the program
# by finding its parent's process-ID and subsequently the related window-ID.
#
# Meant to be launched from the tools-menu of the file-manager named 'XFile' (part of 
# 'Enhanced Motif Window Manager' by Alexander Pampuchin
# - https://fastestcode.org/ - LGPLv3, MIT License).
#
# Option -u re-unites all (recursively) split panes in the directory of the selected pane,
# in size and position of the original window, i.e. the first one from which the splitting
# sequence started, and not a result of splitting itself.
#
# XFile tools-menu items for splitting and uniting by splitpanes.sh could be
# accelerated by assigning e.g. F8 and F9 keys respectively.
#
# Prerequisites:
# - xfile
# - xdotool
# - wmctrl
#
######################################################################################
#
# Copyright (C) 2025 Rob Toscani <rob_toscani@yahoo.com>
#
# splitpanes.sh is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# splitpanes.sh is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
######################################################################################


mode="split"

options(){
# Specify options:
    while getopts "hu" OPTION; do
        case $OPTION in
            h) helptext
               exit 0
               ;;
            u) mode="unite"
               ;;
            *) helptext
               exit 1
               ;;
        esac
    done
}

helptext()
# Text printed if -h option (help) or a non-existent option has been given:
{
    while read "line"; do
        echo "$line" >&2          # Print to standard error (stderr)
    done << EOF
Usage: splitpanes.sh [-hu] DIRECTORY

-h   Help (this output)
-u   Re-unite all split panes in selected directory in size and position of original window
EOF
}

options $@
shift $(( OPTIND - 1 ))


# Determine storage location of the relations-file (preferrably RAM):
if [[ -d /tmp/ramdisk/ ]]; then
    tmpfiledir="/tmp/ramdisk"
elif [[ -d /dev/shm/ ]]; then
    tmpfiledir="/dev/shm"
else
    tmpfiledir="$HOME"
fi

# Current directory:
directory="$1"

# Keep track of any split file-manager windows and their common parent window's geometry:
relationsfile="$tmpfiledir/split_relations.txt"

# Process ID of parent window:
process_id=$(ps -o ppid= $$)
process_id=${process_id// /}  # (Apparently necessary, but variable still doesn't print ?)

# Window ID (decimal) of active parent window:
windowid_dec=$(xdotool getactivewindow)

# Window ID (hexadecimal) of active parent window:
windowid_hex=$(printf '%x\n' $windowid_dec)

# Determine whether we will be splitting or uniting:
if [[ $mode == "unite" ]]; then

    # ############ "Uniting"-code starts here: ############

    # Search in relations-file for line containing the active window PID:
    relatedpanes=($(grep $process_id "$relationsfile"))
    [[ "$relatedpanes" == "" ]] && exit

    # Get geometry (position and size) of original (unsplit) window from which it originated:
    geom=${relatedpanes[0]}

    # Start new file-manager window with current directory and original (unsplit) geometry:
    xfile -a -l -geometry "$geom" "$directory" &

    # Kill all process-IDs found in the same line, all being the related split windows:
    for i in ${!relatedpanes[@]}; do
         [[ $i == 0 ]] && continue
         kill -9 ${relatedpanes[$i]} 2>/dev/null
    done

    # Terminate the program:
    exit

fi

# ############ "Splitting"-code starts here: ############

# Get geometric properties of the active (parent) file-manager window:
geom=($(wmctrl -lG | grep "$windowid_hex" | awk '{ print $5, $6, $3, $4 }'))
w=${geom[0]}
h=${geom[1]}
x=${geom[2]}
y=${geom[3]}

# Get side- and top-edge decoration-frame dimensions:
edges=($(xprop -id "0x"$windowid_hex | grep -m1 FRAME_EXTENTS | \
               awk 'BEGIN { FS="," } { print $(NF-2), $(NF-1) }'))
side=${edges[0]}
top=${edges[1]}

# Set DE-dependent shift values for window-origin correction (empirically found):
xshift=0
yshift=0
case $DESKTOP_SESSION in
    LXDE | xfce | openbox)
            xfactor=2
            yfactor=2
            ;;
    ubuntu)
            xfactor=1
            yfactor=2
            xshift=14
            yshift=12
            ;;
    *)
            xfactor=1
            yfactor=1
            ;;
esac

# Derive geometric properties of child file-manager windows to be resulting from splitting:
(( x = x - xfactor * side - xshift )) # x-position corrected for side-edge dimension
(( y = y - yfactor * top  - yshift )) # y-position corrected for top-edge dimension
(( ws = (w - side) / 2 ))             # Split pane widths corrected for side-edge
(( x2 = x + ws + side ))              # Right pane's x-position corrected for side-edge
geom1="$ws"x"$h"+"$x"+"$y"
geom2="$ws"x"$h"+"$x2"+"$y"

# Create relations-file unless it already exists:
[[ ! -f "$relationsfile" ]] && touch "$relationsfile" && chmod 600 "$relationsfile"

# If current (parent) PID is not in relations-file, append new line with PID and geometry:
if ! grep -q $process_id $relationsfile; then
    echo "$w"x"$h"+"$x"+"$y" $process_id >> $relationsfile
fi

# All related process-IDs before launching the new split file-manager windows:
pre_pids="$(ps aux --sort start | grep xfile | awk '{ print $2 }')"

# Launch the two new split file-manager windows:
xfile -a -l -geometry "$geom1" "$directory" &
xfile -a -l -geometry "$geom2" "$directory" &

# All related process-IDs after launching the new split file-manager windows:
post_pids="$(ps aux --sort start | grep xfile | awk '{ print $2 }')"

# The new PID(s) related to the new split file-manager windows:
new_pids=$(comm -23 <(echo "$post_pids" | sort) <(echo "$pre_pids" | sort) | tr '\n' ' ')

# In the relations-file, replace active (parent) PID by the PIDs of both new split windows:
sed -i "s/$process_id/$new_pids/" $relationsfile

# Kill the active (parent) file-manager window:
kill -9 $process_id 2>/dev/null

