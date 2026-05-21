#!/usr/bin/env python3
# Name: wsbackdrop.py
# Author: Rob Toscani
# Date: 20th of May 2026
# Description: Set backdrop image and optional color(s) for current EMWM workspace.
#
# Wrapper script around the 'tellmwm()' program by Alexander Pampuchin
# (workspace control utility for the 'Enhanced Motif Window Manager (EMWM)'
# https://fastestcode.org/ - LGPLv3, MIT License).
# EMWM version must be at least v2.0 to use this program.
#
# Python3-version of wsbackdrop.sh.
#
# Call this function as follows (example):
# - From Shell-CLI or -script:
#          wsbackdrop.py -d <image> <background_color>
#
# - From Python3-CLI or -script:
#          import sys; sys.path.insert(0, "<path_to_program>");
#          import wsbackdrop
#          wsbackdrop.main(['', '-d', '<image>', '<background_color>'])
#
#############################################################################
#
# Copyright (C) 2026 Rob Toscani <rob_toscani@yahoo.com>
#
# wsbackdrop.py is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# wsbackdrop.py is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
############################################################################
#

import sys
import os
import getopt
import re
from os.path import isdir
from random import random


def name2rgb(name):
# Convert X11-color-name to "rgb:redhex/greenhex/bluehex" string:

    name = name.replace(" ", "")
    rgb = os.popen                                               \
          ('(showrgb; echo "0 128 128 teal") | awk \'NF == 4\' | \
            grep -m1 -iE "( |	)' + name + '$"')                \
          .readline().strip('\n')

    if rgb == "":
        print("Cannot allocate named color " + name, file=sys.stderr)
        return
    else:
        rgb = str(rgb).split()
        red   = format(int(rgb[0]), '02x')
        green = format(int(rgb[1]), '02x')
        blue  = format(int(rgb[2]), '02x')
        return "rgb:" + red + "/" + green + "/" + blue


def get_brightness(red, green, blue):
    return 100 * (0.299 * red + 0.587 * green + 0.114 * blue) / 255


def get_bottomshadow(rgb, DarkThreshold, LightThreshold):
# Calculate RGB of darker 'bottomshadow' gradation of given background RGB:

    rgb = re.split(':|/', rgb)
    red   = int(rgb[1], 16)
    green = int(rgb[2], 16)
    blue  = int(rgb[3], 16)

    brightness = get_brightness(red, green, blue)

    # Calculate foreground and selectColor RGB-values from background RGB- and brightness-values:
    factor_fg     = 1
    offset_red_fg = offset_green_fg = offset_blue_fg  = 0

    if brightness < DarkThreshold:
        offset_red_fg   = 0.2 * (255 - red)
        offset_green_fg = 0.2 * (255 - green)
        offset_blue_fg  = 0.2 * (255 - blue)
    elif brightness > LightThreshold:
        factor_fg = 0.5
    else:
        factor_fg = 0.6

    red_fg   = format(int(red   * factor_fg + offset_red_fg),   '02x')
    green_fg = format(int(green * factor_fg + offset_green_fg), '02x')
    blue_fg  = format(int(blue  * factor_fg + offset_blue_fg),  '02x')

    return "rgb:" + red_fg + "/" + green_fg + "/" + blue_fg


def get_complementary(rgb):
# Return RGB-combination complementary to given RGB-combination:

    rgb = re.split(':|/', rgb)
    red   = format(255 - int(rgb[1], 16), '02x')
    green = format(255 - int(rgb[2], 16), '02x')
    blue  = format(255 - int(rgb[3], 16), '02x')
    return "rgb:" + red + "/" + green + "/" + blue


def tellrgb(symbolicname, workspace):
# Report current RGB of argument-string "Background" or "Foreground":

    nr = str(int(workspace[2:]) + 1)
    color = os.popen                                                                   \
           ('tellmwm | grep "' + symbolicname + '" | head -n ' + nr + ' | tail -n -1') \
           .readline().strip('\n')

    color = color.split(' ')[-1]    # Get last word on line
    return "rgb:" + color[1:3] + "/" + color[3:5] + "/" + color[5:7]


