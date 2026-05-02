#!/bin/bash
# Name: xmbackdrop.sh
# Author: Rob Toscani
# Date: 2nd May 2026
# Description: Set backdrop image and optional color(s) for current EMWM workspace.
#
# Wrapper script around the 'tellmwm()' program by Alexander Pampuchin
# (part of the 'Enhanced Motif Window Manager (EMWM)' - https://fastestcode.org/
# - LGPLv3, MIT License), which as a prerequisite must have been installed in
# order for this script to function.
# EMWM version must be at least v2.0 to use this program.
#
# Possible future feature: if $1 equals 'same', then the *current* image will
# be set with specified color(s).
# Method: use 'tellmwm' command and some filtering to determine existing image
# used with current workspace.
#
# BUG: foreground-color calculation function only supports
# "rgb:<red>/<green>/<blue>" color-notation for now,
# Color *names* aren´t supported as of yet (under development).
#
#############################################################################
#
# Copyright (C) 2026 Rob Toscani <rob_toscani@yahoo.com>
#
# xmbackdrop.sh is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# xmbackdrop.sh is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
############################################################################
#

calculate_fgcolor=0 # Initial state: no calculation of foreground color

# Determine where the modified pixmap file can be stored in RAM temporarily:
if [[ -d /tmp/ramdisk/ ]]; then
    tempdir="/tmp/ramdisk"
elif [[ -d /dev/shm/ ]]; then
    tempdir="/dev/shm"
else
    tempdir="."               # (No RAM, serves as fall back scenario)
fi

# Names of RAM-subdirectory and modified pixmap file:
subdir="subdir_$RANDOM$RANDOM"
new_image="image_$RANDOM$RANDOM"

# Determine current workspace:
workspace=$(tellmwm | tail -n 1 | awk '{ print $NF }')


options(){
# Specify options:
    while getopts "fh" OPTION; do
        case $OPTION in
            f) calculate_fgcolor=1  # Calculate foreground- from background-color
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
        Usage: xmbackdrop.sh [-fh] IMAGE [BACKGROUNDCOLOR [FOREGROUNDCOLOR]]

        -f   Calculate foreground-color from background-color if given
        -h   Help (this output).

        Arguments:
        IMAGE            Full path to image file
        BACKGROUNDCOLOR  Hexadecimal background RGB in format "rgb:1C/87/fa" (example)
        FOREGROUNDCOLOR  Hexadecimal foregorund RGB in format "rgb:08/66/9f" (example)
	EOF
}

get_fgcolor()
# Calculate foreground color RGB from given background RGB and brightness:
{
    rgb="$1"
    awk '\
    BEGIN { FS = "/" }
    {
        DarkThreshold  = 15
        LightThreshold = 93

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
# Report rgb of argument-string "Background" or "Foreground":
{
    (( nr = ${workspace/ws/} + 1 ))
    tellmwm | grep "$1" | head -n $nr | tail -n -1 |
    awk '{ print "rgb:"substr($NF,1,3)"/"substr($NF,4,2)"/"substr($NF,6,2) }'
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
# Test if background/foreground combination results in a white backdrop (Motif-bug!):
{
    awk -v bg=$(combinecolor "$1") -v fg=$(combinecolor "$2") '\
    BEGIN {
        mod=31
        remainder = bg % mod
        badfg = 65805 + (remainder >= 13) * mod - remainder
        if ((fg - badfg) % mod == 0)
            print 1           # Remainder = 0 gives white result
        else
            print 0
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
# Add monochrome shades in the XPM-file, based on the background- and foregound-colors, by:
# 1. Calculating 'selectColor' & 'topShadowColor' RGB values from background- and foregound-colors,
# 2. Updating the 'c'-field by these values in the color strings containing these symbolic color names,
# 3. Renaming the 's'-field named 'bottomShadowColor' to 'foreground':
{
    awk -v bgcolor=$bgcolor -v fgcolor=$fgcolor '\
    function min(a, b){
        if (a <= b)
            return a
        else
            return b
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

        # Calculate topShadowColor RGB-values from background-color RGB (or extrapolate?):
        red_ts   = sprintf("%02x", min(255, 1.4 * red_bg))   # Or should we extrapolate beyond fg & bg gradient?
        green_ts = sprintf("%02x", min(255, 1.4 * green_bg)) # Same question
        blue_ts  = sprintf("%02x", min(255, 1.4 * blue_bg))  # Same question
        tscolor  = "#" red_ts green_ts blue_ts
    }
    /selectColor/ {\
        sub(/( |	)+c( |	)+[^ ",	]+/, "") # Remove existing "c"-field
        sub(/(",$)/, " c " slcolor "\",")    # Add new "c"-field with given slcolor
    }
    /topShadowColor/ {\
        sub(/( |	)+c( |	)+[^ ",	]+/, "") # Remove existing "c"-field
        sub(/(",$)/, " c " tscolor "\",")    # Add new "c"-field with given tscolor
    }
    {
        sub(/bottomShadowColor/, "foreground")
        print
    }' "$1"
}


# Execute the options:
options "$@"
shift $(( OPTIND - 1 ))

# Main function starts here:
image="$1"
(( $# >= 2 )) && bgcolor="$2"
(( $# == 3 )) && fgcolor="$3"

# Get foreground color (and background color) if not given for current workspace:
if (( calculate_fgcolor )) && (( $# >= 2 )); then
    fgcolor="$(get_fgcolor "$bgcolor")"
elif (( $# == 2 )); then
    fgcolor="$(tellrgb "Foreground")"
elif (( $# == 1 )); then
    bgcolor="$(tellrgb "Background")"
    fgcolor="$(tellrgb "Foreground")"
fi

# If combination will result in a flat white backdrop, slightly change foreground-color:
(( $(testwhite "$bgcolor" "$fgcolor") )) && fgcolor="$(shiftcolor "$fgcolor")"

# If image is an XPM, derive a modified version with adapted 's'- and 'c'-fields in color string:
if grep -qE "\.x?pm$" <<< "$image"; then
    mkdir "$tempdir/$subdir"
    convert_xpm $image >| "$tempdir/$subdir/$new_image"
    image="$tempdir/$subdir/$new_image"
fi

# Set desired colors and image as backdrop for current workspace:
tellmwm backdrop $workspace -b "$bgcolor" -f "$fgcolor" "$image"

[[ -d "$tempdir/$subdir" ]] && rm -rf "$tempdir/$subdir"
