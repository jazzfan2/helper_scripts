# Project’s Title: Helper scripts for EMWM and XFile
A couple of helper scripts that I made to use in combination with the 'Enhanced Motif Window Manager' (EMWM) including its file manager 'XFile',
developed and maintained by Alexander Pampuchin.

# Description:
'Enhanced Motif Window Manager' (EMWM) is a great project by Alexander Pampuchin (https://fastestcode.org/), under LGPLv3 and MIT Licenses, providing a functional,
highly configurable and 'classic' looking graphical environment for UNIX-like systems, somewhat reminiscent of the Common Desktop Environment (CDE).
Among other useful applications being part of EWMWM is a file-manager called 'XFile'.

I like using it, and in an aim to contribute to its experience I developped a few small auxilliary shell scripts to customize and extend its behaviour,
even trying to further advance its ease of use. As of now, the following tools are available (more to come!):

## changedir.sh

'changedir.sh' changes to the specified directory, seemingly in the same active file-manager window, but actually by launching a new 
file-manager window of similar position and size as before changing directory, replacing the previous window.

Meant to be launched as a menu-item from XFile's tools-menu, one for each to-be-specified directory which is taken as the argument.
The program finds the active file manager window by its process- and window-ID, and keeps track of whether or not the window was a
result of splitting by the program 'splitpanes.sh', enabling re-uniting with related (split) windows.
It does so by consulting and editing the latter programs's so-called 'relations-file' if present.

## mount_plugdrives.sh

'mount_plugdrives.sh' mounts all external USB-drives, eMMC's and SD-Cards that are physically added to the system.
Meant to be launched as a menu-item from XFile's tools-menu. If a password is required for mounting a particular volume,
'mount_plugdrives.sh' offers an xterm window popup prompting for it.

## mount_volumes.sh

'mount_volumes.sh' mounts or unmounts one or more volumes selected in the file manager.
Mounting point(s) selected in the file manager by mouse button 1 ('primary X-selection') is/are taken by the program as argument(s).
Meant to be launched as a menu-item from XFile's tools-menu, or as a mount/unmount command from its context menu.
As with 'mount_plugdrives.sh', an xterm window popup prompts for a password if this is required.

## newname.sh

'newname.sh' is a rename-function, meant to be launched as a menu-item from XFile's tools-menu. A file selected in the file manager by mouse
button 1 ('primary X-selection') is taken by the program as an argument.
Unlike XFile's own rename-function (in the context menu), 'newname.sh' allows using mouse button 2 for entering a new name obtained by
doing a *new* primary X-selection by mouse button 1.

## selfmounter.sh

'selfmounter.sh' automatically mounts any external USB-drive, eMMC and SD-Card once physically added to the system.
As with 'mount_plugdrives.sh' and 'mount_volumes.sh', an xterm window popup prompts for a password if required.
Meant to act as a background daemon called from '$HOME/.sessionetc' (i.e. the 'startup applications' file read by EMWM's session manager).

'selfmounter.sh' is an alternative for using a 'udev'-rule for automounting.

## splitpanes.sh

'splitpanes.sh' does a 'splitting' of the active file-manager window into two side-by-side windows showing same directory, sharing same total
area and position as a pair as before splitting. Repeated splitting is supported. It mimics the 'split pane'-functionality found in some other
file managers e.g. PCManFM, by actually generating two new windows replacing their parent window.

The program takes the (current) directory (within the active file manager window) as an argument.

The program finds the active file manager window by its process- and window-ID, and keeps track of all windows that originated from it subsequent splitting,
even if replaced by use of the program 'changedir.sh'. It does so by maintaining a so-called 'relations-file' in RAM, by which it supervises all active
sequences of window splitting.

Option -u 're-unites' all (recursively) split windows, in the current directory of the active window, in size and position of the original
parent window, i.e. the first one from which the splitting sequence started, and not a result of splitting itself.

'splitpanes.sh' is meant to be launched as an item from XFile's tools-menu. In this menu, function keys could be assigned to 'splitting' and 're-uniting',
enabling easy toggling, e.g. F8 and F9 respectively.

## symlink.sh

'symlink.sh' stores an absolute symbolic link to the file selected in the file manager into a RAM directory. It presents this in a file
manager window popping up, from which the link can be moved or copied to a desired directory opened in another file manager window.
The symbolic link adopts the name of the file pointed to.

'symlink.sh' is meant to be launched from XFile's tools-menu, and takes two arguments:
1. the full path to the directory where the selected file resides
2. the name of selected file

## updatenotify.sh

'updatenotify.sh' launches a notifying popup in case Ubuntu software updates are available. Meant to act as a background daemon,
called from the $HOME/.sessionetc file (i.e. the 'startup applications' file read by EMWM's session manager).

# Credits:
Thanks to Alexander Pampuchin (https://fastestcode.org/) for his wonderful project 'Enhanced Motif Window Manager' (EMWM) among which the 'XFile' file manager and many more applications.

# Author
Written by Rob Toscani (rob_toscani@yahoo.com). If you find any bugs or want to comment otherwise, please let me know.
