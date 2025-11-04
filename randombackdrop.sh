#!/bin/bash
# Name: randombackdrop.sh
# Author: R.J.Toscani
# Date: 29th of June 2025
# Description: Random-cycling of colors and Motif/X11(CDE)-backdrop images,
# particularly - but not limited to - (x)bm and (x)pm formats.
#
# Wrapper script around the 'xbackdrop' program by Alexander Pampuchin
# (part of the 'Enhanced Motif Window Manager (EMWM)' - https://fastestcode.org/
# - LGPLv3, MIT License), which as a prerequisite must have been installed in
# order for this script to function.
#
# Meant to function as a background daemon called from the $HOME/.sessionetc
# file (i.e. the 'startup applications' file read by EMWM's session manager).
#
#############################################################################
#
# Copyright (C) 2025 Rob Toscani <rob_toscani@yahoo.com>
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

options(){
# Specify options:
    while getopts "cgGhnp:i" OPTION; do
        case $OPTION in
            c) complementarynext=1 # Next color complementary to previous (end) color
               ;;
            g) gradual=1           # Gradual shift to random end color
               ;;
            G) crossover=1         # Gradual shift to complementary end color
               gradual=1
               ;;
            h) helptext>&2
               exit 0
               ;;
            n) image=0             # No CDE backdrop images
               ;;
            p) period="$OPTARG"    # Specify period
               ;;
            i) identicalnext=1     # Next color identical to previous (end) color
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
		Usage: randombackdrop.sh [-icgGhnp] [-p PERIOD]

		-i   Next (start) color is identical to previous (end) color
		-c   Next (start) color complementary to previous (end) color.
		     (Overrules -i.)
		-g   Gradual shift from start color to random end color.
		     (= next start color if -c or -i not given.)
		-G   Gradual shift from start color to complementary end color .
		     (= next start color if -c or -i not given). Overrules -g.
		-h   Help (this output).
		-n   Only backdrop colors, no images.
		-p   Specify period (default = 60 seconds).
	EOF
}


randomgrade()
# Return random grade of red, green or blue color component:
{
    echo "$(shuf --random-source=/dev/urandom -i 0-255 -n 1)"
}

complement()
# Return complementary grade of red, green or blue color component:
{
    echo $((255 - $1))
}

backdrop()
# Set color and optionally the image of window 0 backdrop:
{
    red_hex=$(  printf "%02X" "$red")
    green_hex=$(printf "%02X" "$green")
    blue_hex=$( printf "%02X" "$blue")

    color="rgb:$red_hex/$green_hex/$blue_hex"

    if (( image )); then
        xbackdrop -c "$color" "$tmpfiledir/${imagelist[index]}"
    else
        xbackdrop -c "$color"
    fi
    # For debug purposes (uncomment for output to logfile):
    echo -e "$color\t$tmpfiledir/${imagelist[index]}" >> $HOME/backdroplog.txt
}


# Stop any other "randombackdrop"-process already running:
while read process; do
    [[ $process != $$ ]] && kill -15 $process 2>/dev/null
done < <(ps aux | grep "/bin/bash $HOME/scripts/randombackdrop.sh" | \
         awk '{ print $2 }')

# Default period = 60 seconds, and default include CDE backdrop images:
period=60
image=1
complementarynext=0
gradual=0
crossover=0
identicalnext=0

# Execute the options:
options $@

# Minimize period to 1 second:
if (grep -q [^0-9] <<< "$period" || [[ $period < 1 ]]); then
    period=1
fi


# Determine where the bitmaps and pixmaps must be stored in RAM temporarily:
if [[ -d /tmp/ramdisk/ ]]; then
    tmpfiledir="/tmp/ramdisk/backdrops$RANDOM"
elif [[ -d /dev/shm/ ]]; then
    tmpfiledir="/dev/shm/backdrops$RANDOM"
else
    tmpfiledir="./backdrops$RANDOM"
fi

# Stop the program in case of an interrupt (Ctrl-C) or terminate signal:
trap "[[ -d $tmpfiledir ]] && \rm -rf $tmpfiledir; exit" SIGINT SIGTERM

