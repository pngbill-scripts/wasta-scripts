#!/bin/bash
# Author: Bill Martin <bill_martin@sil.org>
# Date: 4 November 2014
# Revision: 
#   - 7 November 2014 Modified for Trusty mount points having embedded $USER 
#      in $MOUNTPOINT path as: /media/$USER/LM-UPDATES whereas Precise has: 
#      /media/LM-UPDATES
#   - 17 April 2016 Revised to use a default source master mirror location of
#      /data/master/. If a master mirror still exists at the old /data location
#      the script now offers to quickly move (mv) the master mirror from its
#      /data location to the more recommended /data/master location.
#     Added a script version number "0.1" to the script to make future updates
#      easier.
# Name: sync_Wasta-Offline_to_Ext_Drive.sh
# Distribution: 
# This script is included with all Wasta-Offline Mirrors supplied by Bill Martin.
# If you make changes to this script to improve it or correct errors, please send
# your updated script to Bill Martin bill_martin@sil.org
#
# Purpose: 
# The primary purpose of this script is to synchronize an out-of-date Wasta-Offline 
# mirror from a more up-to-date Wasta-Offline mirror. The script is flexible enough
# to do this synchronization between any two Wasta-Offline mirrors located at
# different paths. The more up-to-date mirror should be referred to as the "source" 
# mirror and the out-of-date mirror should be referred to as the "destination" mirror. 
# Normally, the more up-to-date mirror (the source) will be a master Wasta-Offline 
# mirror that gets regularly updated via calls to the apt-mirror program (using our 
# update-mirror.sh script), and this master mirror will be located at a path which 
# this script defaults to the local computer's /data/master/wasta-offline/ folder. 
# The out-of-date mirror (the destination) will be on an external Wasta-Offline USB  
# drive (supplied by Bill Martin) which defaults to: /media/LM-UPDATES/wasta-offline 
# on a Precise based system or to: /media/$USER/wasta-offline on a Trusty based   
# system. These source and destination paths can be altered by passing different   
# paths to this script via its $1 and $2 parameters.
# Both the source path and destination paths should be on file systems formatted 
# as Linux file systems (Ext3 or Ext4) since the rsync utility used to synchronize
# and or doing the copying, is called in such a way as to preserve the source and
# destination mirrors' ownership, group and permissions. If an external USB drive
# is to be used as the destination, and is currently formatted as a FAT or FAT32
# (or any other non-Linux Ext file system) and has a capacity of at least 500GB, 
# the script will optionally offer to format the USB drive with an Ext4 file system.
# This script may also be used to copy or sync the full mirror from any one location 
# to another. Here are some example uses:
#   * Synchronize an external USB drive to bring it up-to-date (default use)
#   * Create a backup copy of the master apt-mirror tree to a safe location
#   * Restore a broken or lost master mirror from a backup copy
#   * Create a new master mirror on a computer from an external USB drive's copy (a
#     better option would be to use the make_Master_for_Wasta-Offline.sh script for 
#     this purpose)
#
# This sync_Wasta-Offline_to_Ext_Drive.sh script does the following:
#   1. Runs the script as root (asks for password).
#   2. Includes some of the functions defined in the bash_functions.sh file which is
#      located in the same directory as this script.
#   3. Checks any parameters that were passed to the script and acts accordingly.
#      If two parameters are present, first param is $COPYFROMDIR, second is $COPYTODIR
#      Note: The $COPYFROMDIR and $COPYTODIR paths must be absolute paths to the 
#      source wasta-offline directories that contain the apt-mirror generated mirrors 
#      (i.e., both source and destination paths should point to the "wasta-offline" 
#      directories of their respective mirror trees). See the "Usage" section below 
#      for other possible invocation parameters.
#      If a thrid parameter is present [currently unimplemented] it must be 
#      "PREP_NEW_USB". It will be ignored unless a USB drive is present and meets all 
#      of the following conditions:
#        a. The attached USB drive is not already labeled "LM-UPDATES"
#        b. The attached USB drive does not already have a Linux file system
#        c. The attached USB drive is not busy and can be unmounted
#      The "PREP_NEW_USB" causes this sync_Wasta-Offline_to_Ext_Drive.sh script to
#      offer to format a USB drive that meets the above conditions, and is 
#      user-selected from a list of those USB drives currently mounted). Formatting 
#      a user-selected USB drive will, of course, only be attemptd after the customary 
#      warnings and user confirmation.
#   4. Ensures there is a valid mount point for the external USB LM-UPDATES drive.
#      Mounts LM-UPDATES if it is plugged in but not mounted. Optionally formats 
#      (after warning and prompting the user for permission) a new USB drive with
#      Ext4 file system if required.
#   5. Determines a base directory for the destination and source mirror trees.
#   6. Checks to ensure that the source mirror path with an apt-mirror tree exists, 
#      if not aborts.
#   7. Checks if a mirror exists at the destination, and if so whether the mirror is 
#      older than the source mirror, and handles 7 possible check result scenarios.
#   8. Ensures that there is a destination mirror structure (up to the apt-mirror
#      directory level) if it doesn't already exist.
#   9. Sets the source mirror's owner:group properties to apt-mirror:apt-mirror, 
#      and sets the source mirror's content permissions to ugo+rw (read-write for
#      everyone).
#  10. Synchronizes/Copies all of the source mirror's "root" directory files to the
#      destination's "root" directory. The "root" directory here refers to the 
#      directory of the device or drive where the mirror begins. For example, the
#      "root" directory of Bill's master copy is on a partition mounted at /data,
#      and the "root" directory of an attached USB Wasta-Offline Mirror - as 
#      supplied by Bill Martin - is at /media/LM-UPDATES or /media/$USER/LM-UPDATES. 
#      Those files include:
#        a. bash_functions.sh
#        b. make_Master_for_Wasta-Offline.sh
#        c. ReadMe
#        d. sync_Wasta-Offline_to_Ext_Drive.sh
#        e. update-mirror.sh
#        f. wasta-offline*.deb packages
#        g. postmirror.sh (in apt-mirror-setup and wasta-offline/apt-mirror/var subdirectories)
#        h. postmirror2.sh (in apt-mirror-setup and wasta-offline/apt-mirror/var subdirectories)
#  11. Sets the destination mirror's ownergroup properties to apt-mirror:apt-mirror
#      and sets the destination mirror's content permissions to ugo+rw (read-write 
#      for everyone).
#  12. Ensures the source mirror directory path to be used with rsync ends with slash, 
#      and the destination directory path to be used with rsync does not end with slash.
#  13. Makes the main rsync call to synchronize the mirror tree from the source tree 
#      (normally the master copy's /data/master/wasta-offline/ directory) to the destination 
#      tree (normally the external USB drive's mirror at /media/$USER/LM-UPDATES/wasta-offline). 
#      This copy will usually go relatively fast if the full mirror existed already on 
#      the external USB drive and you are only synchronizing the latest software updates. 
#      If the external USB drive was an empty drive the copy process to copy all 285+GB 
#      of mirror data from the local computer to the USB external drive will probably 
#      take about 4.5 hours for either a USB 2.0 or USB 3.0 connection.
#  14. Reminds the user to label any new USB drive that was formatted.
#
# Usage:
# 1. Before updating/synchronizing an attached external drive with this script, the user
#    should have previously updated the mirror at the "source" location - usually 
#    /data/master/wasta-offline/ - by doing one of the following:
#      a. Running the update-mirror.sh script (from File Manager or at a command line),
#         which will automatically run this synchronization script after updating the
#         source mirror, or
#      b. Running the command: sudo apt-mirror (at a command line).
# 2. bash sync_Wasta-Offline_to_Ext_Drive.sh [<source-mirror>] [destination-mirror] ["PREP_NEW_USB"]
#    All parameters are optional. 
#    If no parameters are given, "/data/master/wasta-offline/" is assumed to be the path to 
#       the up-to-date source mirror, and "/media/$USER/LM-UPDATES/wasta-offine" is assumed 
#       to be the path to the destination mirror that needs updating.
#    If only one parameter is given, it is the user-specified path to the external USB 
#       drive's 'destination' mirror's wasta-offline directory, and /data/master/wasta-offline/ 
#       is assumed to be the source (master) mirror.
#    If two parameters are given, the 1st is the path to the local computer's updated
#       wasta-offline 'source' mirror's wasta-offline directory, and 2nd is the path to 
#       the external USB drive's 'destination' mirror's wasta-offline directory that 
#       needs to be updated/synchronized.
#       Note: If one wants to establish a new master copy of the full mirror to which
#       updates are then maintained the make_Master_for_Wasta-Offline.sh script should
#       be employed for that purpose. It is possible to make a master copy of the full
#       mirror (or a backup) by calling this script manually with the appropriate 
#       source and destination path parameters, but this is not recommended. Instead
#       use the make_Master_for_Wasta-Offline.sh script which was designed for that
#       purpose. Having a master copy of the full mirror might be desirable if someone 
#       wants to establish a local master copy of the full mirror to which updates are 
#       then maintained (utilizing the supplied update-mirror.sh script) from a 
#       zero-cost FTP network server, or even from an affordable (unlimited data) 
#       Internet connection. Copying 400-500GB from an existing mirror to a new location 
#       through a USB cable to a local computer is much faster than attempting to 
#       download the same amount of data through a DSL or wireless connection.
#    If a thrid parameter is present [currently unimplemented] it must be "PREP_NEW_USB". 
#      It will be ignored unless a USB drive is present and meets all of the following 
#      conditions:
#        a. The attached USB drive is not already labeled "LM-UPDATES"
#        b. The attached USB drive does not already have a Linux file system
#        c. The attached USB drive is not busy and can be unmounted
#      The "PREP_NEW_USB" parameter is in turn passed to the 
#      sync_Wasta-Offline_to_Ext_Drive.sh script which makes the offer to format 
#      the USB drive that meets the above conditions, and is user-selected from a 
#      list of those USB drives currently mounted). Formatting a user-selected USB 
#      drive will, of course, only be attemptd after the customary warnings and user 
#      confirmation.

