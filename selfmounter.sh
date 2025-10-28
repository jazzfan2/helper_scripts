#!/bin/bash
# Name: selfmounter.sh
# Author: R.J.Toscani
# Date: 21 oktober 2025
# Description:
# Automatically mount all present external USB-drives, eMMC's and SD-Cards.
# Program meant to be launched from $HOME/.sessionetc and be used as a background
# daemon facilitating the 'XFile' file manager (p/o 'Enhanced Motif Window Manager'
# by Alexander Pampuchin - https://fastestcode.org/ , LGPLv3, MIT License).
#
######################################################################################
#
# Copyright (C) 2025 Rob Toscani <rob_toscani@yahoo.com>
#
# selfmounter.sh is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# selfmounter.sh is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
######################################################################################

gomount(){
    UUID=$1
    device=${devpath[$UUID]}
    parttype=${parttype[$UUID]}
    (echo -n "	"; date) >> $HOME/mountlog
    if [[ "$parttype" == "vfat" || "$parttype" == "ntfs" ]]; then
        if grep -q "^UUID=$UUID" /etc/fstab; then
            xterm -geometry 60x5+0+0 -e "sudo mount $device 2>&1 1>>$HOME/mountlog"
        else
            udisksctl mount -o umask=0077 --block-device $device 2>&1 1>>$HOME/mountlog
        fi
    elif [[ "$parttype" == "ext2" || "$parttype" == "ext3" || "$parttype" == "ext4" ]]; then
        udisksctl mount --block-device $device 2>&1 1>>$HOME/mountlog
    fi
}

[[ ! -f $HOME/mountlog ]] && touch $HOME/mountlog

# Associative arrays (option '-A') with UUID as index value:
declare -A presence       # 'presence' state of device
declare -A mounted        # 'mounted' state of device
declare -A mount_allowed  # 'mount_allowed' state of device
declare -A devpath        # Path of device (this might become swapped between devices)
declare -A parttype       # File system type (partition type) of device

# Non-associative 'previous presence'-array of all UUIDs present in previous cycle:
prev_presence=()

while true; do

    while read device; do

        # Device string of current UUID is: "<UUID> <PATH> <FSTYPE> 1 <FSROOTS>"
        device=($device)             # Convert this string to an array of UUIDs
        UUID=${device[0]}            # UUID is 0th element, becomes the primary key
        devpath[$UUID]=${device[1]}  # Device path is 1st element, store in devpath-array

        # If current UUID appears here we can set its 'presence' state to true:
        presence[$UUID]=true
        if [[ -e ${device[4]} ]]; then
            # If FSROOTS (4th element) is present ('/'), current UUID is mounted:
            mounted[$UUID]=true
        else
            # Otherwise, if there's no 4th element, current UUID is not mounted:
            mounted[$UUID]=false
        fi

        # If current UUID appears in 'previous presence'-list as well, it's not new:
        prev_presence_copy=(${prev_presence[@]}) # Make copy first, meant to iterate over
        interrupt=0
        for prevUUID in ${prev_presence_copy[@]}; do
            [[ $UUID == $prevUUID ]] &&
            # Then we can eliminate current UUID from the list, leaving ones not matched yet:
            prev_presence=("${prev_presence[@]//$UUID}") &&
            interrupt=1 && break
        done

        # In that case we continue with the next UUID present:
        (( interrupt )) && continue

        # If currect UUID ends here, it's new so we initialize parttype and mount_allowed state:
        parttype[$UUID]=${device[2]} # Partition type is 2nd element, store in parttype-array
        mount_allowed[$UUID]=true

    # Print "<UUID> <PATH> <FSROOTS> <FSTYPE> 1" strings of all present hotplug-partitions:
    done < <(lsblk -o UUID,PATH,FSTYPE,HOTPLUG,FSROOTS | awk '$4 && $4 == 1')

    # Remaining (non-matched) UUIDs in 'previous presence'-list are not present anymore:
    for UUID in ${prev_presence[@]}; do
        # So we set 'presence' + 'mounted' states to false, and 'mount_allowed' state to true:
        presence[$UUID]=false
        mounted[$UUID]=false
        mount_allowed[$UUID]=true
    done
    prev_presence=()             # Make prev_presence list empty again

    # Set states of each UUID and mount it if appropriate combination of states applies:
    for UUID in ${!presence[@]}; do

        # Mount UUID if 'present' and 'mount_allowed' states are both true:
        if [[ ${presence[$UUID]} == true && ${mount_allowed[$UUID]} == true &&
              ${mounted[$UUID]} == false ]]; then
            gomount $UUID &
        fi

        # Set 'mount_allowed' state (true if UUID is absent and unmounted, else false):
        if [[ ${presence[$UUID]} == false && ${mounted[$UUID]} == false ]]; then
            mount_allowed[$UUID]=true
        else
            mount_allowed[$UUID]=false
        fi

        # Keep track which UUIDs were present in this cycle, including those being removed:
        prev_presence=("${prev_presence[@]}" "$UUID")
    done
    sleep 2
done
