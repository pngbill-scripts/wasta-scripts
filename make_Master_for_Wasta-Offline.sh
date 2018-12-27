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
#   - 23 November 2018 Did a major revision to make the script more generalized.
#      Did a general cleanup of the script and comments.
#      Moved script variables to a section after superuser setup.
#      Removed the hard coded "LM-UPDATES" disk label. USB drive can now have 
#      any label.
#      Removed the "PREP_NEW_USB" parameter option which was unused.
#      Streamlined the detection of the USB drive's mount point using echoed 
#      output from the new get_wasta_offline_usb_mount_point () function.
#      Used a new get_device_name_of_usb_mount_point () function to determine
#      the device name of the USB drive's mount point.
#      Used a new get_file_system_type_of_usb_partition () function to determine
#      the file system type of the USB drive at the mount point.
#      Added sleep statements to paus output for better monitoring of progress.
#      Made Abort warnings more visible in console output.
#      Removed 'export' from all variables - not needed for variable visibility.
# Name: make_Master_for_Wasta-Offline.sh
# Distribution: 
# This script is included with all Wasta-Offline Mirrors supplied by Bill Martin.
# If you make changes to this script to improve it or correct errors, please send
# your updated script to Bill Martin bill_martin@sil.org
# The scripts are maintained on GitHub at:
# https://github.com/pngbill-scripts/wasta-scripts
#
# Purpose: 
# The primary purpose of this script is to create a Master copy of the full 
# Wasta-Offline Mirror on a dedicated local computer - copying the mirror data from
# a full Wasta-Offline Mirror located on a USB external drive, to a default location
# of /data/master/wasta-offline/ on the fixed hard drive of a computer that becomes
# the "master mirror". Executing this script need only be done once on a given
# computer to extablish it as a dedicated computer for maintaining the "master mirror."

# NOTE: These Wasta-Offline scripts are for use by administrators and not normal
# Wasta-Linux users. The Wasta-Offline program itself need not be running when you, 
# as administrator are running these scripts. Hence, when you plug in a USB drive 
# containing the full Wasta-Offline Mirror - intending to create a master mirror with 
# this make_Master_for_Wasta-Offline.sh script - and the Authentication/Password message 
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
# What should be done after running this script:
# 
# Once this script has created a master copy of the full Wasta-Offline mirror, 
# this make_Master_for_Wasta-Offline.sh script need not be called again. Instead, 
# the master copy of the mirror should be kept up to date by periodically running  
# the apt-mirror program. Before the script exits, it informs the user that keeping 
# the master mirror updated can be done by calling the update-mirror.sh script
# manually, or for automated updates on a regular schedule, the user can enable the 
# cron job provided during the installation of apt-mirror, by a simple edit of one  
# line in the /etc/cron.d/apt-mirror file.
# Once the master mirror is updated, one or more external USB hard drives can be 
# kept synchronized with the master copy by plugging the USB hard drive in, and
# manually calling the sync_Wasta-Offline_to_Ext_Drive.sh script directly.