def combinecolor(rgb):
# Convert color from 'rgb:redhex/greenhex/bluehex' to 'combined decimal' notation:

    rgb = re.split(':|/', rgb)
    red   = int(rgb[1], 16)
    green = int(rgb[2], 16)
    blue  = int(rgb[3], 16)
    return 256**2 * red + 256 * green + blue


def testwhite(bg, fg):
# Test if background/foreground combination causes a white backdrop (Motif-bug!) with XBM-files:
    bg = combinecolor(bg)
    fg = combinecolor(fg)
    mod = 31
    remainder = bg % mod
    badfg = 65805 + (remainder >= 13) * mod - remainder
    if ((fg - badfg) % mod == 0):
        return True     # Remainder = 0 gives white result
    else:
        return False


def shiftcolor(rgb):
# Slightly change 'rgb:redhex/greenhex/bluehex'-color by incrementing blue component:

    rgb = re.split(':|/', rgb)
    red   = rgb[1]
    green = rgb[2]
    blue  = format(int(rgb[3], 16) + 1, '02x')     # Hier ontbreekt nog: 1 aftrekken als blauw al FF is!!
    return "rgb:" + red + "/" + green + "/" + blue


def convert_xpm(image, bgcolor, fgcolor):
# Re-activate the color-gradations between/beyond foregound- & background-colors in the XPM-file, by:
# 1. Calculating 'selectColor' & 'topShadowColor' RGB values from background- and foregound-colors,
# 2. Updating the 'c'-field accordingly in the color-strings containing above two symbolic color names,
# 3. Renaming the 's'-field called 'bottomShadowColor' to 'foreground':

    bgcolor= re.split(':|/', bgcolor)
    fgcolor= re.split(':|/', fgcolor)

    red_bg   = int(bgcolor[1], 16)
    green_bg = int(bgcolor[2], 16)
    blue_bg  = int(bgcolor[3], 16)

    red_fg   = int(fgcolor[1], 16)
    green_fg = int(fgcolor[2], 16)
    blue_fg  = int(fgcolor[3], 16)

    # Calculate selectColor RGB-values by interpolating background- and foreground-color RGBs:
    red_sl   = format(int((red_bg   + red_fg)  / 2), '02x')
    green_sl = format(int((green_bg + green_fg)/ 2), '02x')
    blue_sl  = format(int((blue_bg  + blue_fg) / 2), '02x')
    slcolor  = "#" + red_sl + green_sl + blue_sl

    # Calculate topShadowColor RGB-values from background-color RGB:
    if get_brightness(red_bg, green_bg, blue_bg) > get_brightness(red_fg, green_fg, blue_fg):
        factor = 1.4    # default value
    else:
        factor = 0.7    # "inverted" value (proposed)

    red_ts   = format(min(255, int(factor * red_bg)),   '02x')
    green_ts = format(min(255, int(factor * green_bg)), '02x')
    blue_ts  = format(min(255, int(factor * blue_bg)),  '02x')
    tscolor  = "#" + red_ts + green_ts + blue_ts

    c_field  = re.compile('( |	)+c( |	)+[^ \",	]+')
    line_end = re.compile('\",$')
    with open(image, 'r') as f:
        for line in f.read().splitlines():
            if "selectColor" in line:
                # Remove existing "c"-field:
                line = re.sub(c_field, "", line)
                # Add new "c"-field with given (sl)color:
                line = re.sub(line_end, " c " + slcolor + "\",", line)
            elif "topShadowColor" in line:
                line = re.sub(c_field, "", line)
                line = re.sub(line_end, " c " + tscolor + "\",", line)
            else:
                line = line.replace("bottomShadowColor", "foreground")
            yield line


