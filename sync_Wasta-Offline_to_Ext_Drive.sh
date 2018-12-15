#!/bin/bash
# Author: Bill Martin <bill_martin@sil.org>
# Date: 4 November 2014
# Revision: 
#   - 7 November 2014 Modified for Trusty mount points having embedded $USER 
#      in $USBMOUNTPOINT path as: /media/$USER/<DISK_LABEL> whereas Precise has: 
#      /media/<DISK_LABEL>
#   - 26 April 2016 Revised to use a default source master mirror location of
#      /data/master/. If a master mirror still exists at the old /data location
#      the script now offers to quickly move (mv) the master mirror from its
#      /data location to the more recommended /data/master location.
#     Added a script version number "0.1" to the script to make future updates
#      easier.
#   - 29 September 2016 COPYFROMBASEDIR and COPYTOBASEDIR were not being
#      calculated properly, fixed by use of dirname on COPYFROMDIR and COPYTODIR.
#   - 28 August 2017 Adjusted the copy_mirror_base_dir_files () function to include
#      copying the bills-wasta-docs dir to the Ext drive.
#   - 23 November 2018 Did a major revision to make the script more generalized.
#      Did a general cleanup of the script and comments.
#      Moved script variables to a section after superuser setup.
#      Revised to remove hard coded "LM-UPDATES" disk label and
#      make the script more generalized. Removed the "PREP_NEW_USB" parameter
#      option which was unused. 
#      Streamlined the detection of the USB drive's mount point using echoed 
#      output from the get_wasta_offline_usb_mount_point () function.
#      Used a new get_device_name_of_usb_mount_point () function to determine
#      the device name of the USB drive's mount point.
#      Used a new get_file_system_type_of_usb_partition () function to determine
#      the file system type of the USB drive at the mount point.
#      Added sleep statements to pause output for better monitoring of progress.
#      Made Abort warnings more visible in console output.
#      Removed 'export' from all variables - not needed for variable visibility.
# Name: sync_Wasta-Offline_to_Ext_Drive.sh
# Distribution: 
# This script is included with all Wasta-Offline Mirrors supplied by Bill Martin.
# If you make changes to this script to improve it or correct errors, please send
# your updated script to Bill Martin bill_martin@sil.org
# The scripts are maintained on GitHub at:
# https://github.com/pngbill-scripts/wasta-scripts

