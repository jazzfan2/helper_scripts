#!/bin/bash
# Name: randombackdrop.sh
# Author: R.J.Toscani
# Date: 5th of May 2026
# Description: Random-cycling of colors and Motif/X11(CDE)-backdrop images,
# particularly - but not limited to - (x)bm and (x)pm formats.
#
# Wrapper around the 'xmbackdrop.sh' script. Engine: the 'tellmwm()' program
# by Alexander Pampuchin (workspace control utility for the 'Enhanced Motif
# Window Manager (EMWM)' https://fastestcode.org/ - LGPLv3, MIT License).
# Version for EMWM v2.0 and higher.
#
# Meant to act as a background daemon called from the $HOME/.sessionetc
# file (i.e. the 'startup applications' file read by EMWM's session manager).
#
#############################################################################
#
# Copyright (C) 2026 Rob Toscani <rob_toscani@yahoo.com>
#
# randombackdrop.sh is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# randombackdrop.sh is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
############################################################################


if [[ -d /tmp/ramdisk/ ]]; then
    ramdir="/tmp/ramdisk"
elif [[ -d /dev/shm/ ]]; then
    ramdir="/dev/shm"
else
    ramdir="."         # (No RAM, serves as fall back scenario)
fi

# Copy 'xmbackdrop.sh' script to RAM-memory if possible in order to run it from there:
cp $HOME/scripts/xmbackdrop.sh $ramdir/xmbackdrop.sh

# Image-sources:
# https://sourceforge.net/projects/cdesktopenv/
# http://cs.gettysburg.edu/~duncjo01/archive/patterns/cde/
# http://cs.gettysburg.edu/~duncjo01/archive/patterns/OEM/Sun/texture/
imagedir1="/usr/dt/share/backdrops"
imagedir2="$HOME/Documenten/Ubuntu-Linux/EMWM/wallpapers/cde"
imagedir3="$HOME/Documenten/Ubuntu-Linux/EMWM/wallpapers/sun"


#=============================== FUNCTIONS ================================#


options(){
# Specify options:
    while getopts "cgGhnp:Psi" OPTION; do
        case $OPTION in
            c) complementarynext=1 # Next color complementary to previous (end) color
               ;;
            g) gradual=1           # Gradual shift to random end-color
               ;;
            G) crossover=1         # Gradual shift to complementary end-color
               gradual=1
               ;;
            h) helptext>&2
               exit 0
               ;;
            n) image=0             # No CDE backdrop images (overrules option -f)
               strongcontrast=0
               ;;
            p) period="$OPTARG"    # Specify period
               ;;
            P) xpm_only=1          # Accept XPM-files only, omit XBM-files
               ;;
            s) strongcontrast=1    # Strong color-contrast by complementary foreground
               (( ! image )) && strongcontrast=0
               ;;
            i) identicalnext=1     # Next color identical to previous (end-)color
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
		Usage: randombackdrop.sh [-icgGhnpPs] [-p PERIOD]

		-i   Next (start-)color is identical to previous (end-)color.
		-c   Next (start-)color complementary to previous (end-)color
		     (Overrules -i).
		-g   Gradual shift from start-color to random end-color.
		     (= next start-color if -c or -i not given).
		-G   Gradual shift from start-color to complementary end-color
		     (= next start-color if -c or -i not given). Overrules -g.
		-h   Help (this output).
		-n   Only backdrop colors, no images (overrules option -f).
		-p   Specify period (default = 60 seconds).
		-P   Accept XPM-files only, omit XBM-files
		-s   Strong color-contrast by complementary foreground-color
	EOF
}

