#!/bin/bash
# Name: wsbackdrop.sh
# Author: Rob Toscani
# Date: 11th of May 2026
# Description: Set backdrop image and optional color(s) for current EMWM workspace.
#
# Wrapper script around the 'tellmwm()' program by Alexander Pampuchin
# (workspace control utility for the 'Enhanced Motif Window Manager (EMWM)'
# https://fastestcode.org/ - LGPLv3, MIT License).
# EMWM version must be at least v2.0 to use this program.
#
#############################################################################
#
# Copyright (C) 2026 Rob Toscani <rob_toscani@yahoo.com>
#
# wsbackdrop.sh is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# wsbackdrop.sh is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
############################################################################
#

calculate_fgcolor=false # Initial state: no calculation of foreground color
DarkThreshold=15        # Motif value
LightThreshold=93       # Motif value

# Determine where the modified pixmap file can be stored in RAM temporarily:
if [[ -d /tmp/ramdisk/ ]]; then
    tempdir="/tmp/ramdisk"
elif [[ -d /dev/shm/ ]]; then
    tempdir="/dev/shm"
else
    tempdir="."               # (No RAM, serves as fall back scenario)
fi

# Name of RAM-subdirectory:
subdir="subdir_$RANDOM$RANDOM"

# X11-colors-list addendum:
addendum="\
0 128 128 teal\n
0 128 128 Teal"

# Determine current workspace:
workspace=$(tellmwm | tail -n 1 | awk '{ print $NF }')


#=============================== FUNCTIONS ================================#


options(){
# Specify options:
    while getopts "fh" OPTION; do
        case $OPTION in
            f) calculate_fgcolor=true  # Calculate foreground from background
               ;;
            *) helptext>&2
               exit 1
               ;;
        esac
    done
}

helptext()
# Text printed if -h option (help) or a non-existent option has been given:
{
	cat <<-EOF
		Usage: wsbackdrop.sh [-fh] IMAGE [BACKGROUNDCOLOR [FOREGROUNDCOLOR]]

		-f   Calculate foreground-color from background-color if given
		-h   Help (this output).

		Arguments:
		IMAGE            Full path to image file, or 'none' for no image.
		BACKGROUNDCOLOR  Hexadecimal RGB-string e.g. "rgb:1C/87/fa",
		                 or X11-color-name without spaces or quoted.
		FOREGROUNDCOLOR  Idem.
	EOF
}

name2rgb()
# Convert X11-color-name to "rgb:redhex/greenhex/bluehex" string:
{
    line="$( (showrgb; echo -e $addendum) | awk 'NF == 4' |
    grep -m1 -iE "\<${1// /}\>" )"
    [[ -z "$line" ]] && echo "Cannot allocate named color '$1'" >&2 && return
    awk '{
        redx   = sprintf("%02x", $1)
        greenx = sprintf("%02x", $2)
        bluex  = sprintf("%02x", $3)
        print "rgb:" redx "/" greenx "/" bluex
    }' <<< "$line"
}

get_fgcolor()
# Calculate foreground color RGB from given background RGB and brightness:
{
    rgb="$1"
    awk -v DarkThreshold=$DarkThreshold -v LightThreshold=$LightThreshold '\
    BEGIN { FS = "/" }
    {
        red   = sprintf("%d", strtonum("0x" $1))
        green = sprintf("%d", strtonum("0x" $2))
        blue  = sprintf("%d", strtonum("0x" $3))

        brightness = 100 * (0.299 * red + 0.587 * green + 0.114 * blue) / 255

        # Calculate foreground and selectColor RGB-values from background RGB- and brightness-values:
        factor_fg     = 1
        offset_red_fg = offset_green_fg = offset_blue_fg  = 0

        if ( brightness < DarkThreshold ){
            offset_red_fg   = 0.2 * (255 - red)
            offset_green_fg = 0.2 * (255 - green)
            offset_blue_fg  = 0.2 * (255 - blue)
        }
        else if ( brightness > LightThreshold )
            factor_fg = 0.5
        else
            factor_fg = 0.6

        red_fg   = sprintf("%02x", red   * factor_fg + offset_red_fg)
        green_fg = sprintf("%02x", green * factor_fg + offset_green_fg)
        blue_fg  = sprintf("%02x", blue  * factor_fg + offset_blue_fg)

        printf ("%s\n", "rgb:"red_fg"/"green_fg"/"blue_fg)
    }' <<< "${rgb/*:/}"
}

tellrgb()
# Report current RGB of argument-string "Background" or "Foreground":
{
    (( nr = ${workspace/ws/} + 1 ))
    tellmwm | grep "$1" | head -n $nr | tail -n -1 |
    awk '{ print "rgb:"substr($NF,2,2)"/"substr($NF,4,2)"/"substr($NF,6,2) }'
}

combinecolor()
# Convert color from 'rgb:redhex/greenhex/bluehex' to 'combined decimal' notation:
{
    rgb="$1"
    awk '\
    BEGIN { FS = "/" }
    {
        red   = sprintf("%d", strtonum("0x" $1))
        green = sprintf("%d", strtonum("0x" $2))
        blue  = sprintf("%d", strtonum("0x" $3))
        print 256**2 * red + 256 * green + blue
    }' <<< "${rgb/*:/}"
}

testwhite()
# Test if background/foreground combination causes a white backdrop (Motif-bug!):
{
    awk -v bg=$(combinecolor "$1") -v fg=$(combinecolor "$2") '\
    BEGIN {
        mod = 31
        remainder = bg % mod
        badfg = 65805 + (remainder >= 13) * mod - remainder
        if ((fg - badfg) % mod == 0)
            print "true"     # Remainder = 0 gives white result
        else
            print "false"
    }'
}

