#!/usr/bin/env python3
# Name: randombackdrop.py
# Author: R.J.Toscani
# Date: 20th of May 2026
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
# Python3-version of randombackdrop.sh. Calls 'wsbackdrop.py'.
#
#############################################################################
#
# Copyright (C) 2026 Rob Toscani <rob_toscani@yahoo.com>
#
# randombackdrop.py is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# randombackdrop.py is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
############################################################################

import time
import datetime
import sys
import threading
import os
import shutil
import getopt
import signal
import re
from os import listdir
from os.path import isfile, isdir, join
from random import random

homedir = os.path.expanduser("~")
sys.path.insert(0, homedir + "/scripts");
# (Adjust above path if 'wsbackdrop.py' resides in another directory)

import wsbackdrop

now = datetime.datetime.now()

if isdir("/tmp/ramdisk/"):
    ramdir = "/tmp/ramdisk"
elif isdir("/dev/shm/"):
    ramdir = "/dev/shm"
else:
    ramdir = "."         # (No RAM, serves as fall back scenario)

# XBM and XPM image-sources (change as desired):
# https://sourceforge.net/projects/cdesktopenv/
# http://cs.gettysburg.edu/~duncjo01/archive/patterns/cde/
# http://cs.gettysburg.edu/~duncjo01/archive/patterns/OEM/Sun/texture/
imagedir1 = "/usr/dt/share/backdrops"
imagedir2 = homedir + "/Documenten/Ubuntu-Linux/EMWM/wallpapers/cde"
imagedir3 = homedir + "/Documenten/Ubuntu-Linux/EMWM/wallpapers/sun"


#=============================== FUNCTIONS ================================#


def kill_earlier(name):
# Stop any other "randombackdrop"-process already running:
# https://www.geeksforgeeks.org/python/kill-a-process-by-name-using-python/
    ownpid = os.getpid()
    try:
        # iterating through each instance of the process
        for line in os.popen("ps ax | grep \"" + name + "\" | grep -v grep"):
            fields = line.split()

            # extracting Process ID from the output
            pid = fields[0]

            if int(pid) != int(ownpid):
                # terminating process
                os.kill(int(pid), signal.SIGKILL)
    except:
        True


def signal_handler(sig, frame):
# Stop the program in case of an interrupt (Ctrl-C) or terminate signal:
# https://stackoverflow.com/questions/1112343/how-do-i-capture-sigint-in-python
# https://forums.whonix.org/t/all-python-scripts-need-sigterm-and-sigint-traps/19280
    if isdir(tmpfiledir):
        shutil.rmtree(tmpfiledir)
    print('Program terminated', file=sys.stderr)
    if sig == 15:    # SIGTERM
        sys.exit(143)
    elif sig == 2:   # SIGINT
        sys.exit(130)


def cycle(imagelist):
# Periodically set image, background color and independent foreground color, and call backdrop():
    # Generate two independent random RGB-combinations:
    color1 = start1 = random_rgb()     # Background color
    color2 = start2 = random_rgb()     # Foreground color (independent from backgrond color)
    while True:
        if image:
            maxindex = len(imagelist)
            # Generate a random array index-number:
            index = max(1, int(random() * maxindex))
        else:
            index = 0       # No image (in case of the -n option)
        # Start colors gradually shifting into another pair of (end) colors during every $period, etc:
        if gradual:
            # End colors are complementary to start colors:
            if crossover:
                end1 = complement(start1)
                end2 = complement(start2)
            # End colors are randomly chosen:
            else:
                end1 = random_rgb()
                end2 = random_rgb()
            for step1, step2 in gradualshift(start1, end1, start2, end2):
                backdrop_thread = threading.Thread(target=backdrop, args=[step1, step2, index])
                backdrop_thread.start()     # backdrop() runs in parallel to cycle()
                time.sleep(0.5)
            # Next shifting start colors are complementary to previous end colors:
            if complementarynext:
                start1 = complement(end1)
                start2 = complement(end2)
            # Next shifting start colors are identical to previous end colors:
            elif identicalnext:
                start1 = end1
                start2 = end2
            # Next shifting start colors are randomly chosen (= default gradual behaviour):
            else:
                start1 = random_rgb()
                start2 = random_rgb()
        # Static colors switching to complementary colors after every $period:
        elif complementarynext:
            color1 = complement(color1)
            color2 = complement(color2)
            backdrop_thread = threading.Thread(target=backdrop, args=[color1, color2, index])
            backdrop_thread.start()
            time.sleep(period)
        # Static colors remaining identical:
        elif identicalnext:
            continue
        # Static colors switching to random colors after every $period (= default static behaviour):
        else:
            color1 = random_rgb()
            color2 = random_rgb()
            backdrop_thread = threading.Thread(target=backdrop, args=[color1, color2, index])
            backdrop_thread.start()
            time.sleep(period)