# Purpose: 
# The primary purpose of this script is to synchronize an out-of-date full Wasta-Offline 
# mirror from a more up-to-date full Wasta-Offline mirror. The script is flexible enough
# to do this synchronization between any two full Wasta-Offline mirrors located at
# different paths. The more up-to-date mirror should be referred to as the "source" 
# mirror and the out-of-date mirror should be referred to as the "destination" mirror. 
# Normally, the more up-to-date mirror (the source) will be a master Wasta-Offline 
# mirror that gets regularly updated via calls to the apt-mirror program (using our 
# update-mirror.sh script). Generally the master mirror will be located at a path which 
# this script defaults to the local computer's /data/master/wasta-offline/ folder. 
# The out-of-date mirror (the destination) will usually be on an external 1TB USB drive. 
# When plugged in, the external USB drive will normally be mounted at:
# /media/$USER/<DISK_LABEL>/wasta-offline on an Ubuntu or Wasta based system - since 
# version 14.04 (Trusty and later).
#
# NOTE: These Wasta-Offline scripts are for use by administrators and not normal
# Wasta-Linux users. The Wasta-Offline program itself need not be running when you, 
# as administrator are running these scripts. Hence, when you plug in a USB drive 
# containing the full Wasta-Offline Mirror - intending to update the mirror with this
# sync_Wasta-Offline_to_Ext_Drive.sh script - and the Authentication/Password message 
# appears, you as administrator, should just click Cancel - to stop wasta-offline from
# running. The USB drive should remain plugged in/mounted, but wasta-offline need not
# be running when executing any of the scripts provided by Bill Martin.
#
# As you know, when a USB drive equipped with a full Wasta-Offline Mirror is plugged
# in to a Wasta Linux system, the Wasta system automatically asks for Authentication 
# in order to start up the wasta-offline program. That is by design - to make it
# easier for end-users to update their software by simply plugging in the portable 
# USB drive containing the Full Wasta-Offline mirror, clicking a couple OK buttons, 
# and when the "Ready" message appears, doing normal system software updates via the
# panel/menu items designed for that purpose. The USB drive's mirror allows fast and
# free access to the world-wide body of Linux software and updates - completely 
# offline - instead of having to use the expensive and slow Internet. However, the 
# wasta-offline program itself never needs to run while using these scripts to
# accomplish their purposes. 
#
# The 'source' and 'destination' paths can be altered by passing different path values 
# to this script via its $1 and $2 parameters.
# Both the 'source' path and 'destination' path should be on file systems formatted 
# as Linux file systems (Ext3 or Ext4) since the rsync utility used to synchronize
# and/or copy the mirror data, is called in such a way as to preserve the source and
# destination mirrors' ownership, group and permissions. 
# This script may also be used to copy or sync the full mirror from any one location 
# to another. Here are some example uses:
#   * Synchronize an external USB drive to bring it up-to-date (default use)
#   * Create a backup copy of the master apt-mirror tree to a safe location
#   * Restore a broken or lost master mirror from a backup copy
#   * Create a new master mirror on a computer from an external USB drive's copy 
#     (the make_Master_for_Wasta-Offline.sh script actually calls this 
#     sync_Wasta-Offline_to_Ext_Drive.sh script for that purpose).
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
#   4. Ensures there is a valid mount point for the external USB drive.
#   5. Determines a base directory for the destination and source mirror trees.
#   6. Determines whether there is a local copy of the wasta-offline software mirror
#      at the old /data/wasta-offline/apt-mirror/mirror/ location. If one is found at
#      the old location, the script offers to quickly move (mv) the master mirror
#      from its /data location to the more recommended /data/master location. 
#   7. Checks to ensure that the source mirror path with an apt-mirror tree exists, 
#      if not aborts.
#   8. Checks if a mirror exists at the destination, and if so whether the mirror is 
#      older than the source mirror, and handles 7 possible check result scenarios
#      (OLDER, NEWER, SAME, No Timestamp, etc).
#   9. Ensures that there is a destination mirror structure (up to the apt-mirror
#      directory level), if it doesn't already exist.
#  10. Ensure that the destination path exists and is writeable. If not issue
#      warning and abort. 
#  10. Sets the source mirror's owner:group properties to apt-mirror:apt-mirror, 
#      and sets the source mirror's content permissions to ugo+rw (read-write for
#      everyone) by calling the set_mirror_ownership_and_permissions () function
#      on the $COPYFROMBASEDIR.
#  11. Synchronizes/Copies all of the source mirror's "root" directory files to the
#      destination's "root" directory, by calling the copy_mirror_base_dir_files ()
#      function with "$COPYFROMBASEDIR" "$COPYTOBASEDIR" parameters.
#      The "root" directory here refers to the 
#      directory of the device or drive where the mirror begins. For example, the
#      "root" directory of Bill's master copy is on a partition mounted at /data,
#      and the "root" directory of an attached USB Wasta-Offline Mirror - as 
#      supplied by Bill Martin - is at /media/<DISK_LABEL> or /media/$USER/<DISK_LABEL>. 
#      Those files include:
#        a. bash_functions.sh
#        b. make_Master_for_Wasta-Offline.sh
#        c. ReadMe
#        d. sync_Wasta-Offline_to_Ext_Drive.sh
#        e. update-mirror.sh
#        f. wasta-offline*.deb packages
#        g. postmirror.sh (in apt-mirror-setup and wasta-offline/apt-mirror/var subdirectories)
#        h. postmirror2.sh (in apt-mirror-setup and wasta-offline/apt-mirror/var subdirectories)
#  12. Sets the destination mirror's ownergroup properties to apt-mirror:apt-mirror
#      and sets the destination mirror's content permissions to ugo+rw (read-write 
#      for everyone) by calling the set_mirror_ownership_and_permissions () function
#      on the $COPYTOBASEDIR.
#  13. Ensures the source mirror directory path to be used with rsync ends with slash, 
#      and the destination directory path to be used with rsync does not end with slash.
#  14. Calls rsync to synchronize the mirror tree from the source tree after verifying that
#      $COPYFROMDIR ends with '/' and $COPYTODIR has no final '/' in their paths.
#      Normally, $COPYFROMDIR is the master mirror tree at /data/master/wasta-offline,
#      and $COPYTODIR is the external USB drive's mirror at /media/$USER/<DISK_LABEL>/wasta-offline).
#      The source and destination will be reversed when this script is called from the
#      make_Master_for_Wasta-Offline.sh script to create a master mirror on a dedicated
#      computer. 
#      This copy will usually go relatively fast if the full mirror existed already on 
#      the external USB drive and you are only synchronizing fairly recent software updates. 
#      If the external USB drive was an empty drive the copy process to copy all 750+GB 
#      of mirror data from the local computer to the USB external drive may take about
#      5-8 hours for either a USB 2.0 or USB 3.0 connection.
#
# Usage:
# 1. Before updating/synchronizing an attached external drive with this script, the user
#    should have previously updated the master mirror at the "source" location - usually 
#    /data/master/wasta-offline/ - by doing one of the following:
#      a. Running the update-mirror.sh script (from File Manager or at a command line),
#         which will automatically run this synchronization script after updating the
#         source mirror, or
#      b. Running the command: sudo apt-mirror (at a command line).
# 2. bash sync_Wasta-Offline_to_Ext_Drive.sh [<source-mirror>] [destination-mirror]
#    All parameters are optional. 
#    If no parameters are given, "/data/master/wasta-offline/" is assumed to be the path to 
#       the up-to-date source mirror, and "/media/$USER/<DISK_LABEL>/wasta-offine" is assumed 
#       to be the path to the destination mirror that needs updating.
#    If only one parameter is given, it is the user-specified path to the external USB 
#       drive's 'destination' mirror's wasta-offline directory, and if that is the case
#       /data/master/wasta-offline is assumed to be the source (master) mirror.
#    If two parameters are given, the 1st is the path to the local computer's updated
#       wasta-offline 'source' mirror's wasta-offline directory, and 2nd is the path to 
#       the 'destination' mirror's wasta-offline directory that needs to be 
#       updated/synchronized (usually external USB drive).
#       Note: It is recommended to establish a master copy of the full mirror on a
#       computer dedicated to maintaining the master mirror, and keep the master
#       mirror updated (with the updata-mirror.sh script). The initial creation of the
#       master mirror should be accomplished using a one-time call of the 
#       make_Master_for_Wasta-Offline.sh script for that purpose. It is possible to 
#       make a master copy of the full mirror (or a backup) by calling this 
#       sync_Wasta-Offline_to_Ext_Drive.sh script manually with the appropriate 
#       source and destination path parameters, but this is not recommended. Instead
#       use the make_Master_for_Wasta-Offline.sh script which was designed for that
#       purpose. Having a master copy of the full mirror is very desirable if administrators 
#       want to establish a local master copy of the full mirror to which updates are 
#       then maintained (utilizing the supplied update-mirror.sh script) from a 
#       zero-cost local network server, or even from an affordable (unlimited data) 
#       Internet connection. Copying 750+TB from an existing mirror to a new location 
#       through a USB cable to a local computer is much faster than attempting to 
#       download the same amount of data through a DSL or wireless connection.
##   Requires sudo/root privileges - password requested at run-time.

