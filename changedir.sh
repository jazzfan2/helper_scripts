#!/bin/bash
# Name: changedir.sh
# Author: R.J.Toscani
# Date: 14th of October 2025
# Description:
# Change to specified directory, seemingly in the same active file-manager
# window, but actually by launching a new file-manager window of similar
# position and size as before changing directory, replacing the previous
# window.
#
# The program takes the to-be-specified directory as an argument. The
# active file-manager window is being derived by the program by finding
# its parent's process-ID and subsequently the related window-ID.
#
# 'changedir.sh' finds the active file manager window by its process-
# and window-ID, and keeps track of whether or not the window was a
# result of splitting by the program 'splitpanes.sh', enabling re-uniting
# with related (split) windows. It does so by consulting and editing the
# latter programs's so-called 'relations-file' if present.
#
# Meant to be launched from the tools-menu of the file-manager named
# 'XFile (part of the 'Enhanced Motif Window Manager (EMWM)' by Alexander
# Pampuchin - https://fastestcode.org/ - LGPLv3, MIT License), one for
# each to-be-specified directory which is taken as the argument.
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
# changedir.sh is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# changedir.sh is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
######################################################################################


# Determine where the relations-file will be found:
if [[ -d /tmp/ramdisk/ ]]; then
    tmpfiledir="/tmp/ramdisk"
elif [[ -d /dev/shm/ ]]; then
    tmpfiledir="/dev/shm"
else
    tmpfiledir="$HOME"
fi

# Specified directory:
directory="$1"

# Time lapse to improve seamless window transition in case of a slow machine:
lapse=0.5

# Keep track of any split file-manager windows and their common parent window's geometry:
relationsfile="$tmpfiledir/split_relations.txt"

# Process ID of parent window:
process_id=$(ps -o ppid= $$)
process_id=${process_id// /} # (Apparently necessary, but variable still doesn't print ?)

# Window ID (decimal) of active parent window:
windowid_dec=$(xdotool getactivewindow)

# Window ID (hexadecimal) of active parent window:
windowid_hex=$(printf '%x\n' $windowid_dec)

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

# Get new file-manager window (x,y)-coordinates:
(( x = x - xfactor * side - xshift )) # x-position corrected for side-edge dimension
(( y = y - yfactor * top  - yshift )) # y-position corrected for top-edge dimension
geom="$w"x"$h"+"$x"+"$y"

# All related process-IDs before launching a new file-manager window:
pre_pids="$(ps aux --sort start | grep xfile | awk '{ print $2 }')"

# Launch a file-manager window:
xfile -a -l -geometry "$geom" "$directory" &

# All related process-IDs after launching the new file-manager window:
post_pids="$(ps aux --sort start | grep xfile | awk '{ print $2 }')"

# The new PID(s) related to the new file-manager window:
new_pids=$(comm -23 <(echo "$post_pids" | sort) <(echo "$pre_pids" | sort) | tr '\n' ' ')

# If a (split_pane.sh) relations-file exists:
if [[ -f "$relationsfile" ]]; then

    # Replace the active window's PID - if present there - by the new window's PID(s):
    sed -i "s/$process_id/$new_pids/" $relationsfile
fi

# Kill the active (parent) file-manager window:
sleep $lapse
kill -9 $process_id

