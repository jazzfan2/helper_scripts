#!/bin/bash
# Name: symlink.sh
# Author: R.J.Toscani
# Date: 7 October 2025
# Description: Store an absolute symlink to the selected file into a RAM directory,
# and present this in a popup from which the symlink can be moved to a desired directory.
# The symlink gets the same name as the file pointed to.
# Meant to be used with XFile (EMWM) by Alexander Pampuchin - https://fastestcode.org/.
# This program takes two arguments:
#     1. full path to directory where selected file resides
#     2. name of selected file
#
########################################################################################


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
