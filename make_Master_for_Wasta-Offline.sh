#!/bin/bash
# Author: Bill Martin <bill_martin@sil.org>
# Date: 4 November 2014
# Revision: 
#   - 7 November 2014 Modified for Trusty mount points having embedded $USER 
#      in $MOUNTPOINT path as: /media/$USER/LM-UPDATES whereas Precise has: 
#      /media/LM-UPDATES
#   - 17 April 2016 Changed the default path of the master mirror location
#      from /data/wasta-offline/ to /data/master/wasta-offline/. This change
#      is needed to avoid spurious running of wasta-offline at boot time on
#      Wasta 14.04 and newer Wasta systems.
#     Added a script version number "0.1" to the script to make future updates
#      easier.
# Name: make_Master_for_Wasta-Offline.sh
# Distribution: 
# This script is included with all Wasta-Offline Mirrors supplied by Bill Martin.
# If you make changes to this script to improve it or correct errors, please send
# your updated script to Bill Martin bill_martin@sil.org
#
# Purpose: 
# The primary purpose of this script is to create a Master copy of the full 
# Wasta-Offline Mirror on a local computer - copying the mirror data from a
# full Wasta-Offline Mirror located on a USB external drive to a location
# on the fixed hard drive of a computer. It calls sync_Wasta-Offline_to_Ext_Drive.sh
# to do its work of creating the master mirror. This script check to see if the 
# apt-mirror program is installed. If not, the script offers to install the 
# apt-mirror program. The script also ensures that the user's mirror.list 
# configuration file has its base_path set appropriately to save mirror updates 
# to the newly created master mirror. 
#
# What should be done after running this script:
# 
# Once this script has created a master copy of the full Wasta-Offline mirror, the 
# master copy of the mirror should be kept up to date by periodically running the 
# apt-mirror program. Before the script exits, it informs the user that keeping 
# the master mirror updated can be done by calling the update-mirror.sh script
# manually, or for automated updates on a regular schedule, the user can enable the 
# cron job provided during the installation of apt-mirror, by a simple edit of one  
# line in the /etc/cron.d/apt-mirror file.
# Once the master mirror is updated, one or more external USB hard drives can be 
# kept synchronized with the master copy by manually calling the 
# sync_Wasta-Offline_to_Ext_Drive.sh script directly.
# 
# This make_Master_for_Wasta-Offline.sh script does the following:
#   1. Runs the script as root (asks for password).
#   2. Checks any parameters that were passed to the script and acts accordingly.
#      If one parameter is present, it can be used to force the script to create
#        the master copy at a different destination path than the default path for
#        the master mirror being created which is: /data/master/wasta-offline/.
#      Note: We no longer use /data/wasta-offline/ as the path on the local
#        fixed hard drive, since the presence of a /data/wasta-offline/ folder
#        in the file system, can trigger the undesired running of wasta-offline 
#        at each boot up. To eliminate such spurious launches of wasta-offline, we
#        now make the master mirror's default location /data/master/wasta-offline/.
#      If two parameters are present they become the source and destination mirror
#        paths respectively ($1 is $COPYFROMDIR path and $2 is $COPYTODIR path).
#      Note: The $COPYFROMDIR and $COPYTODIR paths must be absolute paths to the 
#        wasta-offline directories that contain the apt-mirror generated mirrors 
#        (i.e., both source and destination paths should point to the "wasta-offline" 
#        directories of their respective mirror trees).
#      [Not implemented] If a thrid parameter is present it must be "PREP_NEW_USB". It 
#      will be ignored unless a USB drive is present and meets all of the following 
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
#   3. Checks to ensure that the sync_Wasta-Offline_to_Ext_Drive.sh script is availabe,
#      in the same directory and has executable permissions, if not aborts.
#   4. Finally, calls the sync_Wasta-Offline_to_Ext_Drive.sh script, passing on the
#      parameters that were given in calling this script. The main work is done by the
#      sync_Wasta-Offline_to_Ext_Drive.sh script.
# Usage:
# 1. The most up-to-date Wasta-Offline USB drive that is available should be used when 
#    creating the master copy on the local computer, so that subsequent updates to the
#    master copy of the mirror can be done quickly and easily.
# 2. bash make_Master_for_Wasta-Offline.sh [<source-mirror>] [destination-mirror] ["PREP_NEW_USB"]
#    All parameters are optional. 
#    If one parameter is present, it can be used to force the script to create
#      the master copy at a different destination path than the default path for
#      the master mirror being created which is: /data/master/wasta-offline/.
#    If two parameters are present they become the source and destination mirror
#      paths respectively ($1 is $COPYFROMDIR path and $2 is $COPYTODIR path).
#    Note: The $COPYFROMDIR and $COPYTODIR paths must be absolute paths to the 
#      wasta-offline directories that contain the apt-mirror mirrors (i.e.,
#      both source and destination paths should point to the "wasta-offline" 
#      directories of their respective mirror trees). 
# Note when set -e is uncommented, script stops immediately and no error codes are returned in "$?"
#set -e

SCRIPTVERSION="0.1"
DATADIR="/data"
MASTERDIR="/master"
OFFLINEDIR="/wasta-offline"
APTMIRRORDIR="/apt-mirror"
APTMIRRORSETUPDIR="/apt-mirror-setup"
MIRRORDIR="/mirror"
MOUNTPOINT=`mount | grep LM-UPDATES | cut -d ' ' -f3` # normally MOUNTPOINT is /media/LM-UPDATES or /media/$USER/LM-UPDATES
if [ "x$MOUNTPOINT" = "x" ]; then
  # $MOUNTPOINT for an LM-UPDATES USB drive was not found
  export LMUPDATESDIR=""
  COPYFROMDIR=""
