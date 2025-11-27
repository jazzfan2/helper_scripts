#!/usr/bin/env python3
# Name: menusort.py
# Author: R.J.Toscani
# Date: November 14, 2025
# Description:
# This program is meant as a configuration tool in support of the file manager
# called 'XFile' (part of the 'Enhanced Motif Window Manager (EMWM)'
# by Alexander Pampuchin - https://fastestcode.org/ - LGPLv3, MIT License).
#
# It calculates how to manipulate the values for the 'positionIndex' resources in
# ~/.app-defaults/XFile or ~/.Xresources, as to achieve the desired sorting order
# ('ranking') in the XFile tools-menu (as this can not be set in a more direct
# manner).
# The sequence in which the 'labelString' resources appear in any of the
# above-mentioned files is taken by 'menusort.py' as the basis for the desired
# ranking.
#
# Caveat: sorting is dependant upon the options given to XFile. This means that
# sorting takes effect as intended *only if* the 'xfile_options' variable set in
# this program resembles the (combination of) XFile options given to your
# typical use (e.g. as set in $HOME/.toolboxrc). By default in this program,
# options -a and -l are used, but as a consequence to the above these may have to
# be modified dependant upon your typical use.
#
# Prerequisites for this program:
# - flameshot
# - gocr
# - levenshtein.py (Copyright Jamiel Rahi GPL 2019), to be downloaded from:
#     https://github.com/jamfromouterspace/levenshtein/blob/master/levenshtein.py
#     to $HOME/scripts/ and made executable.
#
# The specified number of 'action'-, 'labelString'- and positionIndex'-resources
# in ~/.app-defaults/XFile or ~/.Xresources must be equal.
#
######################################################################################
#
# Copyright (C) 2025 Rob Toscani <rob_toscani@yahoo.com>
#
# menusort.py is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# menusort.py is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAmenusort.pyR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
######################################################################################

import sys
import os
import random
sys.path.insert(0, "/home/rob/scripts")
from levenshtein import levenshtein; 

# Determine the (preferrably RAM-) directory for temporary files:
if os.path.exists("/tmp/ramdisk/"):
    tmpfiledir = "/tmp/ramdisk"
elif os.path.exists("/dev/shm/"):
    tmpfiledir = "/dev/shm"
else:
    tmpfiledir = "."

resources      = "$HOME/.app-defaults/XFile"   # Could also be: "$HOME/.Xresources"
resources_copy = resources + "_"
menufile1      = tmpfiledir + "/menufile1_" + str(random.randint(1,10000))
menufile2      = tmpfiledir + "/menufile2_" + str(random.randint(1,10000))
menufile3      = tmpfiledir + "/menufile3_" + str(random.randint(1,10000))
image          = tmpfiledir + "/toolsmenu.png"
xfile_pid      = tmpfiledir + "/pid" + str(random.randint(1,10000))

# Set Xfile-options to reflect those being used typically (e.g. in $HOME/.toolboxrc):
xfile_options = "-a -l"  # These are options specified for xfile in my own $HOME/.toolboxrc)

# Delete previous tools-menu image if present:
if os.path.exists(image):
    os.remove(image)

# Backup $HOME/.app-defaults/XFile, and modify it by setting all positionIndex values to 0:
os.system('\\cp '+ resources + " " + resources_copy)
os.system('sed -Ei \"s/positionIndex: [0-9]+/positionIndex: 0/\" ' + resources)

# Store <action>@<labelString> lines, in 'labelString' order of appearance:
os.system('grep \"^XFile.*labelString\" ' + resources + ' |                   \
           sed -E \"s/.*toolsMenu\\.(.+)\\.labelString:( |	)*(.*)/\\1@\\3/\" \
           >| ' + menufile1)

# Convert this to a list of <action>@<labelString> relations:
with open(menufile1) as f:
    menulist1 = [ x for x in f.read().splitlines() ]

# Print the instruction for screen-capturing the tools-menu pop-up:
os.system('clear')
print("""
Menusort.sh - by Rob Toscani (C) 2025 GPL3

Proceed as follows:

1. Within 5 seconds, click on 'Tools' in the 'XFile'-window just started on the top left...

2. Wait for Flameshot (transparent) to open...

3. In Flameshot:
-  Click on: \"Mouse - Select screenshot area\";
-  Select SMALLEST POSSIBLE AREA around all tools-menu labels;
-  Press <ENTER> or tick the box.

(Enter <Ctrl-C> (2x) to interrupt)
""")

