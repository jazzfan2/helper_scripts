#!/bin/bash
# Name: pickrgb.sh
# Author: R.J.Toscani
# Date: 27th of May 2025
# Description: 'pickrgb.sh' automates identification of colors taken from the screen.
# Take a local screenshot including the color of interest, do a detailed selection of
# the color in the XPaint canvas being opened, and obtain its hexadecimal RGB-value
# in "rgb:<red>/<green>/<blue>" format, as well as in "<red> <green> <blue>" format.
#
# Prerequisites:
# - scrot
# - xpaint
#
######################################################################################
#
# Copyright (C) 2025 Rob Toscani <rob_toscani@yahoo.com>
#
# pickrgb.sh is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# pickrgb.sh is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
######################################################################################


# Determine where the screenshot must be stored temporarily:
if [[ -d /tmp/ramdisk/ ]]; then
    tmpfiledir="/tmp/ramdisk"
elif [[ -d /dev/shm/ ]]; then
    tmpfiledir="/dev/shm"
else
    tmpfiledir="."
fi

sample="$tmpfiledir/sample$(date -Iminutes)_$RANDOM.png"

# Abort after receiving an interrupt signal (Ctrl-C):
trap "[[ -f $sample ]] && \rm $sample; pkill xpaint; exit" SIGINT SIGTERM

# Take a local screenshot, including the color of interest:
clear
echo "Select a rectangular sample of the screen, including the color of interest."
scrot -s -F $sample

# The screenshot just taken is being opened as an image in Xpaint:
xpaint $sample 2>/dev/null &

clear
while read line; do
    echo $line
done << EOF
The screenshot just taken is now being opened as an image in XPAINT.
Proceed as follows:

1. Click the EYE symbol at the top left and pick the DESIRED COLOR in the IMAGE,
2. Now click on the IDENTICALLY COLORED ICON in the right upper region,
3. In the popup-window now being opened, read the RED-, GREEN- and BLUE-VALUES,
4. Type these THREE NUMBERS below, separated by spaces, and give <ENTER>:

Enter <Ctrl-C> (2x) to interrupt
EOF
read red green blue

# The decimal RGB-value is converted to hexadecimal:
red_hex=$(printf "%02X" "$red")
green_hex=$(printf "%02X" "$green")
blue_hex=$(printf "%02X" "$blue")

# The hexadecimal RGB-value is printed:
echo -e "\nOf this decimal RGB-value, the hexadecimal equivalent is as follows:\n"
echo -e "rgb:$red_hex/$green_hex/$blue_hex"
echo -e "$red_hex $green_hex $blue_hex\n"
pkill xpaint
[[ -f $sample ]] && \rm $sample