else
  export LMUPDATESDIR=$MOUNTPOINT # normally MOUNTPOINT is /media/LM-UPDATES or /media/$USER/LM-UPDATES
  COPYFROMDIR=$LMUPDATESDIR$OFFLINEDIR  # /media/LM-UPDATES/wasta-offline or /media/$USER/LM-UPDATES/wasta-offline
fi
COPYTODIR=$DATADIR$MASTERDIR$OFFLINEDIR  # /data/master/wasta-offline
SYNCWASTAOFFLINESCRIPT="sync_Wasta-Offline_to_Ext_Drive.sh"
MAKEMASTERCOPYSCRIPT="make_Master_for_Wasta-Offline.sh"
PREPNEWUSB=$3 # if $3 is passed in it should be "PREP_NEW_USB"
WAIT=60

# The following block to run with superuser permissions is needed here, otherwise
# make_Master_for_Wasta-Offline.sh doesn't show a terminal window for error interaction.
# The similar block in sync_Wasta-Offline_to_Ext_Drive.sh will be skipped.
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
# Main program starts here
# ------------------------------------------------------------------------------
# This script calls the sync_Wasta-Offline_to_Ext_Drive.sh script to do its work,
# passing the appropriate parameters to the sync_Wasta-Offline_to_Ext_Drive.sh script.
# The parameters that are passed on to sync_Wasta-Offline_to_Ext_Drive.sh are 
# determined by what parameters are given to this make_Master_for_Wasta-Offline.sh
# script at invocation.
echo -e "\n"
case $# in
    0) 
      echo "$MAKEMASTERCOPYSCRIPT was invoked without any parameters:"
      echo "  Directory to sync from is: $COPYFROMDIR (default)"
      echo "  Directory to sync to is:   $COPYTODIR (default)"
        ;;
    1) 
      COPYTODIR="$1"
      echo "$MAKEMASTERCOPYSCRIPT was invoked with 1 parameter:"
      echo "  Directory to sync from is: $COPYFROMDIR (default)"
      echo "  Directory to sync to is:   $COPYTODIR (parameter 1)"
        ;;
    2) 
      COPYFROMDIR="$1"
      COPYTODIR="$2"
      echo "$MAKEMASTERCOPYSCRIPT was invoked with 2 parameters:"
      echo "  Directory to sync from is: $COPYFROMDIR (parameter 1)"
      echo "  Directory to sync to is:   $COPYTODIR (parameter 2)"
        ;;
    3) 
      COPYFROMDIR="$1"
      COPYTODIR="$2"
      PREPNEWUSB="$3"
      echo "$MAKEMASTERCOPYSCRIPT was invoked with 2 parameters:"
      echo "  Directory to sync from is: $COPYFROMDIR (parameter 1)"
      echo "  Directory to sync to is:   $COPYTODIR (parameter 2)"
      echo "  Parameter '$3' included"
        ;;
    *)
      echo "Unrecognized parameters used with script."
      echo "Usage:"
      echo "$MAKEMASTERCOPYSCRIPT [<source-dir-path>] [<destination-dir-path>] ['PREP_NEW_USB']"
      exit 1
        ;;
esac

# Check that the sync_Wasta-Offline_to_Ext_Drive.sh script is available in the
# same directory and has execute permissions.
# Get the path prefix of this executing script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -x $DIR/$SYNCWASTAOFFLINESCRIPT ]; then
  echo -e "\n$DIR/$SYNCWASTAOFFLINESCRIPT exists, is executable"
else
  echo -e "\nCannot find the $DIR/$SYNCWASTAOFFLINESCRIPT script"
  echo "This script requires that $SYNCWASTAOFFLINESCRIPT be available."
  echo "Aborting..."
  exit 1
fi

# Check whether the COPYTODIR already exists. If so, warn and abort.
if [ -d $COPYTODIR ]; then
  echo -e "\nA master mirror already exists at $COPYTODIR"
  echo "This script should only be used to create a new master mirror."
  echo "Aborting..."
  exit 1
fi

# Check whether an older master mirror exists at:
#   /data/wasta-offline/apt-mirror/mirror/
# If so, offer to do a fast mv to relocate the older master mirror to the new location of:
#   /data/master/wasta-offline/apt-mirror/mirror/
# and adjust the user's mirror.list file
# TODO: Could make the following if ... fi block into a function called
#       move_mirror_from_data_to_data_master ()
# TODO: Any changes to this block should also be made in sync_Wasta-Offline_to_Ext_Drive.sh
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
        mv $DATADIR/README.md $DATADIR$MASTERDIR
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

# The sync_Wasta-Offline_to_Ext_Drive.sh script will require superuser permissions, so
# we don't have to do it here in this script.
# The sync_Wasta-Offline_to_Ext_Drive.sh script will do the necessary checks for the
# existence of the mirrors at $COPYFROMDIR and $COPYTODIR.
# We don't use any external functions from bash_functions.sh in this script.
bash $DIR/$SYNCWASTAOFFLINESCRIPT $COPYFROMDIR $COPYTODIR $PREPNEWUSB

echo -e "\nThe $MAKEMASTERCOPYSCRIPT script has finished."

