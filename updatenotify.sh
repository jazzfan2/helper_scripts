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
notificationtext="New updates are available for your computer (Ctrl-C to quit)."

pid="foobar"    # First (= dummy-) xterm process
while true; do
    kill -9 $pid 2>/dev/null
    if ! grep -q "0 updates" "$notificationfile"; then
        xterm -bg purple -T "NEW UPDATES AVAILABLE" -geometry 44x3-0-0 -e \
        "echo \"$notificationtext\"; while read -sn 1 char; do echo \"$notificationtext\"; done" & pid=$!
    fi
    sleep 60
done