# Note when set -e is uncommented, script stops immediately and no error codes are returned in "$?"
#set -e

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
# code above which starts up a new shell process, preventing any exported variables 
# declared before the above block from being visible to the code below.
# ------------------------------------------------------------------------------
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $DIR/bash_functions.sh # $DIR is the path prefix to bash_functions.sh as well as to the current script

# ------------------------------------------------------------------------------
# Set up some script variables
# ------------------------------------------------------------------------------
SCRIPTVERSION="0.2"
WASTAOFFLINEPKGURL="http://ppa.launchpad.net/wasta-linux/wasta-apps/ubuntu/pool/main/w/wasta-offline"
DATADIR="/data"
MASTERDIR="/master"
APTMIRROR="apt-mirror"
BILLSWASTADOCSDIR="/bills-wasta-docs"
WASTAOFFLINEDIR="/wasta-offline"
APTMIRRORDIR="/apt-mirror"
APTMIRRORSETUPDIR="/apt-mirror-setup"
MIRRORDIR="/mirror"
UPDATEMIRRORSCRIPT="update-mirror.sh"
SYNCWASTAOFFLINESCRIPT="sync_Wasta-Offline_to_Ext_Drive.sh"
POSTMIRRORSCRIPT="postmirror.sh"
POSTMIRROR2SCRIPT="postmirror2.sh"

# See NOTEs later in this script that explain what paths can be pointed to by $COPYFROMDIR and $COPYTODIR.
COPYFROMDIR=$DATADIR$MASTERDIR$WASTAOFFLINEDIR"/"  # /data/master/wasta-offline/ is now the default source dir
USBDEVICENAME=""
USBFILESYSTEMTYPE=""

echo -e "\n[*** Now executing the $SYNCWASTAOFFLINESCRIPT script ***]"
sleep 3s