# This make_Master_for_Wasta-Offline.sh script does the following:
#   1. Runs the script as root (asks for password).
#   2. Checks if the sync_Wasta-Offline_to_Ext_Drive.sh script is available in the
#      same directory and has execute permissions. If not, script warns and aborts.
#   3. Sets some initial defaults path values for the Wasta-Offline 'source' path
#      and the path for the 'destination' master mirror. A default path for the
#      'source' mirror is obtained by calling the 'get_a_default_path_for_COPYFROMDIR ()'
#      function. A default path for the 'destination' mirror is obtained by calling
#      the 'get_a_default_path_for_COPYTODIR ()' function. 
#   4. Checks if a USB drive is plugged in/mounted and that it has a full Wasta-Offline
#      mirror on it available for copying/syncing to a master mirror. If not script
#      warns and aborts.
#   5. Examines any parameters that were passed to the script and acts accordingly.
#      If no parameters are present, this script assumes there is a USB drive already
#         plugged into the computer at the $COPYFROMDIR path that contains a full 
#         wasta-offline mirror present on it, and that a master mirror should be 
#         created on a fixed disk partition at the $COPYTODIR path, which defaults
#         to a path of: /data/master/wasta-offline/. If the $COPYFROMDIR and 
#         $COPYTODIR point to the same identical path (the USB drive), the $COPYTODIR
#         path is changed to a default of /data/master/wasta-offline.
#      If one parameter is present, it can be used to force the script to create
#        the master copy at a different destination path than the default path for
#        the master mirror being created which is: /data/master/wasta-offline/.
#        If the passed-in parameter for $COPYTODIR is the same path as the USB drive
#        a warning is given and the script aborts.
#      If two parameters are present they become the source and destination mirror
#        paths respectively ($1 is $COPYFROMDIR path and $2 is $COPYTODIR path).
#      Note: The $COPYFROMDIR and $COPYTODIR paths cannot point to the same path
#      location, and they must be absolute paths to the wasta-offline directories 
#      that contain the apt-mirror generated mirrors (i.e., both source and 
#      destination paths should point to the "wasta-offline" directories of their 
#      respective mirror trees). If the passed-in parameters for $COPYFROMDIR and
#      $COPYTODIR point to the same identical path a warning is given and the 
#      script aborts.
#   6. Checks for a mounted USB drive containing a full wasta-offline source data 
#      tree. If no USB drive is found with a full mirror on it, a warning is given
#      and the script aborts.
#   7. Gathers more information about the 'source' USB drive and the 'destination'
#      master mirror location, and checks that the $COPYTODIR's base dir has enough 
#      space for syncing the full master mirror from the USB drive. If the disk space 
#      used by the USB drive's data > space available, a warning is given and the 
#      script aborts.
#   8. Generate/Update the computer's /etc/apt/mirror.list file with the base_path
#      determined from the $COPYTODIR value. The mirror.list file is generated by
#      calling the 'generate_mirror_list_file ()' function passing the parameter
#      $UkarumpaURLPrefix which is "http://linuxrepo.sil.org.pg/mirror/". If the
#      mirror.list file can't be generated a warning is given and the script aborts.
#   9. Makes sure there is an apt-mirror group on the user's computer and adds the 
#      non-root user ($SUDO_USER) to the apt-mirror group.
#  10. Finally, this script calls the 'sync_Wasta-Offline_to_Ext_Drive.sh' script, 
#      passing on the $COPYFROMDIR and $COPYTODIR parameters to that script. The
#      were given in calling this script. The main copy/sync work of creating the
#      master mirror is done by the called 'sync_Wasta-Offline_to_Ext_Drive.sh' script.
#   NOTE: The most up-to-date Wasta-Offline USB drive that is available should be 
#    used when creating the master copy on the local computer, so that subsequent 
#    updates to the master copy of the mirror (by calling the updata-mirror.sh script) 
#    can be done quickly and easily.
# Usage:
#   bash make_Master_for_Wasta-Offline.sh  or
#   bash make_Master_for_Wasta-Offline.sh [<destination-mirror>]  or
#   bash make_Master_for_Wasta-Offline.sh [<source-mirror>] [<destination-mirror>]
#   Both parameters are optional.
#   If no parameters are present, this script assumes there is a USB drive already
#     plugged into the computer containing a full wasta-offline mirror present on it,
#     and that a master mirror should be created on a fixed disk partition at a
#     default destination of: /data/master/wasta-offline/, and that destination
#     location should have at least 1TB of capacity.
#   If only one parameter is present, it must represent the destination path of the
#     master mirror. The single parameter can be used to force the script to create
#     the master copy at a different destination path than the default path for
#     the master mirror (when no parameters are used). The path passed in the single
#     parameter should have at least 1TB of capacity. In this case the script assumes
#     that the source mirror data is to be found on an external USB drive that
#     has already been plugged in and contains the source full mirror that will be
#     used to create the master mirror.
#   If two parameters are present they become the source and destination mirror
#     paths respectively. In this case (two parameters), the first parameter points
#     to the source USB drive containing the full mirror data to be copied/synced
#     from; the second parameter points to the destination path for the master mirror, 
#     which should have at least 1TB of capacity.
#   Notes: 
#   1) The $COPYFROMDIR and $COPYTODIR paths must be absolute paths to the 
#      wasta-offline directories that contain the apt-mirror mirrors (i.e.,
#      both source and destination paths should point to the "wasta-offline" 
#      directories of their respective mirror trees). For example,
#      Parameter 1 (the $COPYFROMDIR) might be: /media/bill/UPDATES/wasta-offline
#      Parameter 2 (the $COPYTODIR) might be: /data/master/wasta-offline
#      Note: The wasta-offline directory should be at the 3rd level deep in the
#      absolute path, and it is recommended that 'master' be used as the 2nd level
#      in the absolute path to the master mirror, i.e., ../master/wasta-offline.
#   2) The master mirror should be a partition of at least 1TB is size to
#      hold the full master mirror. A 2TB partition would be better since the
#      full mirror data continually grows larger with time.
#   3) The master mirror partition should be formatted as an Ext4 Linux partition,
#      as a Linux partition makes it possible for the master mirror tree to have 
#      special ownership and permissions. 
#   4) Once the master mirror is established on the computer dedicated for
#      maintaining/updating the master mirror, a different script called
#      'sync_Wasta-Offline_to_Ext_Drive.sh', can then be used to easily and
#      regularly sync multiple USB drives containing the full mirror, one at 
#j     a time - keeping a number of USB drives up-to-date with the master mirror
#      - as they circulate back from the regions for updating.
#   5) The arsenal of 1TB or larger USB drives being used to contain the full 
#      mirrors, currently must be formatted as a Linux Ext4 filesystem.
#      If requested, a future revision may make it possible to have the USB
#      drive partitions formatted as an NTFS filesystem.
#   Requires sudo/root privileges - password requested at run-time.