# Note when set -e is uncommented, script stops immediately and no error codes are returned in "$?"
#set -e

WASTAOFFLINEPKGURL="http://ppa.launchpad.net/wasta-linux/wasta-apps/ubuntu/pool/main/w/wasta-offline"
DATADIR="/data"
MASTERDIR="/master"
export APTMIRROR="apt-mirror"
export OFFLINEDIR="/wasta-offline"
export APTMIRRORDIR="/apt-mirror"
export APTMIRRORSETUPDIR="/apt-mirror-setup"
export MIRRORDIR="/mirror"
export UPDATEMIRRORSCRIPT="update-mirror.sh"
export SYNCWASTAOFFLINESCRIPT="sync_Wasta-Offline_to_Ext_Drive.sh"
export POSTMIRRORSCRIPT="postmirror.sh"
export POSTMIRROR2SCRIPT="postmirror2.sh"
COPYFROMDIR=$DATADIR$MASTERDIR$OFFLINEDIR"/"  # /data/master/wasta-offline/ is now the default source dir
MOUNTPOINT=`mount | grep LM-UPDATES | cut -d ' ' -f3` # normally MOUNTPOINT is /media/LM-UPDATES or /media/$USER/LM-UPDATES
if [ "x$MOUNTPOINT" = "x" ]; then
  # $MOUNTPOINT for an LM-UPDATES USB drive was not found
  export LMUPDATESDIR=""
  LMUPDATESVARDIR=""
  COPYTODIR=""