cycle()
# Periodically set temporary color and image as current workspace backdrop:
{
    # Generate a random RGB-combination:
    start=$(random_rgb)
    color=start
    while true; do
        if (( image )); then
            (( maxindex = ${#imagelist[@]} ))
            # Generate a random array index-number:
            index=$(shuf --random-source=/dev/urandom -i 1-$maxindex -n 1)
        else
            index=0  # No image (in case of the -n option)
        fi
        # Start color gradually shifting into another (end) color during every $period, etc:
        if (( gradual )); then
            # End color is complementary to start color:
            if (( crossover )); then
                end=$(complement $start)
            # End color is randomly chosen:
            else
                end=$(random_rgb)
            fi
            gradualshift "$start" "$end" |
            while read gradation; do
                backdrop $gradation $index
                sleep 0.5
            done
            # Next shifting start color is complementary to previous end color:
            if (( complementarynext )); then
                start=$(complement $end)
            # Next shifting start color is identical to previous end color:
            elif (( identicalnext )); then
                start=$end
            # Next shifting start color is randomly chosen (= default gradual behaviour):
            else
                start=$(random_rgb)
            fi
        # Static color switching to complementary color after every $period:
        elif (( complementarynext )); then
            backdrop $(complement $color) $index
            sleep $period
        # Static color remaining identical:
        elif (( identicalnext )); then
            continue
        # Static color switching to random color after every $period (= default static behaviour):
        else
            backdrop $(random_rgb) $index
            sleep $period
        fi
    done
}

random_rgb()
# Return random rgb-combination:
{
    echo "$(randomgrade)/$(randomgrade)/$(randomgrade)"
}

randomgrade()
# Return random grade of rgb-component:
{
    shuf --random-source=/dev/urandom -i 0-255 -n 1
}

complement()
# Return complementary grade of red, green or blue color component:
{
    awk '\
    BEGIN { FS = "/" }
    {
        red_comp   = 255 - $1
        green_comp = 255 - $2
        blue_comp  = 255 - $3
        print red_comp"/"green_comp"/"blue_comp
    }' <<< "$1"
}

gradualshift()
# Gradually shift from start-color to end-color:
{
    startcolor="$1"
    endcolor="$2"

    awk -v period=$period '\
    BEGIN { FS = "/" }
    {
        startred   = $1
        startgreen = $2
        startblue  = $3
        redrange   = $4 - $1
        greenrange = $5 - $2
        bluerange  = $6 - $3

        elapsed = 0
        while (elapsed < 2*period){
            red   = startred   + elapsed * redrange   / (2 * period)
            green = startgreen + elapsed * greenrange / (2 * period)
            blue  = startblue  + elapsed * bluerange  / (2 * period)
            print red "/" green "/" blue
            elapsed += 1
        }
    }' <<< "$startcolor/$endcolor"
}

dec2hex()
# Convert color from decimal 'red/green/blue' to hexadecimal 'rgb:redx/greenx/bluex' notation:
{
    awk '\
    BEGIN { FS = "/" }
    {
        redx   = sprintf("%02x", $1)
        greenx = sprintf("%02x", $2)
        bluex  = sprintf("%02x", $3)
        print "rgb:" redx "/" greenx "/" bluex
    }' <<< "$1"
}

backdrop()
# Set color and optionally the image of window 0 backdrop:
{
    color=$(dec2hex $1)
    index=$2

    if (( image && strongcontrast )); then
        compcolor=$(dec2hex $(complement $1))
        $ramdir/xmbackdrop.sh "$tmpfiledir/${imagelist[index]}" "$color" "$compcolor"
    elif (( image )); then
        $ramdir/xmbackdrop.sh -f "$tmpfiledir/${imagelist[index]}" "$color"
    elif (( ! image )); then
        $ramdir/xmbackdrop.sh "none" "$color"
    fi
    # For debug purposes (uncomment for output to logfile):
    echo -e "$color\t$tmpfiledir/${imagelist[index]}" >> $HOME/backdroplog.txt
}


#======================== MAIN FUNCTION STARTS HERE ========================#


# Stop any other "randombackdrop"-process already running:
while read process; do
    [[ $process != $$ ]] && kill -15 $process 2>/dev/null
done < <(ps aux | grep "/bin/bash $HOME/scripts/randombackdrop.sh" | \
         awk '{ print $2 }')

# Defaults:
period=60            # Period = 60 seconds
image=1              # Include CDE backdrop images
complementarynext=0  # Next color not complementary to previous color
gradual=0            # No gradual shift from start-color to end-color
crossover=0          # End-color not complementary to start-color
identicalnext=0      # Next color not identical to previous (end-)color
strongcontrast=0     # No strong color-contrast by complementary foreground-color
xpm_only=0           # Accept both XPM- and XBM-files

# Execute the options:
options $@

# Minimize period to 1 second:
if (grep -q [^0-9] <<< "$period" || [[ $period < 1 ]]); then
    period=1
fi

# Create subdirectory in RAM where the bitmaps and pixmaps will be strored temporarily:
tmpfiledir="$ramdir/backdrops$RANDOM"

# Stop the program in case of an interrupt (Ctrl-C) or terminate signal:
trap "[[ -d $tmpfiledir ]] && \rm -rf $tmpfiledir; exit" SIGINT SIGTERM

# Copy the CDE backdrop-images (pixmap and bitmap) to the temporary directory
# (except in if -n option is given):
if (( image )); then
    mkdir $tmpfiledir
    while read path; do
        \cp $path/{*.pm,*.xpm} $tmpfiledir 2>/dev/null
        if (( ! xpm_only )); then
            \cp $path/{*.bm,*.xbm} $tmpfiledir 2>/dev/null
        fi
    done << EOF
$imagedir1
$imagedir2
$imagedir3
EOF
    # Remove some non-desired backdrops from the temporary directory
    # (either because of lack of figuration, insufficient height or negative
    # representation w/ most colors):
    while read omissions; do
        \rm $tmpfiledir/$omissions
    done << EOF
Background.*
Foreground.*
black.*
white.*
Gray*
grey.*
NoBackdrop.*
SkyDark.*pm
SkyLight.*pm
Toronto.*bm
BrickWall.*bm
EOF

    # Make an array (global variable) in which all image names are to be stored:
    declare -a imagelist

    # Store all image names within the temporary directory into the array:
    index=1
    while read imagename; do
        imagelist[index]="$imagename"
        (( index += 1 ))
    done < <(ls $tmpfiledir)
fi

# Periodically set temporary color and image as current workspace backdrop:
cycle