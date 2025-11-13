#!/usr/bin/env python3
# Name  : screenorder.py
# Author: Rob Toscani
# Date  : 12-11-2025
# Description:
# This programm is called by 'menusort2.sh'
# Prerequisite for this program:
# levenshtein.py (Copyright Jamiel Rahi GPL 2019), to be downloaded from:
#     https://github.com/jamfromouterspace/levenshtein/blob/master/levenshtein.py
#     to $HOME/scripts/ and made executable.
#
# Temporary solution for enhanced speed.
# Planning to fully convert menusort.sh into Python3.
#
###############################################################################
#
# Copyright (C) 2025 Rob Toscani <rob_toscani@yahoo.com>
#
# screenorder.py is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# screenorder.py is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
##############################################################################

import sys
sys.path.insert(0, "$HOME/scripts")
import levenshtein; 

with open(sys.argv[1]) as menu1:
    menulist1 = [ x for x in menu1.read().splitlines() ]

with open(sys.argv[2]) as menu2:
    menulist2 = [ x for x in menu2.read().splitlines() ]

# Arrange actions in same sequence as their screen-captured labels appear into a text line:
screen_order = ""
for line2 in menulist2:
    smallest = 100000
    for line1 in menulist1:

        # Get the 'Levenshtein-distance' betw. screen-captured label and each labelString:
        distance = int(levenshtein.levenshtein((line1.split('@'))[1], line2))

        # The smaller the distance, the closer the simularity ('fuzzy comparison'):
        if distance < smallest:
            smallest = distance

            # Action of labelString with closest match to screen-captured label so far:
            action = (line1.split('@'))[0]

    # Place action of closest-matching labelString in same position as on the screen:
    screen_order = screen_order + action + " "

print(screen_order)
