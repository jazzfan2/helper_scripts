#!/bin/bash
# Name: randombackdrop.sh
# Author: R.J.Toscani
# Date: 9th of May 2026
# Description: Random-cycling of colors and Motif/X11(CDE)-backdrop images,
# particularly - but not limited to - (x)bm and (x)pm formats.
#
# Wrapper around the 'wsbackdrop.sh' script. Engine: the 'tellmwm()' program
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

# Copy 'wsbackdrop.sh' script to RAM-memory if possible in order to run it from there:
\cp $HOME/scripts/wsbackdrop.sh $ramdir/wsbackdrop.sh

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
    while getopts "cf:gGhnp:Prsi" OPTION; do
        case $OPTION in
            c) complementarynext=1  # Next color complementary to previous (end) color.
               ;;
            f) fixed=1              # Fixed image.
               image_path="$OPTARG"
               ;;
            g) gradual=1            # Gradual shift to random end-color
               ;;
            G) crossover=1          # Gradual shift to complementary end-color.
               gradual=1
               ;;
            h) helptext>&2          # Print help text.
               exit 0
               ;;
            n) image=0              # No CDE backdrop images.
               ;;
            p) period="$OPTARG"     # Specify period
               ;;
            P) xpm_only=1           # Accept XPM-files only, omit XBM-files
               ;;
            r) randomforeground=1   # Random foreground color, independent from background
               ;;
            s) strongcontrast=1     # Strong color-contrast by complementary foreground
               ;;
            i) identicalnext=1      # Next color identical to previous (end-)color
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
		Usage: randombackdrop.sh [-icfgGhnpPrs] [-p PERIOD]

		-i       Next (start-)color pair is identical to previous (end-)color
		         pair.
		-c       Next (start-)color pair complementary to previous (end-)color
		         pair. Overrides -i.
		-f IMAGEPATH
		         Fixed image, with full IMAGEPATH to file. Overrides -P.
		-g       Gradual shift from start-color pair to random end-color pair.
		-G       Gradual shift from start-color pair to complementary
		         end-color pair. Overrides -g.
		-h       Help (this output).
		-n       Only backdrop colors, no images. Overrides -f, -s and -r.
		-p PERIOD
                 Specify cycling PERIOD in seconds (default = 60).
		-P       Accept XPM-files only, omit XBM-files.
		-r       Random foreground color, unrelated to background color.
		         Overrides -s.
		-s       Strong contrasting foreground-color, complementary to
			     background color.
	EOF
}