def random_rgb():
# Return random RGB-combination:
    red   = int(random() * 255)
    green = int(random() * 255)
    blue  = int(random() * 255)
    return (red, green, blue)


def complement(rgb):
# Return RGB-combination complementary to given RGB-combination:
    red   = 255 - rgb[0]
    green = 255 - rgb[1]
    blue  = 255 - rgb[2]
    return (red, green, blue)


def gradualshift(startcolor1, endcolor1, startcolor2, endcolor2):
# Gradually shift from start-color1 to end-color1, and from start-color2 to end-color2:
    startred1   = startcolor1[0];   redrange1   = endcolor1[0] - startred1
    startgreen1 = startcolor1[1];   greenrange1 = endcolor1[1] - startgreen1
    startblue1  = startcolor1[2];   bluerange1  = endcolor1[2] - startblue1

    startred2   = startcolor2[0];   redrange2   = endcolor2[0] - startred2
    startgreen2 = startcolor2[1];   greenrange2 = endcolor2[1] - startgreen2
    startblue2  = startcolor2[2];   bluerange2  = endcolor2[2] - startblue2

    elapsed = 0
    while elapsed < 2*period:
        red1   = startred1   + elapsed * redrange1   // (2 * period)
        green1 = startgreen1 + elapsed * greenrange1 // (2 * period)
        blue1  = startblue1  + elapsed * bluerange1  // (2 * period)

        red2   = startred2   + elapsed * redrange2   // (2 * period)
        green2 = startgreen2 + elapsed * greenrange2 // (2 * period)
        blue2  = startblue2  + elapsed * bluerange2  // (2 * period)

        yield (red1, green1, blue1), (red2, green2, blue2)
        elapsed += 1


def dec2hex(rgb):
# Convert color from decimal (red,green,blue) tuple to hexadecimal 'rgb:redx/greenx/bluex' string:
    red   = format(rgb[0], '02x')
    green = format(rgb[1], '02x')
    blue  = format(rgb[2], '02x')
    return ("rgb:" + red + "/" + green + "/" + blue)


def backdrop(color1, color2, index):
# Set color(s) and optionally the image of the backdrop for the current workspace:
    color1 = dec2hex(color1)   # Background color
    color2 = dec2hex(color2)   # Foreground color (independent from backgrond color)

    if image and randomforeground:   # foreground color independent from backgropund
        wsbackdrop.main(['', tmpfiledir + "/" + imagelist[index], color1, color2])
    elif image and strongcontrast:   # foreground color complementary to background
        wsbackdrop.main(['', '-s', tmpfiledir + "/" + imagelist[index], color1])
    elif image:                      # foreground color a darker shade of background
        wsbackdrop.main(['', '-d', tmpfiledir + "/" + imagelist[index], color1])
    elif not image:                  # image and foreground color omitted
        wsbackdrop.main(['', 'none', color1])

    # For debug purposes (uncomment for output to logfile):
    with open('/home/rob/backdroplog.txt', 'a') as f:
        print(now.strftime("%Y-%m-%d %H:%M:%S"), str(color1), tmpfiledir + "/" + imagelist[index], file=f)


#======================== MAIN FUNCTION STARTS HERE ========================#


# Stop any other "randombackdrop"-process already running:
kill_earlier("scripts/randombackdrop.py")

# Defaults:
fixed = False              # No single fixed image
period = 60                # Period = 60 seconds
image = True               # Include CDE backdrop images
complementarynext = False  # Next color not complementary to previous color
gradual = False            # No gradual shift from start-color to end-color
crossover = False          # End-color not complementary to start-color
identicalnext = False      # Next color not identical to previous (end-)color
strongcontrast = False     # No strong color-contrast by complementary foreground-color
randomforeground = False   # No independent foreground-color
xpm_only = False           # Accept both XPM- and XBM-files