else
  export LMUPDATESDIR=$MOUNTPOINT # normally MOUNTPOINT is /media/LM-UPDATES or /media/$USER/LM-UPDATES
  LMUPDATESVARDIR=$LMUPDATESDIR$OFFLINEDIR$APTMIRRORDIR"/var" # /media/LM-UPDATES/wasta-offline/apt-mirror/var
  COPYTODIR=$LMUPDATESDIR$OFFLINEDIR  # /media/LM-UPDATES/wasta-offline
fi
DATADIRVARDIR=$DATADIR$MASTERDIR$OFFLINEDIR$APTMIRRORDIR"/var" # /data/master/wasta-offline/apt-mirror/var
CLEANSCRIPT=$COPYFROMDIR"apt-mirror/var/clean.sh" # /data/master/wasta-offline/apt-mirror/var/clean.sh
WAIT=60
DRIVEWASFORMATTED="FALSE"
export LastAppMirrorUpdate="last-apt-mirror-update"

# ------------------------------------------------------------------------------
# Setup script to run with superuser permissions
# ------------------------------------------------------------------------------
if [ "$(whoami)" != "root" ]; then
    echo
    echo "This script needs to run with superuser permissions."
    echo "----------------------------------------------------"
    # below will return <blank> if user not in sudo group
    OUT=$(groups $(whoami) | grep "sudo")

    if [ "$OUT" ]; then
        # user has sudo permissions: use them to re-run the script
        echo
        echo "If prompted, enter the sudo password."
        #re-run script with sudo
        sudo bash $0 $@
        LASTERRORLEVEL=$?
    else
        #user doesn't have sudo: limited user, so prompt for sudo user
        until [ "$OUT" ]; do
            echo
            echo "Current user doesn't have sudo permissions."
            echo
            read -p "Enter admin id (blank for root) to run this script:  " SUDO_ID

            # set SUDO_ID to root if not entered
            if [ "$SUDO_ID" ]; then
                OUT=$(groups ${SUDO_ID} | grep "sudo")
            else
                SUDO_ID="root"
                # manually assign $OUT to anything because we will use root!
                OUT="root"
            fi
        done

        # re-run script with $SUDO_ID 
        echo
        echo "Enter password for $SUDO_ID (need to enter twice)."
        su -l $SUDO_ID -c "sudo bash $0 $@"
        LASTERRORLEVEL=$?

        # give 2nd chance if entered pwd wrong (su doesn't give 2nd chance)
        if [ $LASTERRORLEVEL == 1 ]; then
            su -l $SUDO_ID -c "sudo bash $0 $@"
            LASTERRORLEVEL=$?
        fi
    fi

    echo
    read -p "FINISHED:  Press <ENTER> to exit..."
    exit $LASTERRORLEVEL
fi

# ------------------------------------------------------------------------------
# Include bash_functions.sh to source certain functions for this script
# Note: This must follow the "Setup script to run with superuser permissions"
# code above which starts up a new shell process, preventing exported variables 
# to be visible to the code below.
# ------------------------------------------------------------------------------
#echo "BASH_SOURCE[0] is: ${BASH_SOURCE[0]}"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
#echo "DIR is: $DIR"
. $DIR/bash_functions.sh # $DIR is the path prefix to bash_functions.sh as well as to the current script

