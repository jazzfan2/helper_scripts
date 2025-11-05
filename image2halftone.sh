#!/bin/bash
# Name: image2halftone.sh
# Author: R.J.Toscani
# Date: 5th of June 2025
# Description: Create a halftone dithered (dotted raster) image in .xpm format
# ("black and white - newspaper photograph") from an existing black and white- or color
# image. See also: https://legacy.imagemagick.org/Usage/quantize/#diy_threshold
#
# Application: to convert a jpg- or png-image (or gif etc.) to a format suitable to be
# set as a monochrome Motif/X11 screen-background by the program 'xbackdrop' by Alexander
# Pampuchin (part of the 'Enhanced Motif Window Manager' - https://fastestcode.org/
# - LGPLv3, MIT License).
#
######################################################################################
#
# Copyright (C) 2025 Rob Toscani <rob_toscani@yahoo.com>
#
# image2halftone.sh is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# image2halftone.sh is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
######################################################################################

read -p "Enter full path to image file to be dithered: " "imagepath"

# convert "$imagepath" -colorspace Gray -ordered-dither h4x4a "$imagepath"_halftone.xpm
convert "$imagepath" -colorspace Gray -ordered-dither o4x4 "$imagepath"_halftone.xpm

# Add 's'- en 'm'-columns in the xpm-file's 'colors'-legenda in order to force it to
# be interpreted as 'monochrome colorable' by the 'xbackdrop' background program:
sed -Ei 's/(c black)/s background  m black \1/; s/(c white)/s selectColor m white \1/' "$imagepath"_halftone.xpm
