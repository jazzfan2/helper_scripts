#!/bin/bash
# Name: updatenotify.sh
# Author: R.J.Toscani
# Date: 13 October 2025
# Description: Program that launches a notifying popup in case Ubuntu software
# updates are available. Meant to act as a background daemon, called from the
# $HOME/.sessionetc file (p/o 'Enhanced Motif Window Manager'
# by Alexander Pampuchin - https://fastestcode.org/ - LGPLv3, MIT License).
#
######################################################################################
#
# Copyright (C) 2025 Rob Toscani <rob_toscani@yahoo.com>
#
# updatenotify.sh is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# updatenotify.sh is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
######################################################################################


notificationfile="/var/lib/update-notifier/updates-available"
# notificationfile="/tmp/ramdisk/updates-available"             # For diagnostics
notificationtext="New updates are available for your computer (Ctrl-C to quit)."

monitorcycle=30
checkcycle=3600


monitor()
{
    processid=$1
    while grep -q "^$processid$" <(ps aux | awk '{ print $2 }'); do
        # Monitor if all available updates have been installed, if so terminate xterm popup and return:
        if grep -q "^0 updates" "$notificationfile"; then
            kill -9 $processid 2>/dev/null
            return
        fi
        # Otherwise repeat the cycle:
        sleep $monitorcycle
    done
}


while true; do
    popup=0
    # Check if there are new updates available, if so launch an xterm popup notifying this:
    if ! grep -q "^0 updates" "$notificationfile"; then
        xterm -bg purple -T "NEW UPDATES AVAILABLE" -geometry 44x3-0-0 -e \
        "echo \"$notificationtext\"; while read -sn 1 char; do echo \"$notificationtext\"; done" & pid=$!
        # Monitor on the background if all the updates have been installed:
        popup=1
        monitor $pid &
    fi
    sleep $checkcycle
    # Terminate the xterm popup before starting a new cycle:
    if (( popup )); then
        kill -9 $pid 2>/dev/null  # We assume that if pid was killed earlier, no other process has adopted it...
        # https://superuser.com/questions/1864191/how-to-avoid-killing-the-wrong-process-caused-by-linux-pid-reuse
    fi
done