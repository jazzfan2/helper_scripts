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


handle()
# Mount or unmount the given volume(s):
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

        # If in /etc/fstab:
        if [[ -n "$UUID" ]]; then
            if [[  $mode == "mount" ]]; then
                # With 'ext'-partition, no sudo is needed for mounting:
                if grep -q "ext" <<<"$parttype"; then
                    mount --target "$mountpoint" 2>/dev/null &
                # With 'ntfs'-partition, apparently sudo is needed for mounting:
                elif [[ "$parttype" == "ntfs" ]]; then
                    sudo mount --target "$mountpoint" 2>/dev/null &
                fi
            elif [[ $mode == "unmount" ]]; then
                umount "$mountpoint" 2>/dev/null &
            fi
        # If not in /etc/fstab (USB sticks and SD-cards) only unmount:
        else
            device=($(df | grep "$mountpoint"))
            [[ $mode == "unmount" ]] && udisksctl unmount -b ${device[0]} 1>/dev/null &
        fi
    done
}

options $@
shift $(( OPTIND - 1 ))

# Concatenate mountpoints (N.B.: w/o trailing '/' !) of all mounted devices into one string:
mntpnts=""
while read mntpnt; do
    mntpnts="$mntpnts $mntpnt"
done < <(lsblk -o MOUNTPOINT)

 # Concatenate selected volume-names into a pipe-separated string:
volumes=""
for volume in "$@"; do
    # Only if to-be-unmounted volumes are present, or if to-be-mounted volumes aren't:
    if ( [[ $mode == "unmount" ]] &&   grep -q "$volume" <<< "$mntpnts" ) ||
       ( [[ $mode == "mount"   ]] && ! grep -q "$volume" <<< "$mntpnts" ); then
        volumes="$volumes"$volume"|"
    fi
done

# Export function to all child shells (xterm -e):
export -f handle

# Call xterm popup executing mount or unmount on all volumes in the catenated string:
if [[ $mode == "mount" ]]; then
    xterm -geometry 50x2+0+0 -e "handle \"mount\"  \"$volumes\"; wait"
else # if mode == unmount
    xterm -geometry 50x2+0+0 -e "handle \"unmount\" \"$volumes\"; wait"
fi