cycle()
# Periodically set image, background color and independent foreground color, and call backdrop():
{
    # Generate two independent random RGB-combinations:
    start1=$(random_rgb)
    start2=$(random_rgb)
    color1=start1         # Background color
    color2=start2         # Foreground color (independent from backgrond color)
    while true; do
        if (( image )); then
            (( maxindex = ${#imagelist[@]} ))
            # Generate a random array index-number:
            index=$(shuf --random-source=/dev/urandom -i 1-$maxindex -n 1)
        else
            index=0  # No image (in case of the -n option)
        fi
        # Start colors gradually shifting into another pair of (end) colors during every $period, etc:
        if (( gradual )); then
            # End colors are complementary to start colors:
            if (( crossover )); then
                end1=$(complement $start1);
                end2=$(complement $start2)
            # End colors are randomly chosen:
            else
                end1=$(random_rgb)
                end2=$(random_rgb)
            fi
            gradualshift "$start1" "$end1" "$start2" "$end2" |
            while read gradation_pair; do
                gradation1=${gradation_pair/:*/}  # Background color gradation
                gradation2=${gradation_pair/*:/}  # Foreground color gradation (independent)
                backdrop $gradation1 $gradation2 $index
                sleep 0.5
            done
            # Next shifting start colors are complementary to previous end colors:
            if (( complementarynext )); then
                start1=$(complement $end1)
                start2=$(complement $end2)
            # Next shifting start colors are identical to previous end colors:
            elif (( identicalnext )); then
                start1=$end1
                start2=$end2
            # Next shifting start colors are randomly chosen (= default gradual behaviour):
            else
                start1=$(random_rgb)
                start2=$(random_rgb)
            fi
        # Static colors switching to complementary colors after every $period:
        elif (( complementarynext )); then
            color1=$(complement $color1)
            color2=$(complement $color2)
            backdrop $color1 $color2 $index
            sleep $period
        # Static colors remaining identical:
        elif (( identicalnext )); then
            continue
        # Static colors switching to random colors after every $period (= default static behaviour):
        else
            color1=$(random_rgb)
            color2=$(random_rgb)
            backdrop $color1 $color2 $index
            sleep $period
        fi
    done
}

random_rgb()
# Return random RGB-combination:
{
    echo "$(randomgrade)/$(randomgrade)/$(randomgrade)"
}

randomgrade()
# Return random grade of one RGB-component:
{
    shuf --random-source=/dev/urandom -i 0-255 -n 1
}

complement()
# Return RGB-combination complementary to given RGB-combination:
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
# Gradually shift from start-color1 to end-color1, and from start-color2 to end-color2:
{
    startcolor1="$1"    # Background color (start)
    endcolor1="$2"      # Background color (end)
    startcolor2="$3"    # Foreground color (start, independent from background color)
    endcolor2="$4"      # Foreground color (end, independent from background color)

    awk -v period=$period '\
    BEGIN { FS = "/" }
    {
        startred1   = $1;   redrange1   = $4 - $1
        startgreen1 = $2;   greenrange1 = $5 - $2
        startblue1  = $3;   bluerange1  = $6 - $3

        startred2   = $7;   redrange2   = $10 - $7
        startgreen2 = $8;   greenrange2 = $11 - $8
        startblue2  = $9;   bluerange2  = $12 - $9

        elapsed = 0
        while (elapsed < 2*period){
            red1   = startred1   + elapsed * redrange1   / (2 * period)
            green1 = startgreen1 + elapsed * greenrange1 / (2 * period)
            blue1  = startblue1  + elapsed * bluerange1  / (2 * period)
            red2   = startred2   + elapsed * redrange2   / (2 * period)
            green2 = startgreen2 + elapsed * greenrange2 / (2 * period)
            blue2  = startblue2  + elapsed * bluerange2  / (2 * period)
            print red1 "/" green1 "/" blue1 ":" red2 "/" green2 "/" blue2
            elapsed += 1
        }
    }' <<< "$startcolor1/$endcolor1/$startcolor2/$endcolor2"
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
# Set color(s) and optionally the image of the backdrop for the current workspace:
{
    color1=$(dec2hex $1)   # Background color
    color2=$(dec2hex $2)   # Foreground color (independent from backgrond color)
    index=$3

    if (( image && randomforeground )); then   # independent foreground color
        $ramdir/wsbackdrop.sh "$tmpfiledir/${imagelist[index]}" "$color1" "$color2"
    elif (( image && strongcontrast )); then   # complementary foreground color
        compcolor=$(dec2hex $(complement $1)) 
        $ramdir/wsbackdrop.sh "$tmpfiledir/${imagelist[index]}" "$color1" "$compcolor"
    elif (( image )); then                     # foreground is calculated by wsbackdrop.sh
        $ramdir/wsbackdrop.sh -f "$tmpfiledir/${imagelist[index]}" "$color1"
    elif (( ! image )); then                   # image and foreground color omitted
        $ramdir/wsbackdrop.sh "none" "$color1"
    fi
    # For debug purposes (uncomment for output to logfile):
    echo -e "$(date)\t$color1\t$tmpfiledir/${imagelist[index]}" >> $HOME/backdroplog.txt
}


#======================== MAIN FUNCTION STARTS HERE ========================#


# Stop any other "randombackdrop"-process already running:
while read process; do
    [[ $process != $$ ]] && kill -15 $process 2>/dev/null
done < <(ps aux | grep "/bin/bash $HOME/scripts/randombackdrop.sh" | \
         awk '{ print $2 }')

# Defaults:
fixed=0              # No single fixed image
period=60            # Period = 60 seconds
image=1              # Include CDE backdrop images
complementarynext=0  # Next color not complementary to previous color
gradual=0            # No gradual shift from start-color to end-color
crossover=0          # End-color not complementary to start-color
identicalnext=0      # Next color not identical to previous (end-)color
strongcontrast=0     # No strong color-contrast by complementary foreground-color
randomforeground=0   # No independent foreground-color
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
if (( image)); then
    mkdir $tmpfiledir
    if (( fixed )); then
        \cp $image_path $tmpfiledir 2>/dev/null
    else
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
            \rm $tmpfiledir/$omissions 2>/dev/null
        done << EOF
Background.*
Foreground.*
black.*
white.*
Gray*
grey.*
inversegrey.*
NoBackdrop.*
Pattern50.*
Ridged.*
SkyDark.*pm
SkyLight.*pm
Toronto.*bm
BrickWall.*bm
EOF

    fi

    # Make an array (global variable) in which all image names are to be stored:
    declare -a imagelist

    # Store all image names within the temporary directory into the array:
    index=1
    while read imagename; do
        imagelist[index]="$imagename"
        (( index += 1 ))
    done < <(ls $tmpfiledir)
fi

# Periodically set color(s) and/or image as current workspace backdrop:
sleep 0.4   # To prevent overriding by global setting at start of EMWM session
cycle