# ------------------------------------------------------------------------------
# Main program starts here
# ------------------------------------------------------------------------------
#echo -e "\nNumber of parameters: $#"
echo -e "\n"
case $# in
    0) 
      echo "$SYNCWASTAOFFLINESCRIPT was invoked without any parameters:"
      echo "  Directory to sync from is: $COPYFROMDIR (default)"
      echo "  Directory to sync to is:   $COPYTODIR (default)"
        ;;
    1) 
      COPYTODIR="$1"
      echo "$SYNCWASTAOFFLINESCRIPT was invoked with 1 parameter:"
      echo "  Directory to sync from is: $COPYFROMDIR (default)"
      echo "  Directory to sync to is:   $COPYTODIR (parameter 1)"
        ;;
    2) 
      COPYFROMDIR="$1"
      COPYTODIR="$2"
      echo "$SYNCWASTAOFFLINESCRIPT was invoked with 2 parameters:"
      echo "  Directory to sync from is: $COPYFROMDIR (parameter 1)"
      echo "  Directory to sync to is:   $COPYTODIR (parameter 2)"
        ;;
    3) 
      COPYFROMDIR="$1"
      COPYTODIR="$2"
      PREPNEWUSB="$3"
      echo "$SYNCWASTAOFFLINESCRIPT was invoked with 2 parameters:"
      echo "  Directory to sync from is: $COPYFROMDIR (parameter 1)"
      echo "  Directory to sync to is:   $COPYTODIR (parameter 2)"
      echo "  Parameter '$3' included"
        ;;
    *)
      echo "Unrecognized parameters used with script."
      echo "Usage:"
      echo "$SYNCWASTAOFFLINESCRIPT [<source-dir-path>] [<destination-dir-path>]"
      exit 1
        ;;
esac

# Check to see if a "LM-UPDATES" full Wasta-Offline mirror is plugged in to the system.
# Note: Do not use parenthesis around the if condition so as not to spawn a child process
# for the function call (which would prevent exported variables such as $MOUNTPOINT from 
# being visible here).
if get_valid_LM_UPDATES_mount_point "$3" ; then
  # Either a mount point was found for LM-UPDATES, or an inserted but unmounted "LM-UPDATES"
  # USB drive was successfully mounted
  echo " "
else
  # The function itself informs user of any errors or abort messages
  echo -e "\nCannot Synchronize Wasta-Offline data to the destination location. Aborting..."
  exit 1
fi

# The MOUNTPOINT variable was set in get_valid_LM_UPDATES_mount_point () above, but it doesn't
# propagate back here, so we'll refresh the MOUNTPOINT here again
# Get the mount point for any plugged in external USB drive containing LM-UPDATES label that is 
# part of the $COPYTODIR or $COPYFROMDIR paths
export MOUNTPOINT=`mount | grep LM-UPDATES | cut -d ' ' -f3` # normally MOUNTPOINT is /media/LM-UPDATES
echo "MOUNTPOINT is: $MOUNTPOINT"

# Determine if user still has mirror directly off /data dir rather than the better /data/master dir
# If the user still has mirror at /data then offer to move (mv) it to /data/master

