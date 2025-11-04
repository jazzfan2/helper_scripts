#!/bin/bash
# Name: randombackdrop2.sh
# Author: R.J.Toscani
# Date: 2nd of June 2025
# Description: Interactive wrapper around the 'randombackdrop.sh' script.
# Engine: the 'xbackdrop' program by Alexander Pampuchin (part of the 'Enhanced
# Motif Window Manager (EMWM)' - https://fastestcode.org/ - LGPLv3, MIT License),
# which as a prerequisite must have been installed in order for this script
# to function. Intended to be launched as an item from the EMWM toolbox-menu.
#
##############################################################################
#
# Copyright (C) 2025 Rob Toscani <rob_toscani@yahoo.com>
#
# randombackdrop2.sh is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# randombackdrop2.sh is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#############################################################################

period=60
read -p "Specify cycling period in (minimally 1) seconds (<ENTER> = 60s): " period

if (grep -q [^0-9] <<< "$period" || [[ "$period" < 1 ]]); then
    period=60
fi 

options="-p $period"

read -p "Include CDE-images [y/N]? " -n 1 "reply"

if ! grep -q "y" <<< $reply; then
    options="-n $options"
fi

echo
read -p "Gradual shift of colors [y/N]? " -n 1 "reply"

if grep -q "y" <<< $reply; then

    echo
    read -p "Shift to a complementary color [y/N] instead of a random color? " -n 1 "reply"

    if grep -q "y" <<< $reply; then
        options="-G $options"
    else
        options="-g $options"
    fi

    echo
    read -p "Next color identical [i] or complementary [c] to previous, or random [any other key]? " -n 1 "reply"

    if grep -q "c" <<< $reply; then
        options="-c $options"
    elif grep -q "i" <<< $reply; then
        options="-i $options"
    fi
fi

nohup $HOME/scripts/randombackdrop.sh "$options" 2>/dev/null &

echo
sleep 1    # To avoid timing issue with background process starting up
