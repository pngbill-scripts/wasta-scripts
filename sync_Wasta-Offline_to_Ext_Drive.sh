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
#      Used a new get_file_system_type_of_partition () function to determine
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
#  11. Synchronizes/Copies all of the source mirror's "root" directory files to the
#      destination's "root" directory, by calling the copy_mirror_base_dir_files ()
#      function with "$COPYFROMBASEDIR" "$COPYTOBASEDIR" parameters.
#      The "root" directory here refers to the 
#      directory of the device or drive where the mirror begins. For example, the
#      "root" directory of Bill's master copy is on a partition mounted at /data/master,
#      and the "root" directory of an attached USB Wasta-Offline Mirror - as 
#      supplied by Bill Martin - is at /media/$USER/<DISK_LABEL>. 
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
#      and sets the destination mirror's content permissions to a+rwX (read-write 
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
. "$DIR/bash_functions.sh" # $DIR is the path prefix to bash_functions.sh as well as to the current script

# ------------------------------------------------------------------------------
# Set up some script variables
# ------------------------------------------------------------------------------
SCRIPTVERSION="0.2"
WASTAOFFLINEPKGURL="http://ppa.launchpad.net/wasta-linux/wasta-apps/ubuntu/pool/main/w/wasta-offline"
DATADIR="/data"
MASTERDIR="/master"
APTMIRROR="apt-mirror"
BILLSWASTADOCS="bills-wasta-docs"
BILLSWASTADOCSDIR="/$BILLSWASTADOCS"
WASTAOFFLINEDIR="/wasta-offline"
APTMIRRORDIR="/apt-mirror"
APTMIRRORSETUPDIR="/apt-mirror-setup"
MIRRORDIR="/mirror"
BASH_FUNCTIONS_SCRIPT="bash_functions.sh"
UPDATEMIRRORSCRIPT="update-mirror.sh"
SYNCWASTAOFFLINESCRIPT="sync_Wasta-Offline_to_Ext_Drive.sh"
MAKE_MASTER_SCRIPT="make_Master_for_Wasta-Offline.sh"
POSTMIRRORSCRIPT="postmirror.sh"
POSTMIRROR2SCRIPT="postmirror2.sh"

# See NOTEs later in this script that explain what paths can be pointed to by $COPYFROMDIR and $COPYTODIR.
WAIT=60
start=`date +%s` # keep track of run-time of script

echo -e "\n[*** Now executing the $SYNCWASTAOFFLINESCRIPT script ***]"
sleep 3s

# ------------------------------------------------------------------------------
# Main program starts here
# ------------------------------------------------------------------------------

COPYFROMDIR=$DATADIR$MASTERDIR$WASTAOFFLINEDIR"/"  # /data/master/wasta-offline/ is the default source dir
# Use the get_wasta_offline_usb_mount_point () function to get an initial value for USBMOUNTPOINT
# to fill in the "Directory to sync to is: " field echoed to console below
USBMOUNTPOINT=`get_wasta_offline_usb_mount_point`  # normally USBMOUNTPOINT is /media/$USER/<DISK_LABEL>/wasta-offline
if [ "x$USBMOUNTPOINT" = "x" ]; then
  COPYTODIR="UNKNOWN"
  # See the other actions taken after the case statement below, when COPYTODIR is "UNKNOWN".
else
  COPYTODIR=$USBMOUNTPOINT
fi

#echo -e "\nNumber of parameters: $#"
#echo -e "\nThe SUDO_USER is: $SUDO_USER"
sleep 3s
case $# in
    0) 
      echo -e "\nThis $SYNCWASTAOFFLINESCRIPT script invoked without any parameters:"
      echo "  Directory to sync from is: $COPYFROMDIR (default)"
      if [[ "$COPYTODIR" == "UNKNOWN" ]]; then
        echo "  Directory to sync to is:   $COPYTODIR"
      else
        echo "  Directory to sync to is:   $COPYTODIR (default)"
      fi
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
    *)
      echo -e "\nUnrecognized parameters used with script."
      echo "Usage:"
      echo "$SYNCWASTAOFFLINESCRIPT [<source-dir-path>] [<destination-dir-path>]"
      exit 1
        ;;
esac