# Use the get_wasta_offline_usb_mount_point () function to get a value for USBMOUNTPOINT
USBMOUNTPOINT=`get_wasta_offline_usb_mount_point`  # normally USBMOUNTPOINT is /media/$USER/<DISK_LABEL>/wasta-offline
echo -e "\nThe USB drive mount point is: $USBMOUNTPOINT"
if [ "x$USBMOUNTPOINT" = "x" ]; then
  # $USBMOUNTPOINT for a USB drive containing a wasta-offline subfolder was not found
  USBMOUNTDIR=""
  COPYTODIR=""
  # The $USBMOUNTPOINT variable is empty, i.e., a wasta-offline subdirectory on /media/... was not found
  echo -e "\nWasta-Offline data was NOT found at /media/..."
  echo "Device Name of USB at $USBMOUNTPOINT: Unknown"
  echo "File system TYPE of USB Drive: Unknown"
else
  # The USBMOUNTDIR value should be the path up to, but not including /wasta-offline of $USBMOUNTPOINT
  USBMOUNTDIR=$USBMOUNTPOINT
  if [[ $USBMOUNTPOINT == *"wasta-offline"* ]]; then 
    USBMOUNTDIR=$(dirname "$USBMOUNTPOINT")
  fi
  COPYTODIR=$USBMOUNTPOINT  # /media/$USER/<DISK_LABEL>/wasta-offline
  #echo -e "\nWasta-Offline data was found at: $USBMOUNTPOINT"
  # Use the get_device_name_of_usb_mount_point () function with $USBMOUNTPOINT parameter to get USBDEVICENAME
  USBDEVICENAME=`get_device_name_of_usb_mount_point $USBMOUNTPOINT`
  #echo "Device Name of USB at $USBMOUNTPOINT: $USBDEVICENAME"
  # Use the get_file_system_type_of_usb_partition () function with $USBDEVICENAME parameter to get USBFILESYSTEMTYPE
  USBFILESYSTEMTYPE=`get_file_system_type_of_usb_partition $USBDEVICENAME`
  #echo "File system TYPE of USB Drive: $USBFILESYSTEMTYPE"
fi
DATADIRVARDIR=$DATADIR$MASTERDIR$WASTAOFFLINEDIR$APTMIRRORDIR"/var" # /data/master/wasta-offline/apt-mirror/var
CLEANSCRIPT=$COPYFROMDIR"apt-mirror/var/clean.sh" # /data/master/wasta-offline/apt-mirror/var/clean.sh
WAIT=60
LastAppMirrorUpdate="last-apt-mirror-update" # used in is_this_mirror_older_than_that_mirror () function

# ------------------------------------------------------------------------------
# Main program starts here
# ------------------------------------------------------------------------------
#echo -e "\nNumber of parameters: $#"
echo -e "\nThe SUDO_USER is: $SUDO_USER"
sleep 3s
case $# in
    0) 
      echo -e "\nThis $SYNCWASTAOFFLINESCRIPT script invoked without any parameters:"
      echo "  Directory to sync from is: $COPYFROMDIR (default)"
      echo "  Directory to sync to is:   $COPYTODIR (default)"
        ;;
    1) 
      COPYTODIR="$1"
      echo -e "\nThis $SYNCWASTAOFFLINESCRIPT script was invoked with 1 parameter:"
      echo "  Directory to sync from is: $COPYFROMDIR (default)"
      echo "  Directory to sync to is:   $COPYTODIR (parameter 1)"
        ;;
    2) 
      COPYFROMDIR="$1"
      COPYTODIR="$2"
      echo -e "\nThis $SYNCWASTAOFFLINESCRIPT script was invoked with 2 parameters:"
      echo "  Directory to sync from is: $COPYFROMDIR (parameter 1)"
      echo "  Directory to sync to is:   $COPYTODIR (parameter 2)"
        ;;
    3) 
      COPYFROMDIR="$1"
      COPYTODIR="$2"
      PREPNEWUSB="$3"
      echo -e "\nThis $SYNCWASTAOFFLINESCRIPT script was invoked with 2 parameters:"
      echo "  Directory to sync from is: $COPYFROMDIR (parameter 1)"
      echo "  Directory to sync to is:   $COPYTODIR (parameter 2)"
      echo "  Parameter '$3' included"
        ;;
    *)
      echo -e "\nUnrecognized parameters used with script."
      echo "Usage:"
      echo "$SYNCWASTAOFFLINESCRIPT [<source-dir-path>] [<destination-dir-path>]"
      exit 1
        ;;
esac

