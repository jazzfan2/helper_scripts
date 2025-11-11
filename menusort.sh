#!/bin/bash
# Name: menusort.sh
# Author: R.J.Toscani
# Date: November 11, 2025
# Description:
# This program is meant as a configuration tool in support of the file manager
# called 'XFile' (part of the 'Enhanced Motif Window Manager (EMWM)'
# by Alexander Pampuchin - https://fastestcode.org/ - LGPLv3, MIT License).
#
# It calculates the values for the 'positionIndex' resources in
# $HOME/.app-defaults/Xfile as to achieve the correct items-sequence in the
# XFile tools-menu. That is: resembling the sequence in which the 'labelString'
# resources appear in above mentioned-file - the convention for 'desired order'
# of appearance as used by this program.
#
# Caveat: sorting is dependant upon the options given to XFile. This means that
# desired sorting takes effect as intended *only if* the 'xfile_options' variable
# set in this program ressembles the (combination of) XFile options given to your
# typical use (e.g. as set in $HOME/.toolboxrc). By default in this program,
# options -a and -l are used, but as a consequence to the above these may have to
# be modified dependant upon your typical use.
#
# Prerequisites for this program:
# - python3
# - flameshot
# - gocr
# - levenshtein.py (Copyright Jamiel Rahi GPL 2019), to be downloaded from:
#     https://github.com/jamfromouterspace/levenshtein/blob/master/levenshtein.py
#     to $HOME/scripts/ and make executable.
#
# (Considering converting this program into python or awk for better speed.)
#
######################################################################################
#
# Copyright (C) 2025 Rob Toscani <rob_toscani@yahoo.com>
#
# menusort.sh is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# menusort.sh is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
######################################################################################


# Determine where the temporary Xfile copy can be created:
if [[ -d /tmp/ramdisk/ ]]; then
    tmpfiledir="/tmp/ramdisk/"
elif [[ -d /dev/shm/ ]]; then
    tmpfiledir="/dev/shm/"
fi

xfile="$HOME/.app-defaults/XFile"
menulist1="$tmpfiledir/menulist1_$RANDOM"
menulist2="$tmpfiledir/menulist2_$RANDOM"
image="$tmpfiledir/toolsmenu.png"


levenshtein()
# Measure the so-called 'levenshtein-distance' between two text strings taken as two arguments:
{
    python3 -c "import sys;                            \
                sys.path.insert(0, \"$HOME/scripts\"); \
                import levenshtein;                    \
                print(int(levenshtein.levenshtein(sys.argv[1], sys.argv[2])))" "$1" "$2"
}

flamecheck()
# Have flameshot quit upon finishing its job. Necessary because of the "flameshot delay":
{
     while true; do
         if ps aux | grep -v grep | grep -q "flameshot"; then
             if [[ -f $image ]]; then
                 sleep 1
                 pkill flameshot 2>/dev/null
                 return
             fi
         fi
         sleep 1
     done
}

# Set Xfile-options to reflect those being used typically (e.g. in $HOME/.toolboxrc):
xfile_options="-a -l"  # These are the options specified for xfile in my own $HOME/.toolboxrc)

# Delete previous tools-menu image if present:
[[ -f $image ]] && \rm $image

# Backup $HOME/.app-defaults/XFile, and modify it by setting all positionIndex values to 0:
\cp "$xfile" "$xfile"_
sed -Ei 's/positionIndex: [0-9]+/positionIndex: 0/' "$xfile"

# Store <action>.<labelString> lines (in labelString order of appearance) into 'menulist1':
grep "^XFile.*labelString" "$xfile" |
sed -E 's/.*toolsMenu\.(.+)\.labelString:( |	)*(.*)/\1.\3/' > $menulist1

# Count the number of actions:
actioncount=$(wc -l $menulist1 | awk '{ print $1 }')

# Print the instruction for screen-capturing the tools-menu pop-up:
clear
while read line; do
    echo $line
done << EOF
Menusort.sh - by Rob Toscani (2025 GPL3)

Proceed as follows:

1. Within 10 seconds, click on 'Tools' in the 'XFile'-window just started on the top left...

2. Wait for Flameshot (transparent) to open...

3. In Flameshot:
-  Click on: "Mouse - Select screenshot area";
-  Select SMALLEST POSSIBLE AREA around all toolsmenu-labels;
-  Press <ENTER> or tick the box.

(Enter <Ctrl-C> (2x) to interrupt)
EOF

# Open Xfile window with SAME OPTIONS as typically used:
xfile $xfile_options -geometry 400x800+0+0 $HOME/PDF & xfilepid=$!

# Make sure that flameshot doesn't delay the program:
flamecheck &

# Take a sceenschot of the tools-menu popup:
flameshot gui -d 10000 -p $image 2>/dev/null

# Close Xfile window:
kill -9 $xfilepid 2>/dev/null

# Do a text-recognition on the tools-menu popup just screen-captured, and save results to 'menulist2':
gocr -l 90 -a 70 -C A-Za-z\(\)-- $image | grep -v "^[^a-zA-Z0-9]*$" > "$menulist2"
# (Lines without alphanumerical characters have been filtered away.)

# Count its number of lines:
linecount=$(wc -l "$menulist2" | awk '{ print $1 }')

# Number of lines should be the same as the number of actions, otherwise exit:
(( $linecount != $actioncount )) && echo "Wrong line count" && exit 1

# Create array containing actions in same sequence as their *captured* labels appear on the screen:
echo -e "\e[1A\e[KJust a moment please, the sequence is being calculated...\n"
screen_order=()
i=0
while read menuline2; do
    smallest=100000
    while read menuline1; do
        distance=$(levenshtein "${menuline1/*./}" "$menuline2")
        if (( distance < smallest )); then
            smallest=$distance
            action=${menuline1/.*/}
        fi
        screen_order[i]=$action
    done < "$menulist1"
    echo -e "\e[1A\e[K$(( i + 1 )) of $actioncount items calculated"  # Actually: "recognized"!
    ((i += 1 ))
done < "$menulist2"

# Create associative array in which key = action, and value = desired order-position (0 = top):
declare -A desired_order
i=0
while read menuline1; do
    desired_order[${menuline1/.*/}]=$i
    (( i += 1 ))
done < $menulist1

# Create non-associative array of all desired order-positions already visited:
visited_orders=()

# Create associative array in which key = action, and value = stack-position (0 = bottom):
declare -A stack_positions
((i = linecount - 1 ))
k=0
while ((i >= 0 )); do
    j=0
    stackpos=0
    action=${screen_order[$i]}
    while (( j < ${#visited_orders[@]} )); do
        if (( visited_orders[$j] < desired_order[$action] )); then
            (( stackpos += 1 ))
        fi
        (( j += 1 ))
    done
    (( stack_positions[$action] = stackpos        ))
    (( visited_orders[$k] = desired_order[$action] ))
    (( i -= 1 ))
    (( k += 1 ))
done

# For all actions, substitute position index value (= 0) by stack-position value:
for action in ${!stack_positions[@]}; do
    sed -Ei "/$action\.positionIndex/s/: 0/: ${stack_positions[$action]}/" "$xfile"
done
echo "Done!"