def main(args):
# This function is called from another Python program as 'wsbackdrop.main([<list>])', with
# [<list>] containing the quoted arguments, starting with a 'fake string' as pos. parameter 0:

    bottomshadow   = False # Default: foreground color not a darker grade of background
    complementary  = False # Default: foreground color not complementary to background
    DarkThreshold  = 15    # Motif value
    LightThreshold = 93    # Motif value

    # Determine where the modified pixmap file can be stored in RAM temporarily:
    if isdir("/tmp/ramdisk/"):
        tempdir = "/tmp/ramdisk"
    elif isdir("/dev/shm/"):
        tempdir = "/dev/shm"
    else:
        tempdir = "."         # (No RAM, serves as fall back scenario)

    # Name of RAM-subdirectory:
    subdir = "subdir_" + str(int(random()*1000000)) + str(int(random()*1000000))

    # Determine current workspace:
    workspace = os.popen                                             \
                ('tellmwm 2>&1 | tail -n 1 | awk \'{ print $NF }\'') \
                .readline().strip('\n')

    # Text printed if -h option (help) or a non-existent option has been given:
    usage = """
    Usage:
    wsbackdrop.sh [-dsh] IMAGE [BACKGROUNDCOLOR [FOREGROUNDCOLOR]]
    \t-d	Foreground color is calculated as a darker (= 'bottomshadow')
    \t  	gradation of background color if given. Overrides -s.
    \t-s	Foreground color is calculated as strong contrasting
    \t  	(= complementary) to background color if given.
    \t-h	Help (this output)

    Arguments:
    \tIMAGE            Full path to image file, or 'none' for no image.
    \tBACKGROUNDCOLOR  Hexadecimal RGB-string e.g. "rgb:1C/87/fa",
    \t                 or X11-color-name without spaces or quoted.
    \tFOREGROUNDCOLOR  Idem.
    """

    # Select option(s):
    try:
        options, non_option_args = getopt.getopt(args[1:], 'dsh')
    except:
        print(usage)
        sys.exit()

    for opt, arg in options:
        if opt in ('-h'):
            print(usage)
            sys.exit()
        elif opt in ('-d'):
            bottomshadow = True   # Foreground a darker shade of background
        elif opt in ('-s'):
            complementary = True  # Foreground complementary to background

    argcount = len(non_option_args)
    image = non_option_args[0]
#   print(image)
    if argcount >= 2:
        bg = non_option_args[1]
    if argcount == 3:
        fg = non_option_args[2]

    # In case of X11-color-names for background- and/or foreground-color, retrieve RGB-values:
    slash = re.compile('/')
    if 'bg' in locals() and not re.search(slash, bg):
        bg = name2rgb(bg)
    if 'fg' in locals() and not re.search(slash, fg):
        fg = name2rgb(fg)

    # Get foreground color (and background color) if not given for current workspace:
    if bottomshadow and argcount >= 2:
        fg = get_bottomshadow(bg, DarkThreshold, LightThreshold)
    elif complementary and argcount >= 2:
        fg = get_complementary(bg)
    elif argcount == 2:
        fg = tellrgb("Foreground", workspace)
    elif argcount == 1:
        bg = tellrgb("Background", workspace)
        fg = tellrgb("Foreground", workspace)

    #  If image is an XBM, and bg/fg-combination causes a "White Backdrop" (Motif-bug), slightly change fg:
    xbm_ext = re.compile('\\.x?bm$')
    if re.search(xbm_ext, image) and testwhite(bg, fg):
        fg = shiftcolor(fg)                              # Therefore name2rgb() needed for xbm too

    # If image is an XPM, derive a modified version with adapted 's'- and 'c'-fields in color string:
    xpm_ext = re.compile('\\.x?pm$')
    dirpath = re.compile('.*/')
    if re.search(xpm_ext, image):
        os.system('mkdir ' + tempdir + "/" + subdir)     # New subdir needed for tellmwm() to show image
        new_image = re.sub(dirpath, '', image)           # Edited XPM file w/ same name (dir. path removed)
        with open(tempdir + "/" + subdir + "/" + new_image, 'a') as f:
            for line in convert_xpm(image, bg, fg):
                print(line, file=f)                      # tellmwm ignores image if process-substitution
        image = tempdir + "/" + subdir + "/" + new_image # Full path needed

    # Set desired colors and image as backdrop for current workspace:
    os.system('tellmwm backdrop ' + workspace + ' -b ' + bg + ' -f ' + fg + ' ' + image + ' && \
               (sleep 1 && rm -rf ' + tempdir + "/" + subdir + ')&')


# Ensures main() is run only if program is called from shell,
# or as <module>.main() in Python, not yet at import:
if __name__ == "__main__":
    main(sys.argv)