# Determine if user still has mirror directly off /data dir rather than the better /data/master dir
# If the user still has mirror at /data then offer to move (mv) it to /data/master
# Removed call of move_mirror_from_data_to_data_master () function below. Probably not needed anymore.
#if ! move_mirror_from_data_to_data_master ; then
#  # User opted not to move mirror from /data to /data/master
#  echo -e "\nUser opted not to move (mv) the master mirror directories to: $DATADIR$MASTERDIR"
#  echo "Aborting..."
#  exit 1
#fi

# Check that there is a wasta-offline mirror at the source location. If not there is no
# sync operation that we can do.
sleep 3s
echo -e "\nChecking for a source mirror..."
if is_there_a_wasta_offline_mirror_at "$COPYFROMDIR" ; then
  # There is already a wasta-offline mirror at $COPYFROMDIR
  echo -e "\n   Found a source mirror at: $COPYFROMDIR"
else
  # There is no wasta-offline mirror at the source location, so notify user and abort.
  echo -e "\n****** WARNING ******"
  echo "Could not find a source mirror at: $COPYFROMDIR"
  echo "Therefore, cannot update the USB mirror from this computer."
  echo "****** WARNING ******"
  echo "Aborting..."
  exit 1
fi

# Check if there is a wasta-offline mirror at the destination. If not proceed with a
# copy of the full mirror to the destination. If there is a mirror already at the
# destination, check the destination mirror's wasta-offline/log file named 
# last-apt-mirror-update and compare its timestamp with the source mirror's timestamp. 
# Warn the user if they are about to sync one mirror to an existing mirror, especially
# if we are about to sync an older mirror to a newer mirror.
sleep 3s
echo -e "\nChecking for a destination mirror..."
if is_there_a_wasta_offline_mirror_at "$COPYTODIR" ; then
    # There is already a wasta-offline mirror at $COPYTODIR
    echo -e "\n   Found a destination mirror at: $COPYTODIR"
    # Check the destination mirror's wasta-offline/log file named last-apt-mirror-update 
    # and compare its timestamp with the source mirror's timestamp. Warn the user if they are
    # about to sync an older mirror to a newer mirror.
    # Check if the existing mirror is newer than the one on the external USB drive
    sleep 3s
    is_this_mirror_older_than_that_mirror "$COPYTODIR" "$COPYFROMDIR"
    OlderNewerSame=$?
    case $OlderNewerSame in
      "0")
      # An OLDER copy of the wasta-offline mirror already exists!
      # Replace it with the newer mirror from the external hard drive? [y/n]
      # Have the timer on the prompt default to 'y'
      echo "*******************************************************************************"
      echo "An OLDER copy of the wasta-offline mirror already exists at the destination!"
      # An automatic default response to a newer mirror updating an older mirror should be "Yes"
      # so, have a 60 second countdown that auto selects 'y' at the end of the countdown, but if
      # a user is in attendance, the user can opt for 'n' by choice. 
      echo "Replace it with the NEWER mirror from the source location? [y/n] (default='y')"
      echo "*******************************************************************************"
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
            echo -e "\nUpdating the Wasta-Offline Mirror at: $COPYTODIR..."
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
      echo "*******************************************************************************"
      echo "A NEWER copy of the wasta-offline mirror already exists at the destination!"
      # An automatic default response to an older mirror updating a newer mirror should be "No"
      # so, have a 60 second countdown that auto selects 'n' at the end of the countdown, but if
      # a user is in attendance, the user can opt for 'y' by choice. 
      echo "Replace it with the OLDER mirror from the source location? [y/n] (default='n')"
      echo "*******************************************************************************"
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
            echo -e "\nRolling back the Wasta-Offline Mirror at: $COPYTODIR..."
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
      # Replace/Update it with the 'same' mirror from the external hard drive? [y/n] 
      # Have the timer on the prompt default to 'n'
      echo "*******************************************************************************"
      echo "The SAME copy of the wasta-offline mirror already exists at the destination!"
      # An automatic default response to a mirror updating the "same" mirror should be "No"
      # so, have a 60 second countdown that auto selects 'n' at the end of the countdown, but if
      # a user is in attendance, the user can opt for 'y' by choice. 
      echo "Update/Sync it anyway from the source location? [y/n] (default='n')"
      echo "*******************************************************************************"
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
            echo -e "\nUpdating the Wasta-Offline Mirror at: $COPYTODIR..."
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
      echo -e "\n****** WARNING ******"
      echo "No valid wasta-offline mirror found at: $COPYTODIR"
      echo "Cannot continue!"
      echo "****** WARNING ******"
      echo "Aborting..."
      exit 1
     ;;
      "4")
      # Could not find a valid wasta-offline path at the $2 parameter location
      echo -e "\n****** WARNING ******"
      echo "No valid wasta-offline mirror found at: $COPYFROMDIR"
      echo "Cannot continue!"
      echo "****** WARNING ******"
      echo "Aborting..."
      exit 1
      ;;
      "5")
      echo -e "\n****** WARNING ******"
      echo "Programming Error: Invalid parameters."
      echo "The source and destination locations are one in the same!"
      echo "Cannot continue!"
      echo "****** WARNING ******"
      echo "Aborting..."
      exit 1
      ;;
      "6")
      echo -e "\n****** WARNING ******"
      echo "Programming Error: Invalid parateters given to the following function: "
      echo "   is_this_mirror_older_than_that_mirror ()..."
      echo "Cannot continue!"
      echo "****** WARNING ******"
      echo "Aborting..."
      exit 1
      ;;
      "7")
      echo "*******************************************************************************"
      echo "No Timestamp file found at destination, assuming the mirror there is older."
      # A mirror without our Timestamp is probably older mirror. Hence, an automatic default 
      # response to a mirror updating a mirror with no Timestamp probably should be "Yes".
      # so, have a 60 second countdown that auto selects 'y' at the end of the countdown, but if
      # a user is in attendance, the user can opt for 'n' by choice. 
      echo "Replace it with the mirror from the source location? [y/n] (default is 'y')"
      echo "*******************************************************************************"
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
            echo -e "\nUpdating the Wasta-Offline Mirror at: $COPYTODIR..."
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
    echo -e "\nCreating a NEW full Wasta-Offline Mirror at: $COPYTODIR..."
    # The main rsync command is called below
