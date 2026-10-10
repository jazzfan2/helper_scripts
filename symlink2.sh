#!/bin/bash
# Name: symlink2.sh
# Author: R.J.Toscani
# Date: 6th October 2026
# Description: Create a relative symbolic link to the target-file or -directory
# selected in the file manager. The link is placed into the directory entered
# in the xterm pop-up. The symbolic link adopts the name of the file pointed to.
# Based on the algorithm presented by Thomas Dickey in:
# https://stackoverflow.com/questions/29055511/how-to-find-relative-path-given-two-absolute-paths
#
# Meant to be launched from the tools-menu of the file-manager named
# 'XFile' (part of the 'Enhanced Motif Window Manager (EMWM)' by
# Alexander Pampuchin - https://fastestcode.org/ - LGPLv3, MIT License).
#
# This program takes two arguments (inherited from %p and %n if x-selecting within XFile):
#    1. the full path to the directory where the selected target-file resides
#    2. the name of selected target-file
#
########################################################################################
#
# Copyright (C) 2026 Rob Toscani <rob_toscani@yahoo.com>
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

makelink()
{
    tardirpath="$1"   # Absolute path to directory containing target-file or -directory
    targetfile="$2"   # Name of target-file or -directory

    echo "$tardirpath"
    echo "$targetfile"

    while true; do
        echo "Give absolute path of link directory:"
        read -e "linkdirpath"  # (-e option allows moving the cursor within the entered text)
        if ([ -d "$linkdirpath" ] && [ -w "$linkdirpath" ]); then
            break
        fi
        echo "Path must be an existing directory with write-permission. Please retry."
    done

    if ! echo "$tardirpath" | grep -qE "\/$"; then
        tardirpath=$tardirpath"/"
    fi

    if ! echo "$linkdirpath" | grep -qE "\/$"; then
        linkdirpath=$linkdirpath"/"
    fi

    link=$linkdirpath$targetfile

    while true; do
        # Find both highest parent-directories, and check if these are common:
        prefix1="$(grep -oE "^\/[^/]+" <<< "$tardirpath")"
        prefix2="$(grep -oE "^\/[^/]+" <<< "$linkdirpath")"
        if [ "$prefix1" = "$prefix2" ] && [ "$prefix1" != "" ]; then
            # Strip common parent from target-directory & link-directory strings:
            tardirpath="$( sed "s#^$prefix1##" <<< "$tardirpath")"
            linkdirpath="$(sed "s#^$prefix1##" <<< "$linkdirpath")"
            # And repeat the loop.
        else
            # Else, if parents are uncommon or empty, quit loop:
            break
        fi
    done

    # Replace each directory-name in link-directory string with "..":
    upsteps="$(   sed -E "s/\/[^/]+/..\//g" <<< "$linkdirpath")"
    # Add result (incl. path-separators) in front of target-directory string:
    tardirpath="$(sed -E "s/^\/+//"         <<< "$upsteps$tardirpath")"
    target="$(    sed -E "s/\/+/\//g"       <<< "$tardirpath$targetfile")"

    ln -s "$target" "$link"
}

[[ $# != 2 || $2 == "" ]] && echo "Usage: symlink2 <directory_path> <target_file>" && exit

export -f makelink

xterm -geometry 100x10+0+0 -e "makelink \"$1\" \"$2\""