# Note when set -e is uncommented, script stops immediately and no error 
# codes are returned in "$?"
#set -e

# The following block to run with superuser permissions is needed here, otherwise
# make_Master_for_Wasta-Offline.sh doesn't show a terminal window for error interaction.
# The similar block in sync_Wasta-Offline_to_Ext_Drive.sh (called at the end of this 
# script) will be skipped.
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
# Set up some script variables and default source and destination variables
# ------------------------------------------------------------------------------
SCRIPTVERSION="0.2"
DATADIR="/data"
MASTERDIR="/master"
WASTAOFFLINE="wasta-offline"
WASTAOFFLINEDIR="/wasta-offline"
APTMIRROR="apt-mirror"
APTMIRRORDIR="/apt-mirror"
APTMIRRORSETUPDIR="/apt-mirror-setup"
MIRRORDIR="/mirror"
SYNCWASTAOFFLINESCRIPT="sync_Wasta-Offline_to_Ext_Drive.sh"
MAKEMASTERCOPYSCRIPT="make_Master_for_Wasta-Offline.sh"
WAIT=60
USBDEVICENAME=""
USBFILESYSTEMTYPE=""
SOURCESLIST="sources.list"
ETCAPT="/etc/apt/"
InternetURLPrefix="http://"
UkarumpaURLPrefix="http://linuxrepo.sil.org.pg/mirror/"
FTPURLPrefix="ftp://"
FileURLPrefix="file:"

# The following variables are defined just before the generate... function call below.
#GENERATEDSIGNATURE="###_This_file_was_generated_by_the_update-mirror.sh_script_###"
#LOCALMIRRORSPATH=$COPYTODIR$APTMIRRORDIR # default to /data/master/wasta-offline/apt-mirror
#ETCAPT="/etc/apt/"
#MIRRORLIST="mirror.list"
#MIRRORLISTPATH=$ETCAPT$MIRRORLIST # /etc/apt/mirror.list
#SAVEEXT=".save" # used in generate_mirror_list_file () function

echo -e "\n[*** Now executing the $MAKEMASTERCOPYSCRIPT script ***]"
sleep 3s

# ------------------------------------------------------------------------------
# Main program starts here
# ------------------------------------------------------------------------------
# This script calls the sync_Wasta-Offline_to_Ext_Drive.sh script to do its work,
# passing the appropriate parameters to the sync_Wasta-Offline_to_Ext_Drive.sh script.
# The parameters that are passed on to sync_Wasta-Offline_to_Ext_Drive.sh are 
# determined by what parameters are given to this make_Master_for_Wasta-Offline.sh
# script at invocation. Any parameters given to this make_Master_for_Wasta-Offline.sh
# script will override default values for $COPYFROMDIR and $COPYTODIR.

# First, check that the sync_Wasta-Offline_to_Ext_Drive.sh script is available in the
# same directory and has execute permissions.
echo -e "\nThis script calls the $SYNCWASTAOFFLINESCRIPT script to create"
echo "   a master Wasta-Offline mirror."
echo "Checking for the presence of the $SYNCWASTAOFFLINESCRIPT script..."
sleep 2s
if [ -x $DIR/$SYNCWASTAOFFLINESCRIPT ]; then
  echo "Script $DIR/$SYNCWASTAOFFLINESCRIPT exists, is executable."
else
  echo -e "\n****** WARNING ******"
  echo "Cannot find the $DIR/$SYNCWASTAOFFLINESCRIPT script"
  echo "This script requires that $SYNCWASTAOFFLINESCRIPT be available."
  echo "****** WARNING ******"
  echo "Aborting..."
  exit 1
fi

# Set some initial defaults for USBMOUNTPOINT and BASEPATH_TO_MIRROR.

# Get the USBMOUNTPOINT of the external USB drive's mirror. 
# USBMOUNTPOINT can be an empty string if no USB drive is attached/mounted, or an mounted USB
# drive has no wasta-offline tree on it.
USBMOUNTPOINT=`get_wasta_offline_usb_mount_point` 

# Get the BASEPATH_TO_MIRROR if a mirror.list file exists.
# most likely /data/master/wasta-offline/apt-mirror, if it exists, or it will be an 
# empty string if the mirror.list file doesn't exist.
BASEPATH_TO_MIRROR=`get_base_path_of_mirror_list_file` 
# We'll sync to the wasta-offline directory (one level higher up), so remove /apt-mirror dir part.
BASEPATH_TO_MIRROR=`dirname $BASEPATH_TO_MIRROR` # /data/master/wasta-offline

# Set some defaults for COPYFROMDIR and COPYTODIR, which may be overridden by parameters
# given when invoking this script (see below).

