#!/bin/bash
# Name: symlink.sh
# Author: R.J.Toscani
# Date: 7 October 2025
# Description: Store an absolute symbolic link to the file selected in the file manager
# into a RAM directory. It presents this in a file manager window popping up, from which
# the link can be moved or copied to a desired directory opened in another file manager
# window. The symbolic link adopts the name of the file pointed to.
#
# Meant to be launched from the tools-menu of the file-manager named 'XFile' (part of
# 'Enhanced Motif Window Manager' by Alexander Pampuchin
# - https://fastestcode.org/ - LGPLv3, MIT License).
#
# This program takes two arguments:
#    1. the full path to the directory where the selected file resides
#    2. the name of selected file
#
########################################################################################
#
# Copyright (C) 2025 Rob Toscani <rob_toscani@yahoo.com>
#
# symlink.sh is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# symlink.sh is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
######################################################################################

# Determine where the temporary directory can be created:
if [[ -d /tmp/ramdisk/ ]]; then
    tmpfiledir="/tmp/ramdisk/symlink"
elif [[ -d /dev/shm/ ]]; then
    tmpfiledir="/dev/shm/symlink"
fi

# Create the temporary RAM directory unless it already exists:
[[ ! -d "$tmpfiledir" ]] && mkdir "$tmpfiledir"

# Remove any previous popup of symlink directory:
kill -9 $(ps aux | grep "$tmpfiledir" | awk '{ print $2 }') 2>/dev/null

# Remove any previous symlinks there:
rm "$tmpfiledir"/.* "$tmpfiledir"/* 2>/dev/null

# Place the new symlink to the selected file into the temporary RAM directory:
ln -s "$1"/"$2" "$tmpfiledir"/"$2"

# Open temporary RAM directory - containing the symlink - in XFile:
/usr/bin/xfile -geometry 500x130+0+0 -a "$tmpfiledir"
