#!/bin/bash
# Name: newname.sh
# Author: R.J.Toscani
# Date: 9 October 2025
# Description:
# Alternative rename-function for the Tools-menu of file-manager named 'XFile' 
# (part of 'Enhanced Motif Window Manager' by Alexander Pampuchin
# - https://fastestcode.org/ - LGPLv3, MIT License).
# This version allows using MB2 for entering a new name copied by X-selection (MB1)
# (unlike XFile's own rename-function).
#
###################################################################################
#
# Copyright (C) 2025 Rob Toscani <rob_toscani@yahoo.com>
#
# newname.sh is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# newname.sh is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
######################################################################################

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