# What source mirror are we using? Get a default value for COPYFROMDIR.
# Assume that a Full Wasta-Offline Mirror on USB drive is plugged in.
# Use the get_a_default_path_for_COPYFROMDIR () function to get a reasonable default value 
# for COPYFROMDIR.
# Note: Internally the get_a_default_path_for_COPYFROMDIR () function calls another function
# get_wasta_offline_usb_mount_point () to determine any qualifying USBMOUNTPOINT. If the later
# function returns a non-empty USBMOUNTPOINT that value is returned by the 
# get_a_default_path_for_COPYFROMDIR () function, otherwise "UNKNOWN" is returned.
# The value in COPYFROMDIR below would be overridden by a first parameter - when 2 parameters
# are passed to this make_Master_for_Wasta-Offline.sh script (see below).
COPYFROMDIR=`get_a_default_path_for_COPYFROMDIR` # either path of "UNKNOWN" or default path of /media/$USER/<DISK_LABEL>/wasta-offline

# What destination mirror are we creating/syncing to? 
# Get a default value for COPYTODIR - noting the following possibilities:
# It could be that the computer being used to hold the master mirror may already have an
# apt-mirror installation, and/or an older version of the wasta-offline mirror on it.
# Use the get_a_default_path_for_COPYTODIR () function to get a reasonable default value 
# for COPYTODIR.
# Note: Internally the get_a_default_path_for_COPYTODIR () function calls another function
# get_base_path_of_mirror_list_file () to get any mirror.list base_path that exists.
# If no base_path is available from a mirror.list, this function returns a default value
# of /data/master/wasta-offline. 
# If a base_path is available from a mirror.list file, this function returns the base_path 
# (minus its .../apt-mirror dir) as an initial default COPYTODIR.
# The value in COPYTODIR below would be overridden by a second parameter - when only 1
# parameter is passed to make_Master_for_Wasta-Offline.sh.
# The value in COPYTODIR below would be overridden by a first parameter - when 2 parameters
# are passed to this make_Master_for_Wasta-Offline.sh script (see below).
COPYTODIR=`get_a_default_path_for_COPYTODIR` # Either a path from any mirror.list file, or default path of /data/master/wasta-offline.

# We can't make a master mirror if no USB drive is plugged in/mounted that has a wasta-offline
# mirror tree on it. In such a case COPYFROMDIR will have been set above to "UNKNOWN".
# Bleed off the "UNKNOWN" case here, since the script cannot proceed.
if [[ "$COPYFROMDIR" == "UNKNOWN" ]]; then
  echo -e "\n****** WARNING ******"
  echo "No USB drive could be found containing a wasta-offline mirror."
  echo "Perhaps you failed to plug it in, or it wasn't mounted."
  echo "Please plugin a USB drive containing a full wasta-offline mirror and try again!"
  echo "****** WARNING ******"
  echo "Aborting..."
  exit 1
fi

