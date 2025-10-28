#!/bin/bash
# Name: newname.sh
# Author: R.J.Toscani
# Date: 9 October 2025
# Description: Alternative rename-function for the Tools-menu of XFile (EMWM)
# by Alexander Pampuchin - https://fastestcode.org/
# This version allows using MB2 for entering a new name copied by X-selection (MB1)
# (which XFile's own rename-function doesn't!).
#
###################################################################################


rename()
{
    echo "Geef nieuwe naam:"
    read -e "newname"        # -e option allows moving the cursor within the entered text!!
    mv "$1" "$newname"
}

[[ $# != 1 ]] && exit

file="$1"

export -f rename

xterm -geometry 50x5+0+0 -e "rename \"$file\""