# Check whether an older master mirror exists at:
#   /data/wasta-offline/apt-mirror/mirror/
# If so, offer to do a fast mv to relocate the older master mirror to the new location of:
#   /data/master/wasta-offline/apt-mirror/mirror/
# and adjust the user's mirror.list file
# TODO: Could make the following if ... fi block into a function called
#       move_mirror_from_data_to_data_master ()
# TODO: Any changes to this block should also be made in make_Master_for_Wasta-Offline.sh
# TODO: where the same function could be used.
if [ -d $DATADIR$OFFLINEDIR$APTMIRRORDIR$MIRRORDIR ]; then
  echo -e "\nThere appears to be a master mirror at: "
  echo "   $DATADIR$OFFLINEDIR"
  echo "Your current master mirror location can cause spurious launchings of the"
  echo "wasta-offline program at bootup. We highly recommend you relocate your master"
  echo "mirror into a sub-directory within the $DATADIR directory named 'master'."
  echo "Do you want to do a fast (mv) relocation of your existing mirror to:"
  echo "   $DATADIR$MASTERDIR$OFFLINEDIR [y/n]?"
  for (( i=$WAIT; i>0; i--)); do
      printf "\rPlease press the y or n key, or hit any key to abort - countdown $i "
      read -s -n 1 -t 1 response
      if [ $? -eq 0 ]
      then
          break
      fi
  done
  if [ ! $response ]; then
    echo -e "\nNo selection made, or no reponse within $WAIT seconds. Assuming response of n"
    response="n"
  fi
  echo -e "\nYour choice was $response"
  #read -r -n 1 -p "Replace it with the NEWER mirror from the external hard drive? [y/n] " response
  case $response in
    [yY][eE][sS]|[yY]) 
        echo -e "\nCreating directory at $DATADIR$MASTERDIR"
        # Don't use -p in the mkdir command here. If a 'master' dir exists in /data/ we want it to return an error.
        mkdir $DATADIR$MASTERDIR
        LASTERRORLEVEL=$?
        if [ $LASTERRORLEVEL != 0 ]; then
          echo -e "\nCannot create master mirror directories at $DATADIR$MASTERDIR"
          echo "because a directory already exists at $DATADIR$MASTERDIR"
          echo "Move the existing directory out of the way, then run this script again."
          echo "Aborting..."
          exit $LASTERRORLEVEL
        fi
        echo "Change ownership of master directory to apt-mirror:apt-mirror"
        echo "Change permissions of master directory to ugo+rw"
        chown -R apt-mirror:apt-mirror $DATADIR$MASTERDIR
        chmod -R ugo+rw $DATADIR$MASTERDIR
        echo "Relocating the master mirror to: $DATADIR$MASTERDIR"
        #mv /data/wasta-offline /data/master/wasta-offline
        mv $DATADIR$OFFLINEDIR $DATADIR$MASTERDIR$OFFLINEDIR
        LASTERRORLEVEL=$?
        if [ $LASTERRORLEVEL != 0 ]; then
          echo -e "\nCannot move (mv) the master mirror directories to: $DATADIR$MASTERDIR"
          echo "Aborting..."
          exit $LASTERRORLEVEL
        fi
        echo "Relocating the master mirror scripts from: $DATADIR to: $DATADIR$MASTERDIR"
        mv $DATADIR/*.sh $DATADIR$MASTERDIR
        echo "Relocating the master mirror apt-mirror-setup dir and postmirror*.sh files..."
        mv $DATADIR/$APTMIRRORSETUPDIR $DATADIR$MASTERDIR
        echo "Relocating the master mirror wasta-offline packages..."
        mv $DATADIR/wasta-offline_*.deb $DATADIR$MASTERDIR
        echo "Relocating the master mirror ReadMe and README.md files..."
        mv $DATADIR/ReadMe $DATADIR$MASTERDIR
        #mv $DATADIR/README.md $DATADIR$MASTERDIR
        echo "Modifying base_path in mirror.list file to use: "
        echo "   $DATADIR$MASTERDIR$OFFLINEDIR$APTMIRRORDIR"
        sed -i 's|'$DATADIR$OFFLINEDIR$APTMIRRORDIR'|'$DATADIR$MASTERDIR$OFFLINEDIR$APTMIRRORDIR'|g' /etc/apt/mirror.list
        ;;
     *)
        echo -e "\nNo action taken! Aborting..."
        exit 0
        ;;
  esac
fi

# Determine the direction of copy/sync operation
# Either $COPYTODIR or $COPYFROMDIR could contain the .../LM-UPDATES path depending on
# which direction the user wants to sync the data when calling this script.
if [[ $COPYTODIR == */LM-UPDATES* ]]; then
  # COPYTODIR has the .../LM-UPDATES mount point within it
  # Use the MOUNTPOINT as the base dir
  COPYTOBASEDIR=$MOUNTPOINT  # /media/LM-UPDATES or /media/<user>/LM-UPDATES
  # Initially have COPYFROMBASEDIR assigned the value of COPYFROMDIR
  COPYFROMBASEDIR=$COPYFROMDIR  # /data/master/wasta-offline/
  # Strip off any '/', /apt-mirror, and /wasta-offline from right end of COPYFROMDIR
  # to get COPYFROMBASEDIR
  COPYFROMBASEDIR=${COPYFROMBASEDIR%"/"}  # /data/master/wasta-offline
  COPYFROMBASEDIR=${COPYFROMBASEDIR%$APTMIRRORDIR}  # /data/master/wasta-offline
  #echo "COPYFROMBASEDIR is: $COPYFROMBASEDIR"
  COPYFROMBASEDIR=${COPYFROMBASEDIR%"/"}  # /data/master/wasta-offline
  COPYFROMBASEDIR=${COPYFROMBASEDIR%$OFFLINEDIR}  # /data/master
# whm Note: as of 17Apr2016 we make the /data/master dir be the COPYTOBASEDIR
#  COPYFROMBASEDIR=${COPYFROMBASEDIR%$MASTERDIR}  # /data
  echo "COPYFROMDIR is: $COPYFROMDIR"
  echo "COPYFROMBASEDIR is: $COPYFROMBASEDIR"
  echo "COPYTODIR is: $COPYTODIR"
  echo "COPYTOBASEDIR is: $COPYTOBASEDIR"