# Text printed if -h option (help) or a non-existent option has been given:
usage = """
Usage:
randombackdrop.sh [-icfgGhnpPrs] [-p PERIOD]
\t-i	Next (start-)color pair is identical to previous (end-)color pair.
\t-c	Next (start-)color pair complementary to previous (end-)color pair. Overrides -i.
\t-f IMAGEPATH
\t      Fixed image, with full IMAGEPATH to file. Overrides -P.
\t-g	Gradual shift from start-color pair to random end-color pair.
\t-G	Gradual shift from start-color pair to complementary end-color pair. Overrides -g
\t-h	Help (this output)
\t-n	Only backdrop colors, no images. Overrides -f, -s and -r.
\t-p PERIOD
\t      Specify cycling PERIOD in seconds (default = 60).
\t-P	Accept XPM-files only, omit XBM-files.
\t-r	Random foreground color, unrelated to background color. Overrides -s.
\t-s	Strong contrasting foreground-color, complementary to background color.
"""

# Select option(s):
try:
    options, non_option_args = getopt.getopt(sys.argv[1:], 'cf:gGhnp:Prsi')
except:
    print(usage)
    sys.exit()

for opt, arg in options:
    if opt in ('-h'):
        print(usage)
        sys.exit()
    elif opt in ('-c'):
        complementarynext = True  # Next color complementary to previous (end) color.
    elif opt in ('-f'):
        fixed = True              # Fixed image
        image_path = arg
    elif opt in ('-g'):
        gradual = True            # Gradual shift to random end-color
    elif opt in ('-G'):
        crossover = True          # Gradual shift to complementary end-color.
        gradual = True
    elif opt in ('-n'):
        image = False             # No CDE backdrop images
    elif opt in ('-p'):
        period = arg              # Specify period
    elif opt in ('-P'):
        xpm_only = True           # Accept XPM-files only, omit XBM-files
    elif opt in ('-r'):
        randomforeground = True   # Random foreground color, independent from background
    elif opt in ('-s'):
        strongcontrast = True     # Strong color-contrast by complementary foreground
    elif opt in ('-i'):
        identicalnext = True      # Next color identical to previous (end-)color

# Minimize period to 1 second:
regex = re.compile('^0|[^0-9]')
if re.search(regex, period) or int(period) < 1:
    period = 1
    print("Input is not integer. Period changed to 1s.", file=sys.stderr)
else:
    period = int(period)

# Create subdirectory in RAM where the bitmaps and pixmaps will be stored temporarily:
tmpfiledir = ramdir + "/backdrops" + str(int(random()*1000000))

# Stop the program in case of an interrupt (Ctrl-C) or terminate signal:
signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

# Copy the CDE backdrop-images (pixmap and bitmap) to the temporary directory
# (except in if -n option is given):
imagelist = [""]
if image:
    os.mkdir(tmpfiledir)
    if fixed:
        if isfile(image_path):
            shutil.copy(image_path, tmpfiledir, follow_symlinks=True)
        else:
            print("No such file", file=sys.stderr)
            sys.exit(1)
    else:
        if xpm_only:
            globbing = '/{*.pm,*.xpm}'
        else:
            globbing = '/{*.pm,*.xpm,*.bm,*.xbm}'
        for path in [imagedir1, imagedir2, imagedir3]:
            os.system('bash -c \"cp ' + path + globbing + ' ' + tmpfiledir + ' 2>/dev/null\"')

        # Remove some non-desired backdrops from the temporary directory
        # (either because of lack of figuration, insufficient height or negative
        # representation w/ most colors):

        omissionslist = [
        "Background.*",
        "Foreground.*",
        "black.*",
        "white.*",
        "Gray*",
        "grey.*",
        "inversegrey.*",
        "NoBackdrop.*",
        "Pattern50.*",
        "Ridged.*",
        "SkyDark.*pm",
        "SkyLight.*pm",
        "Toronto.*bm",
        "BrickWall.*bm"]

        for omissions in omissionslist:
            os.system('rm ' + tmpfiledir + "/" + omissions + ' 2>/dev/null')

    # Store all image names within the temporary directory into a global array:
    imagelist += [f for f in listdir(tmpfiledir) if isfile(join(tmpfiledir, f))]

# Periodically set color(s) and/or image as current workspace backdrop:
time.sleep(0.4)   # To prevent overriding by global setting at start of EMWM session
cycle(imagelist)
