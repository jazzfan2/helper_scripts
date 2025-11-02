#!/bin/bash
# Name: mount_volumes.sh
# Author: R.J.Toscani
# Date: 22 oktober 2025
# Description: Mount or unmount one or more volumes selected in the file manager.
# Mounting point(s) selected in the file manager by mouse button 1
# ('primary X-selection') is/are taken by the program as argument(s).
# An xterm window popup prompts for a password if this is required.
#
# Meant to be launched from the tools-menu of the file-manager named 'XFile
# (p/o 'Enhanced Motif Window Manager' by Alexander Pampuchin - https://fastestcode.org/
# - LGPLv3, MIT License), or as a mount/unmount command from its context menu.
#
# Reason for developing this program was to work around following bug(?):
# Primary X-selected filenames containing spaces aren't properly handled by '%n'
# in the 'XFile.tools'-resource if this has the form: xterm -e '<command> \"%n\""
# resulting in undesired word-splitting even if %n is surrounded by escaped quotes.
# (Perhaps this is undefined 'xterm -e' behaviour if the part between quotes contains
# more than just a command name and arguments as described in man xterm for option -e)
#
######################################################################################
#
# Copyright (C) 2025 Rob Toscani <rob_toscani@yahoo.com>
#
# mount_volumes.sh is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# mount_volumes.sh is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
######################################################################################

mode="mount"

options(){
# Specify options:
    while getopts "hu" OPTION; do
        case $OPTION in
            h) helptext
               exit 0
               ;;
            u) mode="unmount"
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
Usage: mount_volumes.sh [-hu]

-h   Help (this output)
-u   Unmount selected volume
EOF
}


function handle()
{
    # 'Mount' or 'unmount' mode:
    mode=$1

    # Separate volume-names (mount-points) in string by pipe symbol, and store into array:
    OLDIFS=$IFS
    IFS='|'
    mountpoints=($2)
    IFS=$OLDIFS

    # File-system table (/etc/fstab) is stored into text-string once for repeated searching:
    fstable=""
    while read line; do
        fstable="$fstable\n$line"
    done < /etc/fstab

    for mountpoint in "${mountpoints[@]}"; do

        # Volume is in /etc/fstab if its UUID is found there (i.e. not an empty string):
        device=($(echo -e "$fstable" | grep -E "^UUID=.*${mountpoint// /\\040}\>"))
        UUID="${device[0]/UUID=/}"
        parttype="${device[2]/-3g/}"

        if [[ -n "$UUID" ]]; then
            # If in /etc/fstab and 'ext'-partition:
            if grep -q "ext" <<<"$parttype"; then
                [[  $mode == "mount"   ]] && (mount --target "$mountpoint" 2>/dev/null &) ||
                ([[ $mode == "unmount" ]] && umount "$mountpoint" 2>/dev/null &)

            # If in /etc/fstab and 'ntfs'-partition (then apparently sudo mount is needed ?!):
            elif [[ "$parttype" == "ntfs" ]]; then
                [[  $mode == "mount"   ]] && sudo mount --target "$mountpoint" 2>/dev/null ||
                ([[ $mode == "unmount" ]] && umount "$mountpoint" 2>/dev/null &)
            fi
        else
            # Not in /etc/fstab (USB sticks and SD-cards); only unmount:
            device=($(df | grep "$mountpoint"))
            [[ $mode == "unmount" ]] && udisksctl unmount -b ${device[0]} 1>/dev/null &
        fi
    done
}

options $@
shift $(( OPTIND - 1 ))

volumes=""
for volume in "$@"; do           # Volumes (mount-points; N.B.: without trailing '/'!)
    volumes="$volumes"$volume"|" # Concatenate volume-names into pipe-separated string
done

export -f handle                 # Export function to all child shells (xterm -e)

if [[ $mode == "mount" ]]; then
    xterm -geometry 50x2+0+0 -e "handle \"mount\"  \"$volumes\"; sleep 0.5"
else # if mode == unmount
    xterm -geometry 50x2+0+0 -e "handle \"unmount\" \"$volumes\"; sleep 0.5"
fi