else
  # COPYFROMDIR has the .../LM-UPDATES mount point within it
  # Use the MOUNTPOINT as the base dir.
  COPYFROMBASEDIR=$MOUNTPOINT  # /media/LM-UPDATES or /media/<user>/LM-UPDATES
  # Initially have COPYTOBASEDIR assigned the value of COPYTODIR
  COPYTOBASEDIR=$COPYTODIR
  # Strip off any '/', /apt-mirror, and /wasta-offline from right end of COPYTODIR
  # to get COPYTOBASEDIR
  COPYTOBASEDIR=${COPYTOBASEDIR%"/"} # /data/master/wasta-offline
  COPYTOBASEDIR=${COPYTOBASEDIR%$APTMIRRORDIR}  # /data/master/wasta-offline
  #echo "COPYTOBASEDIR is: $COPYTOBASEDIR"
  COPYTOBASEDIR=${COPYTOBASEDIR%"/"} # /data/master/wasta-offline
  COPYTOBASEDIR=${COPYTOBASEDIR%$OFFLINEDIR}  # /data/master
# whm Note: as of 17Apr2016 we make the /data/master dir be the COPYTOBASEDIR
#  COPYTOBASEDIR=${COPYTOBASEDIR%$MASTERDIR}  # /data
  echo "COPYFROMDIR is: $COPYFROMDIR"
  echo "COPYFROMBASEDIR is: $COPYFROMBASEDIR"
  echo "COPYTODIR is: $COPYTODIR"
  echo "COPYTOBASEDIR is: $COPYTOBASEDIR"
fi

# Check that there is a wasta-offline mirror at the source location. If not there is no
# sync operation that we can do.
if is_there_a_wasta_offline_mirror_at "$COPYFROMDIR" ; then
  # There is already a wasta-offline mirror at $COPYFROMDIR
  echo -e "\nFound a source mirror at: $COPYFROMDIR"
else
  # There is no wasta-offline mirror at the source location, so notify user and abort.
  echo -e "\nCannot find a source mirror at: $COPYFROMDIR"
  echo "Therefore, cannot update the USB mirror from this computer."
  exit 1
fi

