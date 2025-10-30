# Project’s Title: Helper scripts for EMWM and XFile
A couple of helper scripts that I made, customizing and facilitating the use of the 'Enhanced Motif Window Manager' (EMWM) and its file manager named 'XFile', developped and maintained by Alexander Pampuchin.

# Description:
'Enhanced Motif Window Manager' (EMWM) is a great project by Alexander Pampuchin (https://fastestcode.org/), under LGPLv3 and MIT Licenses, providing a functional, highly configurable and 'classic' looking graphical environment for unix-like systems, somewhat reminiscent of the Common Desktop Environment (CDE). Part of EMWM is the file-manager called 'XFile', among other useful applications.

I very much like to use it, and in an aim to contribute to its experience I developped a few small auxilliary shell scripts facilitating and customizing its behaviour, even trying to further advance its ease of use.
As of now, the following tools are available (more to come!):

## changedir.sh

'changedir.sh' changes to the specified directory, seemingly in the same active file-manager window, but actually by launching a new 
file-manager window of similar position and size as before changing directory, replacing the previous window.

'changedir.sh' is meant to be launched as a menu-item from XFile's tools-menu, one for each to-be-specified directory taken as an argument.
The active file-manager window is being derived by the program by finding its parent's process-ID and subsequently the related window-ID.

'changedir.sh' keeps track of whether or not the window was a result of splitting by the program 'split_panes.sh', thus allowing re-uniting with
related (split) window panes. It does so by consulting and editing the latter programs's so-called 'relations-file' if present.

## mount_plugdrives.sh

'mount_plugdrives.sh' mounts all external USB-drives, eMMC's and SD-Cards that are physically added to the system.
It is meant to be launched as a menu-item from XFile's tools-menu. If a password is required for mounting a particular volume,
'mount_volumes.sh' offers an xterm window popup prompting for it.

## mount_volumes.sh

'mount_volumes.sh' mounts or unmounts volume(s) selected in the file manager.
Mounting point(s) selected in the file manager by mouse button 1 ('primary X-selection') is/are taken by the program as argument(s).
The program is meant to be launched as a menu-item from XFile's tools-menu,or as a mount/unmount command from its context menu.
As with mount_plugdrives.sh, an xterm window popup prompts for a password if required.

Unmounting takes option -u

Reason for developing this program was to work around what I perceive as a bug, but might as well be undefined 'xterm -e' behaviour:
Suppose that a mounting point (directory name) contains a space, and an xterm is needed to prompt for the password. 
In that case the '%n' argument, corresponding with the X-selected mounting point(s), must be used inside the quoted command string
fed to 'xterm -e', like:

	xterm -e "sudo mount \"%n\""

The problem is that undesired word-splitting is not prevented in that case, even if %n is surrounded by escaped quotes inside the quoted
command string.
I couldn't find a way to overcome this, preventing me to use above construct as a 'XFile.tools'-resource, so I chose to handle it inside a script.

## newname.sh

'newname.sh' is a rename-function, meant to be launched as a menu-item from XFile's tools-menu. A file selected in the file manager by mouse
button 1 ('primary X-selection') is taken by the program as an argument.
Unlike XFile's own rename-function (in the context menu), newname.sh allows using mouse button 2 for entering a new name obtained by
doing a *new* primary X-selection by mouse button 1.

## selfmounter.sh

'selfmounter.sh' automatically mounts any external USB-drive, eMMC and SD-Card once physically added to the system. As with mount_plugdrives.sh and mount_plugdrives.sh, an xterm window popup prompts for a password if required.
'selfmounter.sh' is meant to function as a background daemon called from '$HOME/.sessionetc', which is the 'startup applications' file read by EMWM's session manager.  

'selfmounter.sh' is an alternative for using a 'udev'-rule for automounting - which I wasn't able to get working although I really tried hard, grrrr!!! :-C

## splitpanes.sh

'splitpanes.sh' does a 'splitting' of the active file-manager window into two side-by-side windows showing same directory, sharing same total
area and position as a pair as before splitting. Repeated splitting is supported. It is meant to 'mimic' the 'split pane'-functionality found
in some other file managers e.g. PCManFM, by actually generating two new windows replacing their parent window.

The program takes the (current) directory (within the active file manager window) as an argument.

The active file manager window itself is being derived by the program by finding its parent's process-ID and subsequently the related window-ID.
It keeps track of all windows that originated from the parent window by subsequent splitting, even if replaced by use of the program 
'changedir.sh'. It does so by maintaining a so-called 'relations-file' in RAM memory, which even supports multiple split windows situations sumultaneously.

Option -u 're-unites' all (recursively) split windows, in the current directory of the active window, in size and position of the original
window, out of which the full splitting sequence started and which didn't originate by splitting itself.

'splitpanes.sh' is meant to be launched as an item from XFile's tools-menu, where it could e.g. be accelerated by assigning F8 and F9 
function keys respectively for easy toggling between 'splitting' and 're-uniting'.

Prerequisites:
- xfile
- xdotool
- wmctrl

## symlink.sh

'symlink.sh' stores an absolute symbolic link to the file selected in the file manager into a RAM directory. It presents this in a file
manager window popping up, from which the link can be moved or copied to a desired directory opened in another file manager window.
The symbolic link gets the same name as the file pointed to.

'symlink.sh' is meant to be launched from XFile's tools-menu.

This program takes two arguments:
1. the full path to the directory where the selected file resides
2. the name of selected file

# Credits:
Thanks to Alexander Pampuchin (https://fastestcode.org/) for his wonderful project 'Enhanced Motif Window Manager' (EMWM) among which the XFile file manager and many more applications.

# Author
Written by Rob Toscani (rob_toscani@yahoo.com). If you find any bugs or want to comment otherwise, please let me know.