fi

# Ensure that there is an initial mirror directory structure at the destination (in case
# one doesn't exist yet)
mkdir -p $COPYTODIR
LASTERRORLEVEL=$?
if [ $LASTERRORLEVEL != 0 ]; then
  echo -e "\n****** WARNING ******"
  echo "Cannot create mirror directories at $COPYTODIR - is the Drive writeable?"
  echo "You might try rebooting the computer and running this script again."
  echo "****** WARNING ******"
  echo "Aborting..."
  exit $LASTERRORLEVEL
fi
# Ensure that the external <destination-mirror-path> exists and is writeable
if [ ! -d "$COPYTODIR" ]; then
  # $COPYTODIR doesn't exist so abort
  echo -e "\n****** WARNING ******"
  echo "The mirror directories at $COPYTODIR do not exist - is the Drive writeable?"
  echo "You might try rebooting the computer and running this script again."
  echo "****** WARNING ******"
  echo "Aborting..."
  exit 1
else
  echo -e "\nFound $COPYTODIR"
  # Calculate the COPYFROMBASEDIR and COPYTOBASEDIR paths. This should be calculated by
  # removing the wasta-offline dir from the end of the COPYFROMDIR and COPYTODIR paths
  COPYFROMBASEDIR=`dirname $COPYFROMDIR`
  COPYTOBASEDIR=`dirname $COPYTODIR`
  # See NOTEs below that explain what paths can be pointed to by $COPYFROMDIR and $COPYTODIR.
  echo -e "\nThe Source Base Directory is: $COPYFROMBASEDIR"
  echo "The Destination Base Directory is: $COPYTOBASEDIR"
  
  # Take care of any source and destination mirror ownership and permission issues at
  # the source and destination, in case they have changed.
  #
  # An apt-mirror's directory tree and content that is located on a Linux master mirror  
  # needs to be owned by apt-mirror for cron to work.
  # Make sure source mirror owner is apt-mirror:apt-mirror and everything in the mirror 
  # tree is read-write for everyone.
  # NOTE the following about the parameter passed to the set_mirror_ownership_and_permissions ()
  # function call below: 
  # When this sync_Wasta-Offline_to_Ext_Drive.sh is called DIRECTLY (routine updating):
  #   $COPYFROMBASEDIR - When this script is called directly, $COPYFROMBASEDIR will be the 
  #     path of the master mirror on a dedicated computer. This represents the routine invocation
  #     invocation of the 'sync_Wasta-Offline_to_Ext_Drive.sh' script, which is done 
  #     periodically to update/sync a portable external USB drive containing a full 
  #     Wasta-Offline mirror. The master mirror is the 'source' whose path is pointed to
  #     in $COPYFROMBASEDIR.
  # When this sync_Wasta-Offline_to_Ext_Drive.sh is called INDIRECTLY (at the end of 
  # the 'make_Master_for_Wasta-Offline.sh' script):
  #   $COPYFROMBASEDIR - When this script is called secondarily - near the end of the 
  #    'make_Master_for_Wasta-Offline.sh' script - the 'source' and 'destination' roles are
  #     reversed. The $COPYFROMBASEDIR 'source' will be the path of an external USB drive 
  #     containing a reasonably up-to-date full mirror. Generally an administrator would 
  #     make a one-time invocation of the 'make_Master_for_Wasta-Offline.sh' script (which
  #     in turn calls this script) to create a master Wasta-Offline mirror on a dedicated 
  #     computer. In this (rare) case the external USB drive is functioning as the 'source' 
  #     whose path is pointed to in $COPYFROMBASEDIR.
  # TODO: Make any necessary adjustments related to call of set_mirror_ownership_and_permissions () 
  # function below if 'source' mirror at $COPYFROMBASEDIR is a USB drive that is not Linux ext4 (ntfs).
  sleep 3s
  if set_mirror_ownership_and_permissions "$COPYFROMBASEDIR" ; then
    # All chown and chmod operations were successful
    echo -e "\nSet mirror ownership and permissions successfully at: $COPYFROMBASEDIR"
  else
    echo -e "\nNot all mirror ownership and permissions could be set at: $COPYFROMBASEDIR"
  fi

  # Before setting the destination's ownership and permissions, call the 
  # copy_mirror_base_dir_files () function, which uses rsync to copy all of
  # the necessary files from the source's base directory to the destination.
  # Parameters: # $COPYFROMBASEDIR (normally: /data/master) and $COPYTOBASEDIR (normally: /media/<DISK_LABEL>).
  # NOTE the following about the parameter passed to the copy_mirror_base_dir_files ()
  # function call below:
  # When this sync_Wasta-Offline_to_Ext_Drive.sh is called DIRECTLY (routine updating):
  #   $COPYFROMBASEDIR - When this script is called directly, $COPYFROMBASEDIR will be the 
  #     path of the master mirror on a dedicated computer. This represents the routine invocation
  #     invocation of the 'sync_Wasta-Offline_to_Ext_Drive.sh' script, which is done 
  #     periodically to update/sync a portable external USB drive containing a full 
  #     Wasta-Offline mirror. The master mirror is the 'source' whose path is pointed to
  #     in $COPYFROMBASEDIR.
  #   $COPYTOBASEDIR - When this script is called directly, $COPYTOBASEDIR will be the 
  #     path of an external USB drive containing an out-of-date full Wasta-Offline mirror
  #     that needs syncing from the master mirror to bring the mirror on the USB drive 
  #     up-to-date. This represents the routine invocation invocation of the 
  #     'sync_Wasta-Offline_to_Ext_Drive.sh' script, which is done periodically to 
  #     update/sync a portable external USB drive containing a full Wasta-Offline mirror. 
  #     The external USB drive is the 'destination' whose path is pointed to in
  #     $COPYFROMBASEDIR.
  # When this sync_Wasta-Offline_to_Ext_Drive.sh is called INDIRECTLY (at the end of 
  # the 'make_Master_for_Wasta-Offline.sh' script):
  #   $COPYFROMBASEDIR - When this script is called secondarily - near the end of the 
  #    'make_Master_for_Wasta-Offline.sh' script - the 'source' and 'destination' roles are
  #     reversed. The $COPYFROMBASEDIR 'source' will be the path of an external USB drive 
  #     containing a reasonably up-to-date full mirror. Generally an administrator would 
  #     make a one-time invocation of the 'make_Master_for_Wasta-Offline.sh' script (which
  #     in turn calls this script) to create a master Wasta-Offline mirror on a dedicated 
  #     computer. In this (rare) case the external USB drive is functioning as the 'source' 
  #     whose path is pointed to in $COPYFROMBASEDIR.
  #   $COPYTOBASEDIR - When this script is called secondarily - near the end of the 
  #    'make_Master_for_Wasta-Offline.sh' script - the 'source' and 'destination' roles are
  #     reversed. The $COPYTOBASEDIR 'destination' will be the path of an external USB drive 
  #     containing a reasonably up-to-date full mirror. Generally an administrator would
  #     make a one-time invocation of the 'make_Master_for_Wasta-Offline.sh' script (which
  #     in turn calls this script) to create a master Wasta-Offline mirror on a dedicated 
  #     computer. In this (rare) case the designated master mirror location is functioning 
  #     as the 'destination' whose path is pointed to in $COPYTOBASEDIR.
  # TODO: Make any necessary adjustments related to call of copy_mirror_base_dir_files () 
  # function below if 'destination' mirror at $COPYTOBASEDIR is a USB drive that is not Linux ext4 (ntfs).
  sleep 3s
  if copy_mirror_base_dir_files "$COPYFROMBASEDIR" "$COPYTOBASEDIR" ; then
    # All copy operations were successful
    echo -e "\nCopied source mirror's root directory files to destination mirror."
  else
    echo -e "\nNot all source mirror's root directory files could be copied!"
  fi

  # Make sure destination mirror owner is apt-mirror:apt-mirror and everything in the mirror
  # tree is read-write for everyone.
  # NOTE the following about the parameter passed to the set_mirror_ownership_and_permissions ()
  # function call below: 
  # When this sync_Wasta-Offline_to_Ext_Drive.sh is called DIRECTLY (routine updating):
  #   $COPYTOBASEDIR - When this script is called directly, $COPYTOBASEDIR will be the 
  #     path of an external USB drive containing an out-of-date full Wasta-Offline mirror
  #     that needs syncing from the master mirror to bring the mirror on the USB drive 
  #     up-to-date. This represents the routine invocation invocation of the 
  #     'sync_Wasta-Offline_to_Ext_Drive.sh' script, which is done periodically to 
  #     update/sync a portable external USB drive containing a full Wasta-Offline mirror. 
  #     The external USB drive is the 'destination' whose path is pointed to in
  #     $COPYFROMBASEDIR.
  # When this sync_Wasta-Offline_to_Ext_Drive.sh is called INDIRECTLY (at the end of 
  # the 'make_Master_for_Wasta-Offline.sh' script):
  #   $COPYTOBASEDIR - When this script is called secondarily - near the end of the 
  #    'make_Master_for_Wasta-Offline.sh' script - the 'source' and 'destination' roles are
  #     reversed. The $COPYTOBASEDIR 'destination' will be the path of an external USB drive 
  #     containing a reasonably up-to-date full mirror. Generally an administrator would
  #     make a one-time invocation of the 'make_Master_for_Wasta-Offline.sh' script (which
  #     in turn calls this script) to create a master Wasta-Offline mirror on a dedicated 
  #     computer. In this (rare) case the designated master mirror location is functioning 
  #     as the 'destination' whose path is pointed to in $COPYTOBASEDIR.
  # TODO: Make any necessary adjustments related to call of set_mirror_ownership_and_permissions () 
  # function below if 'destination' mirror at $COPYTOBASEDIR is a USB drive that is not Linux ext4 (ntfs).
  sleep 3s
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
# Sync the data from the 'source' mirror to the 'destination' mirror.
# See NOTE above for the copy_mirror_base_dir_files () function call describing
# what paths can be pointed to by $COPYFROMDIR and $COPYTODIR in the rsync call below.
# Note: The rsync call below should preserve all ownership and permissions
# from the source mirror's tree (set above) to the destination mirror's tree.
# whm 23 November 2018 Note: Use rsync -rvh --size-only --progress --delete /path/to/ext4/ /path/to/ntfs/
# to rsync between Ext4/Xfs and NTFS partitions.
echo -e "\n"
echo "*******************************************************************************"
echo "Synchronizinging data via the following rsync command:"
echo "rsync -avz --progress --delete $COPYFROMDIR $COPYTODIR"
echo "This may take a while - press CTRL-C anytime to abort..."
echo "*******************************************************************************"
sleep 3s
# Here is the main rsync command. The rsync options are:
#   -a archive mode (recurses thru dirs, preserves symlinks, permissions, times, group, owner)
#   -v verbose
#   -z compress file data during transfer
#   --progress show progress during transfer
#   --delete delete extraneous files from the destination dirs
# TODO: Adjust rsync command to use options: -rvh --size-only --progress
# if destination USB drive is not Linux ext4 (ntfs)
rsync -avz --progress --delete $COPYFROMDIR $COPYTODIR
############### The Main Sync Operation Happens Here ########################

LASTERRORLEVEL=$?
if [ $LASTERRORLEVEL != 0 ]; then
  echo -e "\n****** WARNING ******"
  echo "Could not rsync the mirror data to $COPYTODIR!"
  echo "****** WARNING ******"
  echo "Aborting..."
  return $LASTERRORLEVEL
fi

# Flush the file system copy buffers
sync

echo -e "\nThe $SYNCWASTAOFFLINESCRIPT script has finished."