sleep 3s
case $# in
    0) 
    
      # A default $COPYFROMDIR and $COPYTODIR were calculated above.
      # The default COPYFROMDIR at this point will be &USBMOUNTPOINT ("UNKNOWN" case handled above).
      # The default COPYTODIR is either a path from any mirror.list file, or /data/master/wasta-offline.
    
      echo -e "\nThis $MAKEMASTERCOPYSCRIPT script was invoked without any parameters:"
      echo "Default values will be assumed as follows"
      echo "  Directory to sync from is: $COPYFROMDIR (default)"
      echo "  Directory to sync to is:   $COPYTODIR (default)"
      # Preliminary Check:
      # Do a preliminary check at this early stage, to ensure that a non-empty $COPYTODIR  
      # and a non-empty $COPYFROMDIR don't point to the same path location. 
      # This might happen if the computer to host the master mirror beintg created was used 
      # previously to get full wasta-offline updates for an external USB drive by calling 
      # the updata-mirror.sh script - during the time it did not have a master mirror established 
      # on the computer. In such cases the update-mirror.sh script would have ensured that 
      # apt-mirror was installed and the updata-mirror.sh script would also have generated a 
      # mirror.list file at /etc/apt/mirror.list, and that mirror.list would have set the 
      # base_path value to point directly to the full mirror on the external USB drive. The
      # administrator may now be using the same external USB drive as source mirror for creating  
      # the master mirror on the host computer - by calling this script. In such cases the
      # script would detect that the $COPYFROMDIR value might be something like:
      # /media/bill/UPDATES/wasta-offline, and the $COPYTODIR value (taken from the mirror.list
      # file) would also point to the same location: /media/bill/UPDATES/wasta-offline. It would
      # not make sense to copy mirror data from an external USB drive AND copying it to the 
      # same external USB drive. The mirror data needs to be copied from the external drive's
      # source mirror to the destination mirror on the dedicated computer. And, any mirror.list 
      # file's base_path needs to be set to point to the master mirror on the dedicated computer
      # rather than pointing to the external drive's mirror.
      # We have to detect this situation, and adjust the $COPYTODIR to a suitable default
      # location on the dedicated computer's hard drive - /data/master/wasta-offline. This
      # initial default may be changed by use of one or two parameter(s) passed to the script.
      # In this situation we also need to generate a new mirror.list file on the hosting computer
      # hosting computer so that its mirror.list file's base_path value is set to the default
      # master mirror's destination location of /data/master/wasta-offline, replacing its 
      # Previous setting that pointed to the external USB drive.
      if [[ "$COPYTODIR" == "$COPYFROMDIR" && "x$COPYTODIR" != "x" && "x$COPYFROMDIR" != "x" ]]; then
        echo "This computer's mirror.list file points to a base_path for its mirror of:"
        echo "   $COPYTODIR"
        echo "But that location is also the SAME mirror location as the USB drive."
        echo "It makes no sense to copy mirror data from/to the same location!"
        echo "Therefore, we adjust the destination master mirror's base_path to"
        echo "point to a default location of: $DATADIR$MASTERDIR$WASTAOFFLINEDIR."
        COPYTODIR=$DATADIR$MASTERDIR$WASTAOFFLINEDIR
      fi
        ;;
    1) 
      # The default COPYFROMDIR at this point will be &USBMOUNTPOINT ("UNKNOWN" case handled above).
      # The COPYTODIR is contained in the single parameter passed into this function.
      COPYTODIR="$1"
      echo -e "\nThis $MAKEMASTERCOPYSCRIPT script was invoked with 1 parameter:"
      echo "  Directory to sync from is: $COPYFROMDIR (default)"
      echo "  Directory to sync to is:   $COPYTODIR (parameter 1)"
      # Preliminary Check:
      # Do a preliminary check at this early stage, to ensure that a non-empty $COPYTODIR  
      # and a non-empty $COPYFROMDIR don't point to the same path location. 
      # This might happen if user used one parameter and the path represented by that parameter
      # is the same as the (default) path to the mirror on the USB drive.
      if [[ "$COPYTODIR" == "$COPYFROMDIR" && "x$COPYTODIR" != "x" && "x$COPYFROMDIR" != "x" ]]; then
        echo -e "\n****** WARNING ******"
        echo "The destination location is the SAME as the USB drive."
        echo "It makes no sense to copy mirror data from/to the same location!"
        echo "Please supply a destination path for the master mirror is not the same as the"
        echo "the path to the USB Drive and try again!"
        echo "****** WARNING ******"
        echo "Script Usage:"
        echo "$MAKEMASTERCOPYSCRIPT [no parameters]"
        echo "  <source-dir-path> defaults to /media/$USER/<DISK_LABEL>/wasta-offline"
        echo "  <destination-dir-path> defaults to /data/master/wasta-offline"
        echo "$MAKEMASTERCOPYSCRIPT [<destination-dir-path>]"
        echo "  <source-dir-path> defaults to /media/$USER/<DISK_LABEL>/wasta-offline"
        echo "$MAKEMASTERCOPYSCRIPT [<source-dir-path>] [<destination-dir-path>]"
        echo "Aborting..."
        exit 1
      fi
        ;;
    2) 
      # The COPYFROMDIR is contained in the first parameter passed into this function.
      # The COPYTODIR is contained in the second parameter passed into this function.
      COPYFROMDIR="$1"
      COPYTODIR="$2"
      echo -e "\nThis $MAKEMASTERCOPYSCRIPT script was invoked with 2 parameters:"
      echo "  Directory to sync from is: $COPYFROMDIR (parameter 1)"
      echo "  Directory to sync to is:   $COPYTODIR (parameter 2)"
      # Preliminary Check:
      # Do a preliminary check at this early stage, to ensure that a non-empty $COPYTODIR  
      # and a non-empty $COPYFROMDIR don't point to the same path location. 
      # This might happen if user entered the same path for both parameters.
      if [[ "$COPYTODIR" == "$COPYFROMDIR" && "x$COPYTODIR" != "x" && "x$COPYFROMDIR" != "x" ]]; then
        echo -e "\n****** WARNING ******"
        echo "The destination location is the SAME as the USB drive."
        echo "It makes no sense to copy mirror data from/to the same location!"
        echo "Please supply a destination path for the master mirror is not the same as the"
        echo "the path to the USB Drive and try again!"
        echo "****** WARNING ******"
        echo "Script Usage:"
        echo "$MAKEMASTERCOPYSCRIPT [no parameters]"
        echo "  <source-dir-path> defaults to /media/$USER/<DISK_LABEL>/wasta-offline"
        echo "  <destination-dir-path> defaults to /data/master/wasta-offline"
        echo "$MAKEMASTERCOPYSCRIPT [<destination-dir-path>]"
        echo "  <source-dir-path> defaults to /media/$USER/<DISK_LABEL>/wasta-offline"
        echo "$MAKEMASTERCOPYSCRIPT [<source-dir-path>] [<destination-dir-path>]"
        echo "Aborting..."
        exit 1
      fi
        ;;
    *)
      echo -e "\nUnrecognized or too many parameters used with script."
      echo "Script Usage:"
      echo "$MAKEMASTERCOPYSCRIPT [no parameters]"
      echo "  <source-dir-path> defaults to /media/$USER/<DISK_LABEL>/wasta-offline"
      echo "  <destination-dir-path> defaults to /data/master/wasta-offline"
      echo "$MAKEMASTERCOPYSCRIPT [<destination-dir-path>]"
      echo "  <source-dir-path> defaults to /media/$USER/<DISK_LABEL>/wasta-offline"
      echo "$MAKEMASTERCOPYSCRIPT [<source-dir-path>] [<destination-dir-path>]"
      exit 1
        ;;