shiftcolor()
# Slightly change 'rgb:redhex/greenhex/bluehex'-color by incrementing blue component:
{
    rgb="$1"
    awk '\
    BEGIN { FS = "/" }
    {
        red   = $1
        green = $2
        blue = sprintf("%02x", strtonum("0x" $3) + 0x01)
        print "rgb:"red"/"green"/"blue
    }' <<< "${rgb/*:/}"
}

convert_xpm()
# Re-activate the color-gradations between/beyond foregound- & background-colors in the XPM-file, by:
# 1. Calculating 'selectColor' & 'topShadowColor' RGB values from background- and foregound-colors,
# 2. Updating the 'c'-field accordingly in the color-strings containing above two symbolic color names,
# 3. Renaming the 's'-field called 'bottomShadowColor' to 'foreground':
{
    image="$1"
    awk -v bgcolor=$bg -v fgcolor=$fg '\
    function min(a, b){
        if (a <= b)
            return a
        else
            return b
    }
    function brightness(red, green, blue){
        return 100 * (0.299 * red + 0.587 * green + 0.114 * blue) / 255
    }
    BEGIN {
        red_bg   = sprintf("%d", strtonum("0x" substr(bgcolor, 5, 2)))
        green_bg = sprintf("%d", strtonum("0x" substr(bgcolor, 8, 2)))
        blue_bg  = sprintf("%d", strtonum("0x" substr(bgcolor, 11, 2)))

        red_fg   = sprintf("%d", strtonum("0x" substr(fgcolor, 5, 2)))
        green_fg = sprintf("%d", strtonum("0x" substr(fgcolor, 8, 2)))
        blue_fg  = sprintf("%d", strtonum("0x" substr(fgcolor, 11, 2)))

        # Calculate selectColor RGB-values by interpolating background- and foreground-color RGBs:
        red_sl   = sprintf("%02x", (red_bg   + red_fg)   / 2)
        green_sl = sprintf("%02x", (green_bg + green_fg) / 2)
        blue_sl  = sprintf("%02x", (blue_bg  + blue_fg)  / 2)
        slcolor  = "#" red_sl green_sl blue_sl

        # Calculate topShadowColor RGB-values from background-color RGB:
        if (brightness(red_bg, green_bg, blue_bg) > brightness(red_fg, green_fg, blue_fg))
            factor = 1.4    # default value
        else
            factor = 0.7    # "inverted" value (proposed)

        red_ts   = sprintf("%02x", min(255, factor * red_bg))
        green_ts = sprintf("%02x", min(255, factor * green_bg))
        blue_ts  = sprintf("%02x", min(255, factor * blue_bg))
        tscolor  = "#" red_ts green_ts blue_ts
    }
    /selectColor/ {
        sub(/( |	)+c( |	)+[^ ",	]+/, "") # Remove existing "c"-field
        sub(/(",$)/, " c " slcolor "\",")    # Add new "c"-field with given slcolor
    }
    /topShadowColor/ {
        sub(/( |	)+c( |	)+[^ ",	]+/, "") # Remove existing "c"-field
        sub(/(",$)/, " c " tscolor "\",")    # Add new "c"-field with given tscolor
    }
    {
        sub(/bottomShadowColor/, "foreground")
        print
    }' "$image"
}


#======================== MAIN FUNCTION STARTS HERE ========================#


# Execute the options:
options "$@"
shift $(( OPTIND - 1 ))

image="$1"
(( $# >= 2 )) && bg="$2"
(( $# == 3 )) && fg="$3"

# In case of X11-color-names for background- and/or foreground-color, retrieve RGB-values:
[[ -n "$bg" ]] && [[ "${bg//\//}" == "$bg" ]] && bg=$(name2rgb "$bg")
[[ -n "$fg" ]] && [[ "${fg//\//}" == "$fg" ]] && fg=$(name2rgb "$fg")

# Get foreground color (and background color) if not given for current workspace:
if $calculate_fgcolor && (( $# >= 2 )); then
    fg="$(get_fgcolor "$bg")"
elif (( $# == 2 )); then
    fg="$(tellrgb "Foreground")"
elif (( $# == 1 )); then
    bg="$(tellrgb "Background")"
    fg="$(tellrgb "Foreground")"
fi

#  If image is an XBM, and bg/fg-combination causes a "White Backdrop" (Motif-bug), slightly change fg:
if grep -qE "\.x?bm$" <<< "$image"; then
    $(testwhite "$bg" "$fg") && fg="$(shiftcolor "$fg")" # Therefore name2rgb() needed for xbm too
fi

# If image is an XPM, derive a modified version with adapted 's'- and 'c'-fields in color string:
if grep -qE "\.x?pm$" <<< "$image"; then
    mkdir "$tempdir/$subdir"                            # New subdir needed for tellmwm() to show image
    new_image="${image/*\//}"                           # Edited XPM file keeps same name
    convert_xpm $image >| "$tempdir/$subdir/$new_image" # tellmwm ignores image if process-substitution
    image="$tempdir/$subdir/$new_image"                 # Full path needed
fi

# Set desired colors and image as backdrop for current workspace:
tellmwm backdrop $workspace -b "$bg" -f "$fg" "$image" 2>/dev/null

[[ -d "$tempdir/$subdir" ]] && rm -rf "$tempdir/$subdir"