if [[ "$COPYTODIR" = "UNKNOWN" ]]; then
  # $USBMOUNTPOINT for a USB drive containing a wasta-offline subfolder was not found
  COPYTODIR=""
  USBMOUNTPOINT=""
  USBMOUNTDFIR=""
  USBDEVICENAME=""
  USBFILESYSTEMTYPE=""
  # The $USBMOUNTPOINT variable is empty, i.e., a wasta-offline subdirectory on /media/... was not found
  echo -e "\nWasta-Offline data was NOT found at /media/..."
  #sleep 3s
  
  # Check if there is one or more USB drive(a) mounted that have no wasta-offline subfolder yet, 
  # and that might be available/intended for use in creating a new USB full Wasta-Offline Mirror.
  
  # First, get list of 'removable' drives - drives that are "usb" block devices
  # The REMOVABLE_DRIVES var will contain just the device name(s) in a single string, for example: "sde sdf"
  total=0
  REMOVABLE_DRIVES=""
  for _device in /sys/block/*/device; do
    if echo $(readlink -f "$_device") | egrep -q "usb"; then # egrep -q "usb" returns 0 (success) if "usb" is in the readlink -f output of "$_device"
        _disk=$(echo "$_device" | cut -f4 -d/) # gets 4th '/' path element of $_device, for example, for /sys/block/sde/device cuts out "sde"
        REMOVABLE_DRIVES="$REMOVABLE_DRIVES $_disk"
        let total=total+1
    fi
  done
  
  # If at least one USB drive/partition was found prompt user to select one
  if [ "$total" -gt "0" ]; then
    # get partition(s) and mount points paired with above device names
    #echo "Removable USB drive devices found: $REMOVABLE_DRIVES"
    echo -e "\nFound potential USB Drive(s) for creating a new wasta-offline mirror..."
    echo "Select a USB partition NUMBER from this list to create a new mirror:"
    #sleep 1s
    echo "NUMBER PARTITION TYPE MOUNTPOINT"
    itemnum=0
    total=0
    USBMOUNTPTARRAY=() # Create an empty array for mount points
    # display partitions and mount points paired with above removable drive names
    for devname in $REMOVABLE_DRIVES; do
      # Note: Use sed in lsblk command to replace any \x20 chars with spaces in the MOUNTPOINT output
      # before grep does its matching and the value is stored in $USBMOUNTPTARRAY.
      #USBMOUNTPTARRAY[itemnum]=$(lsblk -o NAME,FSTYPE,MOUNTPOINT -pr | sed 's/\\x20/ /g' | grep "/media" | grep $devname | cut -f3 -d" ")
      # Note: Can't do '| cut -f3 -d" "' to get MOUNTPOINT that has embedded space(s), so get the raw line first:
      TEMP_MEDIA_LINE=$(lsblk -o NAME,FSTYPE,MOUNTPOINT -pr | sed 's/\\x20/ /g' | grep "/media" | grep $devname)
      MEDIA="/media/"
      # Use bash parameter expansion to get the part /media/... to the end of the line
      USBMOUNTPTARRAY[itemnum]=$MEDIA${TEMP_MEDIA_LINE##*$MEDIA}
      #echo "TEMP_MEDIA_LINE is: $TEMP_MEDIA_LINE"
      #echo "Item $itemnum ${USBMOUNTPTARRAY[itemnum]}"
      let itemnum=itemnum+1
      printf "  $itemnum)   $TEMP_MEDIA_LINE \n"
      let total=total+1
    done  

    for (( i=$WAIT; i>0; i--)); do
      printf "\rType the NUMBER of the USB drive to use, or hit any key to abort - countdown $i "
      read -s -n 1 -t 1 SELECTION
      if [ $? -eq 0 ]; then
        break
      fi
    done
    if [[ ! $SELECTION ]] || [[ "$SELECTION" > "$total" ]] || [[ "$SELECTION" < "1" ]]; then
      echo -e "\n"
      echo "You typed $SELECTION"
      echo "*********************** WARNING *****************************************"
      echo "Unrecognized selection made, or no reponse within $WAIT seconds."
      echo "Please connect a USB drive to receive wasta-offline mirror data/updates, or"
      echo "Alternately, connect an empty USB drive that meets these qualifications:"
      echo "  Is large enough to contain the full wasta-offline mirror (at least 1TB)"
      echo "Then, run this script again."
      echo "********************** WARNING ******************************************"
      echo "Aborting..."
      exit 1
    fi
    # If we get this far, the user has typed a valid selection
    echo -e "\n"
    echo "Your choice was $SELECTION"
    # Set a value for the $USBMOUNTDIR and $USBMOUNTPOINT variable corresponding to
    # the newly selected USB drive selected.
    USBMOUNTDIR=${USBMOUNTPTARRAY[((SELECTION - 1))]} # adjust SELECTION value to zero index value
    USBMOUNTPOINT=$USBMOUNTDIR$WASTAOFFLINEDIR
    echo -e "\nCreating initial wasta-offline tree at: $USBMOUNTPOINT"
    mkdir -p "$USBMOUNTPOINT"
    LASTERRORLEVEL=$?
    if [ $LASTERRORLEVEL != 0 ]; then
      echo -e "\n****** WARNING ******"
      echo "Cannot create mirror directories at $USBMOUNTPOINT - is the Drive writeable?"
      echo "You might try rebooting the computer and running this script again."
      echo "****** WARNING ******"
      echo "Aborting..."
      exit $LASTERRORLEVEL
    fi
    # COPYTODIR needs to be set to the newly selected $USBMOUNTPOINT value
    COPYTODIR=$USBMOUNTPOINT  # /media/$USER/<DISK_LABEL>/wasta-offline
    #echo -e "\nWasta-Offline data was found at: $USBMOUNTPOINT"
  else
    # No USB drive available to create mirror, so warn and abort
    echo -e "\n****** WARNING ******"
    echo "No USB drive found to update or create a wasta-offline mirror."
    echo "Please plug in a suitable USB drive and try running this script again."
    echo "****** WARNING ******"
    echo "Aborting..."
    exit 1  
  fi
else
  # The $USBMOUNTPOINT was initially determined - not an empty string
  # The USBMOUNTDIR value should be the path up to, but not including /wasta-offline of $USBMOUNTPOINT
  USBMOUNTDIR=$USBMOUNTPOINT
  if [[ "$USBMOUNTPOINT" == *"wasta-offline"* ]]; then 
    USBMOUNTDIR=$(dirname "$USBMOUNTPOINT")
  fi
  # COPYTODIR needs to be set to the detected $USBMOUNTPOINT value
  COPYTODIR=$USBMOUNTPOINT  # /media/$USER/<DISK_LABEL>/wasta-offline
  #echo -e "\nWasta-Offline data was found at: $USBMOUNTPOINT"
fi

# Use the get_device_name_of_usb_mount_point () function with $USBMOUNTDIR parameter to get USBDEVICENAME
USBDEVICENAME=`get_device_name_of_usb_mount_point "$USBMOUNTDIR"`
# Use the get_file_system_type_of_partition () function with $USBMOUNTDIR parameter to get USBFILESYSTEMTYPE
USBFILESYSTEMTYPE=`get_file_system_type_of_partition "$USBMOUNTDIR"`
echo -e "\nThe USB drive mount point is: $USBMOUNTPOINT"
#echo "Debug: The USBMOUNTDIR from USBMOUNTPOINT is: $USBMOUNTDIR"
#echo "Debug: USBDEVICENAME of USB at USBMOUNTDIR is: $USBDEVICENAME"
#echo "Debug: File system TYPE of USB Drive: $USBFILESYSTEMTYPE"

# Check that there is a wasta-offline mirror at the source location. If not there is no
# sync operation that we can do.
sleep 3s
echo -e "\nChecking for a source mirror..."
if is_there_a_wasta_offline_mirror_at "$COPYFROMDIR" ; then
  # There is already a wasta-offline mirror at $COPYFROMDIR
  echo -e "\n  Found a source mirror at: $COPYFROMDIR"
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
    echo -e "\n  Found a destination mirror at: $COPYTODIR"
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
      echo "No Time stamp file found at destination, assuming the mirror there is older."
      # A mirror without our Timestamp is probably older mirror. Hence, an automatic default 
      # response to a mirror updating a mirror with no Time stamp probably should be "Yes".
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
    echo -e "\n  No existing mirror found at: $COPYTODIR"
    # We can proceed with the copy process - same as the 'y' (YES) case above.
    echo -e "\nCreating a NEW Wasta-Offline Mirror at: $COPYTODIR..."
    # The main rsync command is called below
fi

# Ensure that there is an initial mirror directory structure at the destination (in case
# one doesn't exist yet)
mkdir -p "$COPYTODIR"
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
  #echo -e "\nFound $COPYTODIR"
  # Calculate the COPYFROMBASEDIR and COPYTOBASEDIR paths. This should be calculated by
  # removing the wasta-offline dir from the end of the COPYFROMDIR and COPYTODIR paths
  COPYFROMBASEDIR=`dirname "$COPYFROMDIR"`
  COPYTOBASEDIR=`dirname "$COPYTODIR"`
  RSYNC_OPTIONS_1=$(get_rsync_options "$COPYFROMBASEDIR") 
  RSYNC_OPTIONS_2=$(get_rsync_options "$COPYTOBASEDIR")
  USBFSTYPE_1=$(get_file_system_type_of_partition "$COPYFROMBASEDIR")
  USBFSTYPE_2=$(get_file_system_type_of_partition "$COPYTOBASEDIR")
  #echo "  Debug: RSYNC_OPTIONS_1 for $COPYFROMBASEDIR are [$RSYNC_OPTIONS_1] [$USBFSTYPE_1]"
  #echo "  Debug: RSYNC_OPTIONS_2 for $COPYTOBASEDIR are [$RSYNC_OPTIONS_2] [$USBFSTYPE_2]"

  # See NOTEs below that explain what paths can be pointed to by $COPYFROMDIR and $COPYTODIR.
  echo "  The Source Base Directory is: $COPYFROMBASEDIR [$USBFSTYPE_1]"
  echo "  The Destination Base Directory is: $COPYTOBASEDIR [$USBFSTYPE_2]"
  
  # whm 5Jan2019 removed the set_mirror_ownership_and_permissions () function call on the
  # 'source' $COPYFROMBASEDIR below. This should not be needed since when this sync_... script
  # is called indirectly by the make_Master_for_Wasta-Offline.sh script, that calling
  # script should not attempt to set mirror ownership and permissions for the 'source' - 
  # the USB drive's mirror - which might be formatted as ntfs. And, when this sync_... 
  # script is called directly to update a destination USB drive's mirror from a master 
  # mirror, the master mirror is the 'source' and its ownership and permissions should
  # have been set by the make_Master_for_Wasta-Offline.sh script when the master mirror
  # was initially created, and I think the postmirror.sh script ensures the ownership 
  # and permissions of downloaded data files are set appropriately each time cron calls 
  # apt-mirror.
  #
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
  #sleep 3s
  #echo -e "\nSetting source mirror ownership and permissions at $COPYFROMBASEDIR..."
  #if set_mirror_ownership_and_permissions "$COPYFROMBASEDIR" ; then
  #  # All chown and chmod operations were successful
  #  echo -e "\n  Mirror ownership and permissions set successfully at: $COPYFROMBASEDIR."
  #else
  #  echo -e "\nNot all mirror ownership and permissions could be set at: $COPYFROMBASEDIR."
  #fi

  # Before setting the destination's ownership and permissions, call the 
  # copy_mirror_base_dir_files () function, which uses rsync to copy all of
  # the necessary files from the source's base directory to the destination.
  # Parameters: # $COPYFROMBASEDIR (normally: /data/master) and $COPYTOBASEDIR (normally: /media/<DISK_LABEL>).
  # NOTE the following about the parameters passed to the copy_mirror_base_dir_files ()
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
  #     reversed. The $COPYTOBASEDIR 'destination' will be the path of the master mirror
  #     on a dedicated computer. Generally an administrator would make a one-time invocation 
  #     of the 'make_Master_for_Wasta-Offline.sh' script (which in turn calls this script) 
  #     to create a master Wasta-Offline mirror on a dedicated computer. In this (rare or
  #     specialized) case the designated master mirror location is functioning as the 
  #     'destination' whose path is pointed to in $COPYTOBASEDIR.
  # Note: The copy_mirror_base_dir_files () function call below internally determines the
  # USB file system type of the path at $COPYTOBASEDIR, and adjusts the options it uses
  # on its calls of rsync accordingly applying different options to the rsync command so 
  # that it avoids attempting to preserve ownership/permissions in the copy/sync process
  # when the destination is a non-Linux USB drive.
  
  sleep 3s
  echo -e "\nCopying mirror root files from $COPYFROMBASEDIR to $COPYTOBASEDIR..."
  if copy_mirror_base_dir_files "$COPYFROMBASEDIR" "$COPYTOBASEDIR" ; then
    # All copy operations were successful
    echo -e "\n  Source mirror's root directory files copied to destination mirror."
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
  #     reversed. The $COPYTOBASEDIR 'destination' will be the path of the master mirror
  #     on a dedicated computer. Generally an administrator would make a one-time invocation 
  #     of the 'make_Master_for_Wasta-Offline.sh' script (which in turn calls this script) 
  #     to create a master Wasta-Offline mirror on a dedicated computer. In this (rare or
  #     specialized) case the designated master mirror location is functioning as the 
  #     'destination' whose path is pointed to in $COPYTOBASEDIR.
  # Note: If $USBFSTYPE_2 (2nd parameter) in the function call below is "ntfs" or "vfat"
  # and $COPYTOBASEDIR starts with '/media/' the set_mirror_ownership_and_permissions () 
  # function does nothing - no ownership/permissions are set.
  sleep 3s
  echo -e "\nSetting destination mirror ownership and permissions at $COPYTOBASEDIR..."
  echo "... Please wait"
  if set_mirror_ownership_and_permissions "$COPYTOBASEDIR" "$USBFSTYPE_2" ; then
    # All chown and chmod operations were successful, or skipped if "ntfs" or "vfat"
    if [[ "$USBFSTYPE_2" == "ntfs" ]] || [[ "$USBFSTYPE_2" == "vfat" ]]; then
      echo "  Destination format is $USBFSTYPE_2 - no ownership/permissions were set."
    else
      echo -e "\n  Mirror ownership and permissions set successfully at: $COPYTOBASEDIR."
    fi
  else
    # Notify user of ERROR but don't halt the rest of the script for this error
    echo -e "\nERROR: NOT ALL OWNERSHIP/PERMISSIONS WERE SET AT: $COPYTOBASEDIR."
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

# Determine the rsync options to use.
# Use the bash function get_rsync_options () to determine the correct rsync options:
# If the destination's path root dir is "/media", and if its file system type 
# is "ntfs" or "vfat", set rsync options to "-rvh --size-only" to avoid
# messing with ownership/permissions on a Windows format drive, otherwise use the
# default rsync options of "-avh --update" for a Linux format drive.
# For this main sync operation use the "--progress" option in addition to the
# main RSYNC_OPTIONS.
# The get_rsync_options () function needs a $USBMOUNTDIR as input parameter, so get 
# it from $COPYTODIR:
if [[ "$COPYTODIR" == *"wasta-offline"* ]]; then 
  USBMOUNTDIR=$(dirname "$COPYTODIR")
fi

############### The Main Sync Operation Happens Below Here ########################
# Sync the data from the 'source' mirror to the 'destination' mirror.
# See NOTE above for the copy_mirror_base_dir_files () function call describing
# what paths can be pointed to by $COPYFROMDIR and $COPYTODIR in the rsync call below.
# Note: The rsync call below does not attempt to preserve all ownership and permissions
# when syncing from the source mirror's tree (set above) to the destination mirror's 
# tree when the destination is a "ntfs" or "vfat" format file system.
# See the get_rsync_options () function in bash_functions.sh for more info.
echo " "
echo "*******************************************************************************"
echo "Synchronizinging data via the following rsync command:"
echo "rsync $RSYNC_OPTIONS_2 --progress --delete <Sync From Path> <Sync To Path>"
echo "  Sync From Path is: $COPYFROMDIR [$USBFSTYPE_1]"
echo "  Sync To Path is: $COPYTODIR [$USBFSTYPE_2]"
echo "  Destination drive is $USBFSTYPE_2 file system."
echo "Expect a lot of screen output during Sync operation."
echo "This may take a while - press CTRL-C anytime to abort..."
echo "*******************************************************************************"
echo ""
sleep 5s
# Here is the main rsync command. The rsync options differ depending on the
# value of $RSYNC_OPTIONS_2 and if the destination $COPYTODIR path has "/media/...
# The --progress option is always used here for the main sync operation, but in other
# places (copying *.sh *.deb, bills-wasta-docs, etc) the -q (quiet) options is used 
# in place of --progress.
# When $RSYNC_OPTIONS_2 is "ntfs" or "vfat" and destination is /media/... the rsync options are:
#   -r recurses through directories
#   -v verbose
#   -h output numbers in a human-readable format
#   --size-only skip files that match in size
#   --delete  delete extraneous files from the destination dirs
#   --progress  show progress during transfer
# When $RSYNC_OPTIONS_2 is other than "ntfs"/"vfat" or destination is other than /media/... the rsync options are:
#   -a archive mode (recurses thru dirs, preserves symlinks, permissions, times, group, owner)
#   -v verbose
#   -h output numbers in a human-readable format
#   --delete  delete extraneous files from the destination dirs
#   --progress  show progress during transfer
#
rsync $RSYNC_OPTIONS_2 --progress --delete "$COPYFROMDIR" "$COPYTODIR"
############### The Main Sync Operation Happens Above Here ########################

LASTERRORLEVEL=$?
if [ $LASTERRORLEVEL != 0 ]; then
  echo -e "\n****** WARNING ******"
  echo "Could not rsync the mirror data to $COPYTODIR!"
  echo "****** WARNING ******"
  echo "Aborting..."
  exit $LASTERRORLEVEL
fi

# Flush the file system copy buffers
sync

echo -e "\nThe $SYNCWASTAOFFLINESCRIPT script has finished."
echo "Script running time: $((($(date +%s)-$start)/60)) minutes"

