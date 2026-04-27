#!/bin/bash
# Name: xmbackdrop.sh
# Author: Rob Toscani
# Date: 26 april 2026
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
# BUG (tellmwm): with .xpm images, rendering is sometimes not monochrome as
# with xbackdrop but includes black, white and grey-shades as well,
# as tellmwm() doesn't use foreground-color with (X)PM (only background-color).
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

convert_xpm=0       # Initial state: no conversion from (X)PM image to (X)BM format
calculate_fgcolor=0 # Initial state: no calculation of foreground color

# Determine current workspace:
workspace=$(tellmwm | tail -n 1 | awk '{ print $NF }')

options(){
# Specify options:
    while getopts "fxh" OPTION; do
        case $OPTION in
            f) calculate_fgcolor=1  # Calculate foreground- from background-color
               ;;
            x) convert_xpm=1        # Convert (X)PM image to (X)BM format
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
		Usage: xmbackdrop.sh [-fxh] IMAGE [BACKGROUNDCOLOR [FOREGROUNDCOLOR]]

		-f   Calculate foreground-color from background-color if given
		-x   Convert (X)PM image to (X)BM format
		-h   Help (this output).
	EOF
}

get_fgcolor()
# Calculate foreground-color RGB from given background-color RGB and brightness:
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

        printf ("%f\t%s\t", brightness, "-b rgb:"$1"/"$2"/"$3) > "/dev/stderr"

        # Calculate foreground RGB-values from background RGB- and brightness-values:
        factor       = 1
        offset_red   = 0
        offset_green = 0
        offset_blue  = 0
        if ( brightness < DarkThreshold ){
            offset_red   = 0.2 * (255 - red)
            offset_green = 0.2 * (255 - green)
            offset_blue  = 0.2 * (255 - blue)
        }
        else if ( brightness > LightThreshold )
            factor = 0.5
        else
            factor = 0.6

        redfg   = sprintf("%02x", red   * factor + offset_red)
        greenfg = sprintf("%02x", green * factor + offset_green)
        bluefg  = sprintf("%02x", blue  * factor + offset_blue)

        printf ("%s\n", "-f rgb:"redfg"/"greenfg"/"bluefg) > "/dev/stderr"

        print "rgb:"redfg"/"greenfg"/"bluefg
    }' <<< "${rgb/*:/}"
}

tellrgb()
# Report rgb of argument-string "Background" or "Foreground":
{
    (( nr = ${workspace/ws/} + 1 ))
    rgb=$(tellmwm | grep "$1" | head -n $nr | tail -n -1 | awk '{ print $NF }')
    echo "rgb:${rgb:1:2}/${rgb:3:2}/${rgb:5:2}"
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
    image="$1"
    bg=$(combinecolor "$2")
    fg=$(combinecolor "$3")

    mod=31
    (( remainder = bg % mod ))
    (( badfg = 65805 + (remainder >= 13) * mod - remainder ))
    (( (fg - badfg) % mod == 0 )) && echo 1 || echo 0  # Remainder = 0 gives white result
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
        blue  = sprintf("%02x", strtonum("0x" $3) + 0x01)
        print "rgb:"red"/"green"/"blue
    }' <<< "${rgb/*:/}"
}

# Execute the options:
options "$@"
shift $(( OPTIND - 1 ))

# Main function starts here:
image="$1"
(( $# >= 2 )) && bgcolor="$2"
(( $# == 3 )) && fgcolor="$3"

# With option -x, if image is (X)PM, convert to (X)BM to get real monochrome result:
if (( convert_xpm )) && grep -qE "\.x?pm$" <<< "$1"; then
   image="/tmp/ramdisk/backdrop.xbm" # Waarom werkt het met $RANDOM in de naam niet?
   convert "$1" xbm:- >| "$image"
fi

# Get foreground color (and background color) if not given for current workspace:
if (( calculate_fgcolor )) && (( $# >= 2 )); then
    fgcolor=$(get_fgcolor "$bgcolor")
elif (( $# == 2 )); then
    fgcolor="$(tellrgb "Foreground")"
elif (( $# == 1 )); then
    bgcolor="$(tellrgb "Background")"
    fgcolor="$(tellrgb "Foreground")"
fi

# If combination results in a flat white backdrop, slightly change background-color:
(( $(testwhite "$image" "$bgcolor" "$fgcolor") )) && bgcolor="$(shiftcolor "$bgcolor")"

# Set desired image and color(s) as backdrop for current workspace:
tellmwm backdrop $workspace -b "$bgcolor" -f "$fgcolor" "$image"