# In case the -n option is not given, copy the CDE backdrop-images (bitmap and
# pixmap) to the temporary directory:
if (( image )); then
    # Sources: https://sourceforge.net/projects/cdesktopenv/
    # http://cs.gettysburg.edu/~duncjo01/archive/patterns/cde/
    # http://cs.gettysburg.edu/~duncjo01/archive/patterns/OEM/Sun/texture/
    mkdir $tmpfiledir
    cp /usr/dt/share/backdrops/*.bm $tmpfiledir
    \cp /usr/dt/share/backdrops/*.pm $tmpfiledir
    \cp $HOME/Documenten/Ubuntu-Linux/EMWM/wallpapers/cde/*bm $tmpfiledir
    \cp $HOME/Documenten/Ubuntu-Linux/EMWM/wallpapers/cde/*pm $tmpfiledir
    \cp $HOME/Documenten/Ubuntu-Linux/EMWM/wallpapers/sun/*bm $tmpfiledir
    \cp $HOME/Documenten/Ubuntu-Linux/EMWM/wallpapers/sun/*pm $tmpfiledir
    # Remove some non-desired backdrops from the temporary directory:
    \rm $tmpfiledir/Background.*     # This only provides color, no figuration
    \rm $tmpfiledir/Foreground.*     # This only provides color, no figuration
    \rm $tmpfiledir/black.*          # This only provides color, no figuration
    \rm $tmpfiledir/white.*          # This only provides color, no figuration
    \rm $tmpfiledir/Gray*            # This only provides color, no figuration
    \rm $tmpfiledir/NoBackdrop.*     # This only gives a black screen
    \rm $tmpfiledir/SkyDark.*pm      # Unmodified version w/ insufficient height
    \rm $tmpfiledir/SkyLight.*pm     # Unmodified version w/ insufficient height
    \rm $tmpfiledir/Toronto.*bm      # Negative representation w/ most colors
    \rm $tmpfiledir/BrickWall.*bm    # Negative representation w/ most colors
#   \rm $tmpfiledir/SunLogo.*pm      # Doesn´t adapt to color

    # Make an array in which all image names are to be stored:
    declare -a imagelist

    # Store all image names within the temporary directory into the array:
    index=0
    while read imagename; do
        imagelist[index]="$imagename"
        (( index += 1 ))
    done < <(ls $tmpfiledir)

    (( maxindex = ${#imagelist[@]} - 1 ))
fi

startred=$(  randomgrade); red=startred
startgreen=$(randomgrade); green=startgreen
startblue=$( randomgrade); blue=startblue


# Periodically generate a random RGB-combination and a random array index-number,
# each defining temporary color and image for the root window backdrop,
# or only the color in case of the -n option:
while true; do

    if (( image )); then
        index=$(shuf --random-source=/dev/urandom -i 0-$maxindex -n 1)
    fi

    # Start color gradually shifting into another (end) color during every $period, etc:
    if (( gradual )); then

        # End color is complementary to start color:
        if (( crossover )); then
            endred=$(  complement $startred)
            endgreen=$(complement $startgreen)
            endblue=$( complement $startblue)

        # End color is randomly chosen:
        else
            endred=$(  randomgrade)
            endgreen=$(randomgrade)
            endblue=$( randomgrade)
        fi

        elapsed=0
        while (( elapsed < 2*period )); do
            (( red   = startred   + elapsed * (endred   - startred)   / (2*period) ))
            (( green = startgreen + elapsed * (endgreen - startgreen) / (2*period) ))
            (( blue  = startblue  + elapsed * (endblue  - startblue)  / (2*period) ))
            backdrop
            (( elapsed += 1 ))
            sleep 0.5
        done

       # Next shifting start color is complementary to previous end color:
        if (( complementarynext )); then
            startred=$(  complement $endred)
            startgreen=$(complement $endgreen)
            startblue=$( complement $endblue)

        # Next shifting start color is identical to previous end color:
        elif (( identicalnext )); then
            startred=$endred
            startgreen=$endgreen
            startblue=$endblue

        # Next shifting start color is randomly chosen (= default gradual behaviour):
        else
            startred=$(  randomgrade)
            startgreen=$(randomgrade)
            startblue=$( randomgrade)
        fi

   # Static color switching to complementary color after every $period:
    elif (( complementarynext )); then
        red=$(  complement $red)
        green=$(complement $green)
        blue=$( complement $blue)
        backdrop
        sleep $period

    # Static color remaining identical:
    elif (( identicalnext )); then
        continue

    # Static color switching to random color after every $period (= default static behaviour):
    else
        red=$(  randomgrade)
        green=$(randomgrade)
        blue=$( randomgrade)
        backdrop
        sleep $period
    fi

done