# Open Xfile window with SAME OPTIONS as typically used, and store its process-id:
os.system('/usr/bin/xfile ' + xfile_options + ' -geometry 400x800+0+0 / & \
           echo $! >| ' + xfile_pid)

# Restore the original positionIndex values in case the program terminates prematurely:
os.system('(sleep 1; \\cp '+ resources_copy + " " + resources + ' &)')

# Have flameshot quit upon finishing its job. Necessary because of the "flameshot delay":
os.system('                               \
flamewatch(){                             \
    while true; do                        \
        if [ -f ' + image + ' ]; then     \
            sleep 1;                      \
            pkill flameshot 2>/dev/null;  \
            return;                       \
        fi;                               \
        sleep 1;                          \
    done;                                 \
};                                        \
flamewatch &')

# Take a sceenschot of the tools-menu popup:
os.system('flameshot gui -d 5000 -p ' + image + ' 2>/dev/null')

# Close Xfile window by killing the process-id stored earlier:
os.system('kill -9 $(cat ' + xfile_pid  + ') 2>/dev/null')

# Perform text-recognition on screen-captured tools-menu popup, and save results:
os.system('gocr -l 90 -a 70 -C A-Za-z\\(\\)-- ' + image + ' 2>/dev/null | \
           grep -v \"^[^a-zA-Z0-9]*$\" >| ' + menufile2)
# (Lines without alphanumerical characters have been filtered away.)

# Convert this to a list of screen-captured labels:
with open(menufile2) as f:
    menulist2 = [ x for x in f.read().splitlines() ]

# Number of screen-captured labels should equal the number of actions, otherwise exit:
if len(menulist2) != len(menulist1):
    print(f"\033[FWrong line count")
    sys.exit(1)

# Open a diagnostics file for 'Screen-captured label' to 'labelString' mapping:
with open(menufile3, "w") as f:
    f.write("")

# Arrange actions into a list in same sequence as their screen-captured labels appear:
print(f"\033[FJust a moment please, the sequence is being calculated...")
screen_order = []
for line2 in menulist2:
    smallest = 100000
    for line1 in menulist1:

        # Get the 'Levenshtein-distance' betw. each labelString and screen-captured label:
        distance = int(levenshtein((line1.split('@'))[1], line2))

        # The smaller the distance, the closer the simularity ('fuzzy comparison'):
        if distance < smallest:
            smallest = distance

            # Action of labelString with closest match to screen-captured label so far:
            action = (line1.split('@'))[0]
            label = (line1.split('@'))[1]

    # Place action of closest-matching labelString in same position as on the screen:
    screen_order.append(action)

    # Write the 'Screen-captured label' to 'labelString' mapping to the mapping-file:
    with open(menufile3, "a") as f:
        f.write(line2 + '	' + label + '\n')

# Dictionary with key = action, and value = (desired) ranking-position (0 = top):
ranking_positions = {}
i = 0
for line1 in menulist1:
    ranking_positions[line1.split('@')[0]] = i
    i += 1

# List of all ranking-positions already visited:
visited_rankings = []

# Dictionary with key = action, and value = stack-position:
stack_positions = {}

# Iterate over the actions, start w/ bottom pos. on the screen, give it stack-position 0:
for action in reversed(screen_order):

    # Count how many previously-visited actions have a ranking-position < this action:
    stackpos = 0
    for visited_rank in visited_rankings:
        if visited_rank < ranking_positions[action]:
            stackpos += 1

    # Assign to action a stack-position = number of visited actions w/ smaller ranking:
    stack_positions[action] = stackpos
    visited_rankings.append(ranking_positions[action])

# For all actions, substitute positionIndex value (= 0) by stack-position value:
regex = " \""
for action in stack_positions:
    regex = regex + \
    "/" + action + "\\.positionIndex/s/: [0-9]+/: " + str(stack_positions[action]) + "/;"
regex = regex + "\" "
os.system("sed -Ei" + regex + resources)

print("Done! - Changes will take effect in a new XFile window.")