esac

# At this point the $COPYFROMDIR and $COPYTODIR values have been adjusted by any 
# parameters that were passed in to the script.

# We can't make a master mirror if the USB drive doesn't have a FULL wasta-offline mirror on it.
sleep 3s
echo -e "\nChecking for a USB drive containing a full wasta-offline source data tree..."
# Bleed off the case that the USB drive doesn't have a full wasta-offline mirror on it.
if is_there_a_wasta_offline_mirror_at "$COPYFROMDIR" ; then
  # There is already a full wasta-offline mirror at $COPYFROMDIR
  echo -e "\nFound a full wasta-offline mirror at: $COPYFROMDIR"
else
  # There is no wasta-offline mirror at the source location, so notify user and abort.
  echo -e "\n****** WARNING ******"
  echo "No USB drive was found having a full Wasta-Offline Mirror."
  echo "Have you plugged in a USB drive containing a full Wasta-Offline Mirror on it?"
  echo "Cannot create a master mirror without a full mirror on a USB drive to copy from."
  echo "Please plug in an existing 'Full Wasta-Offline Mirror' USB Drive and try again!"
  echo "****** WARNING ******"
  echo "Aborting..."
  exit 1
fi

# Get more information about the attached/mounted USB drive, especially the space required for the 
# current full mirror that we're creating/syncing from the USB drive.
# The USBMOUNTDIR value should be the path up to, but not including /wasta-offline of $USBMOUNTPOINT
USBMOUNTDIR=$USBMOUNTPOINT # normally USBMOUNTDIR is /media/$USER/<DISK_LABEL>
if [[ $USBMOUNTPOINT == *"wasta-offline"* ]]; then 
  USBMOUNTDIR=$(dirname "$USBMOUNTPOINT")
fi
USBDEVICENAME=`get_device_name_of_usb_mount_point $USBMOUNTPOINT`
echo "   Device NAME of USB Drive: $USBDEVICENAME"
USBFILESYSTEMTYPE=`get_file_system_type_of_usb_partition $USBDEVICENAME`
echo "   File system TYPE of USB Drive: $USBFILESYSTEMTYPE"
  
# Get more information about the destination's master mirror taking into account any
# parameter-updated COPYTODIR value.
# Earlier in this script, a call of the get_base_path_of_mirror_list_file () function
# assigned a value to the BASEPATH_TO_MIRROR. 
# The value of BASEPATH_TO_MIRROR then was either:
#   an empty string, if no mirror.list file exists, or
#   the value set for base_path in any existing mirror.list file.
# After parameter adjustments, the BASEPATH_TO_MIRROR should now be assigned the same
# value as the $COPYTODIR, which, the above code assured $COPYTODIR will not be an 
# empty string, but will be either a default value of /data/master/wasta-offline or 
# whatever path value set by parameter.
# The $COPYTODIR/$BASEPATH_TO_MIRROR will also be used later when updating the master
# mirror computer's mirror.list file with an accurate base_path pointing to the
# master mirror.
BASEPATH_TO_MIRROR=$COPYTODIR

# Get the top level root or ROOT_DIRECTORY_OF_MASTER from the BASEPATH_TO_MIRROR.
sleep 3s
echo -e "\nThe destination path to the master mirror is: $BASEPATH_TO_MIRROR"
ROOT_DIRECTORY_OF_MASTER="/"$(echo "$BASEPATH_TO_MIRROR" | cut -d "/" -f2)
echo "The root directory of the master mirror is: $ROOT_DIRECTORY_OF_MASTER"

# Check whether the ROOT_DIRECTORY_OF_MASTER exists. If not create the base directory, if only
# temporarily, in order to get a value using df for MASTER_BYTES_AVAIL.
CREATED_ROOT_DIRECTORY_OF_MASTER="FALSE"
if [ ! -d "$ROOT_DIRECTORY_OF_MASTER" ]; then
  CREATED_ROOT_DIRECTORY_OF_MASTER="TRUE"
  mkdir -p "$ROOT_DIRECTORY_OF_MASTER"
fi