# Check if there is a wasta-offline mirror at the destination. If not proceed with a
# copy of the full mirror to the destination. If there is a mirror already at the
# destination, check the destination mirror's wasta-offline/log file named 
# last-apt-mirror-update and compare its timestamp with the source mirror's timestamp. 
# Warn the user if they are about to sync one mirror to an existing mirror, especially
# if we are about to sync an older mirror to a newer mirror.
if is_there_a_wasta_offline_mirror_at "$COPYTODIR" ; then
    # There is already a wasta-offline mirror at $COPYTODIR
    echo -e "\nFound a destination mirror at: $COPYTODIR"
    # Check the destination mirror's wasta-offline/log file named last-apt-mirror-update 
    # and compare its timestamp with the source mirror's timestamp. Warn the user if they are
    # about to sync an older mirror to a newer mirror.
    # Check if the existing mirror is newer than the one on the external USB drive
    is_this_mirror_older_than_that_mirror "$COPYTODIR" "$COPYFROMDIR"
    OlderNewerSame=$?
    case $OlderNewerSame in
      "0")
      # An OLDER copy of the wasta-offline mirror already exists!
      # Replace it with the newer mirror from the external hard drive? [y/n]
      # Have the timer on the prompt default to 'y'
      echo "An OLDER copy of the wasta-offline mirror already exists at the destination!"
      # An automatic default response to a newer mirror updating an older mirror should be "Yes"
      # so, have a 60 second countdown that auto selects 'y' at the end of the countdown, but if
      # a user is in attendance, the user can opt for 'n' by choice. 
      echo "Replace it with the NEWER mirror from the source location? [y/n]"
      for (( i=$WAIT; i>0; i--)); do
          printf "\rPlease press the y or n key, or hit any key to abort - countdown $i "
          read -s -n 1 -t 1 response
          if [ $? -eq 0 ]
          then
              break
          fi
      done
      if [ ! $response ]; then
        echo -e "\nNo selection made, or no reponse within $WAIT seconds. Assuming response of y"
        response="y"
      fi
      echo -e "\nYour choice was $response"
      #read -r -n 1 -p "Replace it with the NEWER mirror from the external hard drive? [y/n] " response
      case $response in
        [yY][eE][sS]|[yY]) 
            echo -e "\nUpdating the full Wasta-Offline Mirror at: $COPYTODIR..."
            # The main rsync command is called below
            ;;
         *)
            echo -e "\nNo action taken! Aborting..."
            exit 0
            ;;
      esac
      ;;
      "1")
      # A NEWER copy of the wasta-offline mirror already exists!
      # Replace it with the older mirror from the external hard drive? [y/n] 
      # Have the timer on the prompt default to 'n'
      echo "A NEWER copy of the wasta-offline mirror already exists at the destination!"
      # An automatic default response to an older mirror updating a newer mirror should be "No"
      # so, have a 60 second countdown that auto selects 'n' at the end of the countdown, but if
      # a user is in attendance, the user can opt for 'y' by choice. 
      echo "Replace it with the OLDER mirror from the source location? [y/n]"
      for (( i=$WAIT; i>0; i--)); do
          printf "\rPlease press the y or n key, or hit any key to abort - countdown $i "
          read -s -n 1 -t 1 response
          if [ $? -eq 0 ]
          then
              break
          fi
      done
      if [ ! $response ]; then
        echo -e "\nNo selection made, or no reponse within $WAIT seconds. Assuming response of n"
        response="n"
      fi
      echo -e "\nYour choice was $response"
      #read -r -n 1 -p "Replace it with the OLDER mirror from the external hard drive? [y/n] " response
      case $response in
        [yY][eE][sS]|[yY]) 
            echo -e "\nRolling back the full Wasta-Offline Mirror at: $COPYTODIR..."
            # The main rsync command is called below
            ;;
         *)
            echo -e "\nNo action taken! Aborting..."
            exit 0
            ;;
      esac
      ;;
      "2")
      # The same copy of the wasta-offline mirror already exists!
      # Replace it with the older mirror from the external hard drive? [y/n] 
      # Have the timer on the prompt default to 'n'
      echo "The SAME copy of the wasta-offline mirror already exists at the destination!"
      # An automatic default response to a mirror updating the "same" mirror should be "No"
      # so, have a 60 second countdown that auto selects 'n' at the end of the countdown, but if
      # a user is in attendance, the user can opt for 'y' by choice. 
      echo "Replace it with the mirror from the source location? [y/n]"
      for (( i=$WAIT; i>0; i--)); do
          printf "\rPlease press the y or n key, or hit any key to abort - countdown $i "
          read -s -n 1 -t 1 response
          if [ $? -eq 0 ]
          then
              break
          fi
      done
      if [ ! $response ]; then
        echo -e "\nNo selection made, or no reponse within $WAIT seconds. Assuming response of n"
        response="n"
      fi
      echo -e "\nYour choice was $response"
      #read -r -n 1 -p "Replace it anyway with the mirror from the external hard drive? [y/n] " response
      case $response in
        [yY][eE][sS]|[yY]) 
            echo -e "\nReplacing the full Wasta-Offline Mirror at: $COPYTODIR..."
            # The main rsync command is called below
            ;;
         *)
            echo -e "\nNo action taken! Aborting..."
            exit 0
            ;;
      esac
      ;;
      "3")
      # Could not find a valid wasta-offline path at the $1 parameter location
      echo "No valid wasta-offline mirror found at: $COPYTODIR"
      echo "Cannot continue. Aborting..."
      exit 1
     ;;
      "4")
      # Could not find a valid wasta-offline path at the $1 parameter location
      echo "No valid wasta-offline mirror found at: $COPYFROMDIR"
      echo "Cannot continue. Aborting..."
      exit 1
      ;;
      "5")
      echo "Programming Error: Invalid parameters."
      echo "The source and destination locations are one in the same!"
      echo "Cannot continue. Aborting..."
      exit 1
      ;;
      "6")
      echo "Programming Error: Invalid parateters given to the following function: "
      echo "   is_this_mirror_older_than_that_mirror ()..."
      echo "Cannot continue. Aborting..."
      exit 1
      ;;
      "7")
      echo "No Timestamp file found at destination, assuming the mirror there is older."
      # A mirror without our Timestamp is probably older mirror. Hence, an automatic default 
      # response to a mirror updating a mirror with no Timestamp probably should be "Yes".
      # so, have a 60 second countdown that auto selects 'y' at the end of the countdown, but if
      # a user is in attendance, the user can opt for 'n' by choice. 
      echo "Replace it with the mirror from the source location? [y/n]"
      for (( i=$WAIT; i>0; i--)); do
          printf "\rPlease press the y or n key, or hit any key to abort - countdown $i "
          read -s -n 1 -t 1 response
          if [ $? -eq 0 ]
          then
              break
          fi
      done
      if [ ! $response ]; then
        echo -e "\nNo selection made, or no reponse within $WAIT seconds. Assuming response of n"
        response="y"
      fi
      echo -e "\nYour choice was $response"
      #read -r -n 1 -p "Replace destination mirror using the mirror on the external hard drive? [y/n] " response
      case $response in
        [yY][eE][sS]|[yY]) 
            echo -e "\nUpdating the full Wasta-Offline Mirror at: $COPYTODIR..."
            # The main rsync command is called below
            ;;
         *)
            echo -e "\nNo action taken! Aborting..."
            exit 0
            ;;
      esac
      ;;
    esac
else
    echo -e "\nNo existing mirror found at: $COPYTODIR"
    # We can proceed with the copy process - same as the 'y' (YES) case above.
    echo -e "\nCreating a full Wasta-Offline Mirror at: $COPYTODIR..."
    # The main rsync command is called below
fi

# Ensure that there is an initial mirror directory structure at the destination (in case
# one doesn't exist yet)
mkdir -p $COPYTODIR
LASTERRORLEVEL=$?
if [ $LASTERRORLEVEL != 0 ]; then
  echo -e "\nCannot create mirror directories at $COPYTODIR - is the Drive writeable?"
  echo "You might try rebooting the computer and running this script again."
  echo "Aborting..."
  exit $LASTERRORLEVEL
