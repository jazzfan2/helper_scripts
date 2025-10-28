#!/bin/bash
# Name: mount_plugdrives.sh
# Author: R.J.Toscani
# Date: 5 september 2025
# Description: Mount all present external USB-drives, eMMC's and SD-Cards.
# Program meant to be used with XFile (p/o 'Enhanced Motif Window Manager'
# by Alexander Pampuchin - https://fastestcode.org/ , LGPLv3, MIT License).
#
######################################################################################
#
# Copyright (C) 2025 Rob Toscani <rob_toscani@yahoo.com>
#
# mount_plugdrives.sh is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# mount_plugdrives.sh is distributed in the hope that it will be useful,
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
    if [[ "$parttype" == "vfat" || "$parttype" == "ntfs" ]]; then
        if grep -q "^UUID=$UUID" /etc/fstab; then
            xterm -geometry 60x5+0+0 -e "sudo mount $device"
        else
            udisksctl mount -o umask=0077 --block-device $device 2>/dev/null
        fi
    elif [[ "$parttype" == "ext2" || "$parttype" == "ext3" || "$parttype" == "ext4" ]]; then
        udisksctl mount --block-device $device 2>/dev/null
    fi
}


declare -A devpath    # Path of device
declare -A parttype   # File system type (partition type) of device

while read device; do
    device=($device)
    UUID=${device[0]}
    devpath[$UUID]=${device[1]}
    parttype[$UUID]=${device[2]}
    if [[ ! -e ${device[4]} ]]; then
        # If the device is not mounted, then go mount it:
        gomount $UUID &
    fi
done < <(lsblk -o UUID,PATH,FSTYPE,HOTPLUG,FSROOTS | awk '$4 && $4 == 1')