# Check that the COPYTODIR's base dir has enough space for syncing the full 
# master mirror from the USB drive.
# Note on using df and pipes:
# df option: -B1 means block is is 1 byte
# df --output=fstype,used,target means select for output columns fstype, used (number of bytes), target (mount point)
# pipe to awk '{if(NR>1)print}' removes header line out df output
# pipe to tr -s " " means to squeeze each repeated space to a single space
# pipe to cut -f2 -d" " means to cut stream to output only field 2 delimited by space
# Note: fstype is first listed column in df --output because used has leading spaces
# that prevent accurate selection of field in the cut pipe, whereas fstype doesn't
# have leading spaces, making cut's field selection work accurately.
# Using df rather than lsblk, because lsblk just has one 'SIZE' field, and doesn't 
# appear to have fields that differentiate between a 'used' and an 'avail' fields
# that are available in the df --output= fields.
USB_BYTES_USED=`df -B1 --output=fstype,used,target $USBMOUNTDIR | awk '{if(NR>1)print}' | tr -s " " | cut -f2 -d" "`
MASTER_BYTES_AVAIL=`df -B1 --output=fstype,avail,target $ROOT_DIRECTORY_OF_MASTER | awk '{if(NR>1)print}' | tr -s " " | cut -f2 -d" "`
#USB_BYTES_USED=`lsblk -o SIZE,MOUNTPOINT -b | grep $USBMOUNTDIR | cut -f1 -d" "`
#MASTER_BYTES_AVAIL=`lsblk -o SIZE,MOUNTPOINT -b | grep $ROOT_DIRECTORY_OF_MASTER | cut -f1 -d" "`
ONE_TB_BYTES="1000000000000"
# If the disk space used by the USB drive's data > space available, warn user and abort
sleep 3s
if [ "$USB_BYTES_USED" -gt "$MASTER_BYTES_AVAIL" ]; then
  echo -e "\n-----------------------------------------------------------------"
  echo "Checking Disk Space Requirements..."
  echo "   The source USB Drive mirror uses $USB_BYTES_USED Bytes of data."
  echo "    The dest Master Mirror only has $MASTER_BYTES_AVAIL Bytes available."
  echo "-----------------------------------------------------------------"
  echo "****** WARNING ******"
  echo "The USB data used is GREATER than available space at the master mirror!"
  echo "This script cannot create a master mirror in the space available."
  echo "Please allocate disk space for the master mirror of at least 1TB and try again!"
  echo "****** WARNING ******"
  echo "Aborting..."
  # If we just created the $ROOT_DIRECTORY_OF_MASTER above with mkdir remove it with rm -rf
  # before we abort. If "$CREATED_ROOT_DIRECTORY_OF_MASTER" == "TRUE" we know that the 
  # directory didn't exist previously. Since we're running as root, ensure that
  # the value in $ROOT_DIRECTORY_OF_MASTER is not "/" since rm -rf / would remove the entire
  # file system!!
  if [[ "$CREATED_ROOT_DIRECTORY_OF_MASTER" == "TRUE" && "$ROOT_DIRECTORY_OF_MASTER" != "/" ]]; then
    rm -rf "$ROOT_DIRECTORY_OF_MASTER"
  fi
  exit 1
else
  echo -e "\n-----------------------------------------------------------------"
  echo "Checking Disk Space Requirements..."
  echo "   The source USB Drive mirror uses $USB_BYTES_USED Bytes of data."
  echo "   The dest Master Mirror Drive has $MASTER_BYTES_AVAIL Bytes available."
  if [ "$MASTER_BYTES_AVAIL" -lt "$ONE_TB_BYTES" ]; then 
    echo "WARNING: The dest Master Mirror Drive space is smaller than 1TB!"
    echo "You have sufficient space now, but your master mirror may run out of space."
    echo "We recommend that you allocate at least 1TB for the master mirror!"
  fi
  echo "-----------------------------------------------------------------"
fi
sleep 3s

# If we get here, there is probably sufficient space to create the mirror at $COPYTODIR location
# Check if the ROOT_DIRECTORY_OF_MASTER already exists that we'll sync to.

# NOTE: The call of the sync_Wasta-Offline_to_Ext_Drive.sh script at the end
# of this function will check for existence of any wasta-offline mirror at the
# COPYTODIR location. If one exists, that script will also check the time stamps
# to see if the destination mirror is OLDER, SAME, or NEWER, and will then 
# present that info to the user along with a timed prompt in which s/he can
# proceed to create/sync the mirror to the destination, or abort the operation.

# Call the get_sources_list_protocol () function to determine the current protocol
# of the dedicated computer's sources.list file.
# Internally the 'get_sources_list_protocol' function call below gets the 
# currently used protocol from the sources.list file, but we'll also get it here and
# assign it to a locally defined PROTOCOL variable for use below when calling
# the 'generate_mirror_list_file ()' function. Presumably the sources.list file 
# of the dedicated master computer is likely to point to the best sources for
# installing apt-mirror within the context of this make_Master_for_Wasta-Offline.sh
# script. 
SOURCES_LIST_PROTOCOL=`get_sources_list_protocol` 
#echo "The SOURCES_LIST_PROTOCOL is: $SOURCES_LIST_PROTOCOL"