fi
# Ensure that the external <destination-mirror-path> exists and is writeable
if [ ! -d "$COPYTODIR" ]; then
  # $COPYTODIR doesn't exist so abort
  echo -e "\nThe mirror directories at $COPYTODIR do not exist - is the Drive writeable?"
  echo "You might try rebooting the computer and running this script again."
  echo "Aborting..."
  exit 1
else
  echo -e "\nFound $COPYTODIR"
  # Take care of any source and destination mirror ownership and permission issues at
  # the source and destination, in case they have changed.
  #
  # An apt-mirror's directory tree and content need to be owned by apt-mirror for cron 
  # to work.
  # Make sure source mirror owner is apt-mirror:apt-mirror and everything in the mirror 
  # tree is read-write for everyone.
  if set_mirror_ownership_and_permissions "$COPYFROMBASEDIR" ; then
    # All chown and chmod operations were successful
    echo -e "\nSet mirror ownership and permissions successfully at: $COPYFROMBASEDIR"
  else
    echo -e "\nNot all mirror ownership and permissions could be set at: $COPYFROMBASEDIR"
  fi

  # Before setting the destination's ownership and permissions, use rsync to copy all of
  # the necessary files from the source's base directory to the destination.
  # Parameters: # $COPYFROMBASEDIR (normally: /data/master) and $COPYTOBASEDIR (normally: /media/LM-UPDATES).
  echo "The COPYFROMBASEDIR is: $COPYFROMBASEDIR"
  echo "The COPYTOBASEDIR is: $COPYTOBASEDIR"
  if copy_mirror_root_files "$COPYFROMBASEDIR" "$COPYTOBASEDIR" ; then
    # All chown and chmod operations were successful
    echo -e "\nCopied source mirror's root directory files to destination mirror."
  else
    echo -e "\nNot all source mirror's root directory files could be copied!"
  fi

  # Make sure destination mirror owner is apt-mirror:apt-mirror and everything in the mirror
  # tree is read-write for everyone.
  if set_mirror_ownership_and_permissions "$COPYTOBASEDIR" ; then
    # All chown and chmod operations were successful
    echo "Set mirror ownership and permissions successfully at: $COPYTOBASEDIR"
  else
    echo "Not all mirror ownership and permissions could be set at: $COPYTOBASEDIR"
  fi
fi

# Note: Since the clean.sh script is created on the fly by each fresh run of apt-mirror
# it should only be called from the postmirror.sh script.
# Clean the source data

# Note: To recurse through the source directory rsync wants the source directory
# path to have a final slash /, so check the $COOPYFROMDIR and if it does not 
# have final slash add it.
STRLEN=${#COPYFROMDIR}-1
if [ "${COPYFROMDIR:STRLEN}" != "/" ]; then
  COPYFROMDIR=$COPYFROMDIR"/"
fi
# rsync also expects the destination directory to not end with a slash,
# so check if $COPYTODIR has a final slash, if so remove it.
COPYTODIR=${COPYTODIR%/}

############### The Main Sync Operation Happens Here ########################
# Sync the data from the updated mirror to the USB external drive's mirror
# Note: The rsync call below should preserve all ownership and permissions
# from the source mirror's tree (set above) to the destination mirror's tree.
echo "Synchronizinging data via the following rsync command:"
echo "rsync -avzP --delete $COPYFROMDIR $COPYTODIR"
# Here is the main rsync command. The rsync options are:
#   -a archive mode (recurses thru dirs, preserves symlinks, permissions, times, group, owner)
#   -v verbose
#   -z compress file data during transfer
#   --progress show progress during transfer
#   --delete delete extraneous files from the destination dirs
rsync -avz --progress --delete $COPYFROMDIR $COPYTODIR
############### The Main Sync Operation Happens Here ########################

LASTERRORLEVEL=$?
if [ $LASTERRORLEVEL != 0 ]; then
  echo -e "\nCould not rsync the mirror data to $COPYTODIR. Aborting..."
  return $LASTERRORLEVEL
fi

# The DRIVEWASFORMATTED var was determined in the get_valid_LM_UPDATES_mount_point () function earlier above
if [ "$DRIVEWASFORMATTED" = "TRUE" ]; then
  echo -e "\nThe USB drive was formatted with the Linux Ext4 file system"
  echo "and the full Wasta-Offline mirror was copied to the drive."
  echo "Please be sure to label the drive with the following information:"
  echo "    Full Wasta-Offline Mirror for Precise and Trusty"
  echo "    Mounted Name: /media/LM-UPDATES"
  echo "    Has Ext4 File System - Readable Only on Linux Systems"
  echo "    To Update See ReadMe File"
fi

echo -e "\nThe $SYNCWASTAOFFLINESCRIPT script has finished."