if smart_install_program $APTMIRROR -q ; then
  # The apt-mirror program is installed
  echo "The $APTMIRROR program is installed"
else
  # Could NOT install the apt-mirror program so warn and abort
  echo -e "\n****** WARNING ******"
  echo "Error: Could not install $APTMIRROR."
  echo "****** WARNING ******"
  echo "Aborting..."
  exit $LASTERRORLEVEL        
fi
# Always create/update the master computer's mirror.list file with current base_path
# Call the generate_mirror_list_file () function to create/update the computer's 
# mirror.list file.
# The generate_mirror_list_file () function requires that the $LOCALMIRRORSPATH
# variable be defined before the function is called.
# In this context, we use the $COPYTODIR path with the /apt-mirror dir appended to it.
GENERATEDSIGNATURE="###_This_file_was_generated_by_the_update-mirror.sh_script_###"
LOCALMIRRORSPATH=$COPYTODIR$APTMIRRORDIR # default to /data/master/wasta-offline/apt-mirror
ETCAPT="/etc/apt/"
MIRRORLIST="mirror.list"
MIRRORLISTPATH=$ETCAPT$MIRRORLIST # /etc/apt/mirror.list
SAVEEXT=".save" # used in generate_mirror_list_file () function
# Note: We use the $PROTOCOL that currently exists in the computer's sources.list as an
# initial default mirror.list prefix protocol when establishing the master mirror with 
# make_Master_for_Wasta-Offline.sh. For a master computer based at Ukarumpa the most likely
# protocol would be the local server at: http://linuxrepo.sil.org.pg/mirror/. Even so, 
# once the master mirror is established using this current script, the updata-mirror.sh script 
# will be used to update the mirror, and update-mirror.sh will change the protocol prefix of 
# the entries in the mirror.list file each time the user runs update-mirror.sh depending
# on the menu choice (of where to get the mirror data) the user makes in the process
# of running the update-mirror.sh script.
if generate_mirror_list_file $SOURCES_LIST_PROTOCOL ; then
  echo "Successfully generated $MIRRORLIST at $MIRRORLISTPATH."
else
  echo -e "\n****** WARNING ******"
  echo "Error: Could not generate $MIRRORLIST at $MIRRORLISTPATH."
  echo "****** WARNING ******"
  echo "Aborting..."
  # If we just created the $ROOT_DIRECTORY_OF_MASTER above with mkdir remove it with rm -rf
  # before we abort. If "$CREATED_ROOT_DIRECTORY_OF_MASTER" == "TRUE" we know that the 
  # directory didn't exist previously. Since we're running as root, ensure that
  # the value in $ROOT_DIRECTORY_OF_MASTER is not "/" since rm -rf / would remove the entire
  # file system!!
  if [[ "$CREATED_ROOT_DIRECTORY_OF_MASTER" == "TRUE" && "$ROOT_DIRECTORY_OF_MASTER" != "/" ]]; then
    rm -rf "$ROOT_DIRECTORY_OF_MASTER"
  fi
  exit $LASTERRORLEVEL
fi

#TODO: At this point we could offer to activate the automatic running of apt-mirror 
# by uncommenting the line in /etc/cron.d/apt-mirror and setting a daily hour to
# run apt-mirror. Ask user for hour?

# Make sure there is an apt-mirror group on the user's computer and
# add the non-root user to the apt-mirror group
echo -e "\nEnsuring apt-mirror group exists and user $SUDO_USER is in apt-mirror group..."
sleep 3s
if ! ensure_user_in_apt_mirror_group "$SUDO_USER" ; then
  # Issue a warning, but continue the script
  echo "WARNING: Could not add user: $SUDO_USER to the apt-mirror group"
else
  echo "User $SUDO_USER is in the apt-mirror group"
fi

# Note: The sync_Wasta-Offline_to_Ext_Drive.sh script that is called below checks
# the time stamps of the COPYFROMDIR and COPYTODIR mirrors, and informs the user
# whether the time stamps of the destination are newer, older or the same, and
# allows the user to proceed or abort the operation based on the time stamp info. 

# Finally, call the 'sync_Wasta-Offline_to_Ext_Drive.sh' script to sync the source
# mirror to the destination mirror and form the master mirror.
# That script also does some checks of the mirrors at $COPYFROMDIR and $COPYTODIR
# and other validity checks.
sleep 3s
echo -e "\nCalling the $SYNCWASTAOFFLINESCRIPT script with these parameters:"
echo "  Source mirror (parameter 1): $COPYFROMDIR"
echo "  Destination mirror (parameter 2): $COPYTODIR"
bash $DIR/$SYNCWASTAOFFLINESCRIPT $COPYFROMDIR $COPYTODIR

# Once the 'sync_Wasta-Offline_to_Ext_Drive.sh' script finishes, program
# execution returns here, and this script also finishes at this point.
echo -e "\nThe $MAKEMASTERCOPYSCRIPT script has finished."

