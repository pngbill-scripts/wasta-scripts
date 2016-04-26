#!/bin/bash
# Author: Bill Martin <bill_martin@sil.org>
# Date: 4 November 2014
# Revision: 
#   - 7 November 2014 Modified for Trusty mount points having embedded $USER 
#      in $MOUNTPOINT path as: /media/$USER/LM-UPDATES whereas Precise was: 
#      /media/LM-UPDATES
#   - 26 April 2016 Revised to use a default source master mirror location of
#      /data/master/. If a master mirror still exists at the old /data location
#      the script now offers to quickly move (mv) the master mirror from its
#      /data location to the more recommended /data/master location.
#     Added a script version number "0.1" to the script to make future updates
#      easier.
# Name: update-mirror.sh
# Distribution:
# This script is the main script that is included with all full Wasta-Offline 
# Mirrors supplied by Bill Martin.
# The scripts are maintained on GitHub at:
# https://github.com/pngbill-scripts/wasta-scripts
# If you make changes to this script to improve it or correct errors, please send
# your updated script to Bill Martin bill_martin@sil.org

# Purpose:
# The primary purpose of this script is to help keep a Wasta-Offline full mirror 
# up to date with current software updates - getting those software updates from 
# either the Internet or from a local network FTP server (as exists at Ukarumpa 
# PNG). It can be used to keep a master copy of the mirror up to date on a local
# computer or server, or to update an external USB drive such as the "LM-UPDATES" 
# drive supplied by Bill Martin, up to date. This script may also be used to do 
# the initial setup of apt-mirror on a computer (installing apt-mirror if needed), 
# and automatically configuring the computer's apt-mirror configuration file 
# (/etc/apt/mirror.list) depending on the user's choice of sources (from a menu) 
# for such apt-mirror updates.
#
# NOTE: The inventory of software repositories apt-mirror downloads updates from is
#       controlled by the bash function below called generate_mirror_list_file ().
#       The current full Wasta-Offline mirror has about 430GB of data.
#       Existing repositories can be removed by commenting out lines from the
#       generate_mirror_list_file () function (see bash_functions.sh) or additional
#       repositories can be added by adding additional "deb-amd64" and "deb-i386" 
#       repositories to the generate_mirror_list_file () function.
# 
# This script does the following:
# 1. Runs the script as root (asks for password).
# 2. Determines whether there is a local copy of the wasta-offline software mirror
#    at the old /data/wasta-offline/apt-mirror/mirror/ location. If one is found at
#    the old location, the script offers to quickly move (mv) the master mirror
#    from its /data location to the more recommended /data/master location. 
# 3. Determines whether there is a wasta-offline software mirror at the prescribed
#    location of /data/master/wasta-offline/apt-mirror/mirror. If so, it assumes 
#    the local copy of the mirror is a "master" mirror and the one to be updated, 
#    and the wasta-offline software mirror on the external USB drive at 
#    /media/LM-UPDATES... will be synchronized with the local mirror after the 
#    updates have been completed. The script syncs the ext drive by calling the
#    sync_Wasta-Offline_to_Ext_Drive.sh script. If no local copy of the full wasta-
#    offline software mirror is at /data/master/wasta-offline/apt-mirror/mirror/,
#    the wasta-offline mirror on the external USB drive at /media/LM-UPDATES...
#    (where this script is normally run from) will receive the software updates
#    directly.
# 4. Checks that the necessary *.sh files are available within the apt-mirror-setup 
#    subfolder - of the same external USB hard drive that is being used to invoke 
#    this script.
# 5. Checks to see if apt-mirror is installed on the user's computer. If not it
#    offers to install apt-mirror, or quit.
# 6. It queries the user to determine where the apt-mirror software updates should 
#    come from, presenting the following menu of choices:
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Where should the Wasta-Offline Mirror get its software updates?
#   1) Get software updates from the SIL Ukarumpa local network FTP server.
#   2) Get software updates directly from the Internet (might be expensive!)
#   3) Get software updates from a custom network path that I will provide.
#   4) Quit - I don't want to get any software updates at this time.
# Please press the 1, 2, 3, or 4 key, or hit any key to abort - countdown 60
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#    If no response is given within 60 seconds, 4) Quit ... is automatically selected
#    and the script will end without getting any software updates.
# 7. Depending on the user's choice above, ensures that the user's /etc/apt/mirror.list
#    file and the /media/LM-UPDATES/wasta-offline/apt-mirror/var/postmirror* script 
#    files are configured properly to get software mirror updates from the user's
#    selected source for obtaining the software updates: the Internet, a local 
#    network FTP server, or a custom URL network path supplied by the user.
# 8. Calls the apt-mirror program to download software updates to the full mirror.
#    After fetching the software updates, the apt-mirror program itself calls the
#    postmirror.sh script (which may at the user's option call postmirror2.sh) to tidy 
#    up the updated software mirror.
#
# Usage: 
#   Automatic: bash update-mirror.sh - or, use the File Manager to navigate to the
#      master mirror or external hard drive (LM-UPDATES) and double-click on the 
#      updata-mirror.sh and select "Run in Terminal" to start the script.
#   Manual: Can be run manually with the following invocation and optional parameters: 
#      bash update-mirror.sh [ftp | <path-prefix>]
#      ftp option: Using ftp as a parameter will direct all downloads to the Ukarumpa FTP mirror
#         at ftp://ftp.sil.org.pg/Software/CTS/Supported_Software/Ubuntu_Repository/mirror/
#      <path-prefix> option: a different ftp:// or http:// URL address may be given
#   Requires sudo/root privileges - password requested at run-time.

SCRIPTVERSION="0.1"
UPDATEMIRRORSCRIPT="update-mirror.sh"
APTMIRROR="apt-mirror"
DATADIR="/data"
MASTERDIR="/master"
APTMIRRORDIR="/$APTMIRROR" # /apt-mirror
WASTAOFFLINE="wasta-offline"
WASTAOFFLINEDIR="/$WASTAOFFLINE" # /wasta-offline
MOUNTPOINT=`mount | grep LM-UPDATES | cut -d ' ' -f3` # normally MOUNTPOINT is /media/LM-UPDATES or /media/$USER/LM-UPDATES
if [ "x$MOUNTPOINT" = "x" ]; then
  # $MOUNTPOINT for an LM-UPDATES USB drive was not found
  LMUPDATESDIR=""
  WASTAOFFLINEEXTERNALAPTMIRRORPATH=""
else
  LMUPDATESDIR=$MOUNTPOINT # normally MOUNTPOINT is /media/LM-UPDATES or /media/$USER/LM-UPDATES
  WASTAOFFLINEEXTERNALAPTMIRRORPATH=$LMUPDATESDIR$WASTAOFFLINEDIR$APTMIRRORDIR # /media/LM-UPDATES/wasta-offline/apt-mirror
fi
WASTAOFFLINELOCALAPTMIRRORPATH=$DATADIR$WASTAOFFLINEDIR$APTMIRRORDIR # /data/wasta-offline/apt-mirror
UPDATINGLOCALDATA="YES" # [may be changed below]
LOCALMIRRORSPATH=$WASTAOFFLINELOCALAPTMIRRORPATH # default to /data/wasta-offline/apt-mirror [may be changed below]
MIRRORLIST="mirror.list"
SOURCESLIST="sources.list"
ETCAPT="/etc/apt/"
MIRRORLISTPATH=$ETCAPT$MIRRORLIST # /etc/apt/mirror.list
SAVEEXT=".save"
APTMIRRORSETUPDIR="/apt-mirror-setup"
POSTMIRRORSCRIPT="postmirror.sh"
POSTMIRROR2SCRIPT="postmirror2.sh"
SYNCWASTAOFFLINESCRIPT="sync_Wasta-Offline_to_Ext_Drive.sh"
FTP="ftp"
WAIT=60
# The SIL Ukarumpa FTP site's URL:
FTPUkarumpaURLPrefix="ftp://ftp.sil.org.pg/Software/CTS/Supported_Software/Ubuntu_Repository/mirror/"
# The above FTPUkarumpaURL may be overridden if the user invokes this script manually and uses a
# different URL in a parameter at invocation.
GENERATEDSIGNATURE="###_This_file_was_generated_by_the_update-mirror.sh_script_###"
InternetURLPrefix="http://"
FTPURLPrefix="ftp://"
FileURLPrefix="file:"
VARDIR="/var"
PathToCleanScript=$BasePath"/var/clean.sh"

CURRDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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

# Determine if user still has mirror directly off /data dir rather than the better /data/master dir
# If the user still has mirror at /data then offer to move (mv) it to /data/master
if ! move_mirror_from_data_to_data_master ; then
  # User opted not to move mirror from /data to /data/master
  echo -e "\nUser opted not to move (mv) the master mirror directories to: $DATADIR$MASTERDIR"
  echo "Aborting..."
  exit 1
fi

# NOTE: If neither a local master mirror nor a USB drive labeled "LM-UPDATES" is found notify
# the user of the problem and abort, otherwise continue.
# Updating the master wasta-offline mirror is handled a bit differently than the 
# external USB drive's mirror. If there is a local /data/wasta-offline/apt-mirror directory, 
# $UPDATINGLOCALDATA="YES" and update-mirror.sh will update the local master wasta-offline 
# mirror instead of the external USB drive's wasta-offline mirror. When the local master  
# mirror is updated, update-mirror.sh will also call the sync_Wasta-Offline_to_Ext_Drive.sh 
# script after the apt-mirror update to synchronize the external USB drive's mirror with the 
# newly updated master copy of the mirror. 
# This is the usual case for Bill Martin's situation and other situation in which a master
# mirror is maintained. If more than one Wasta-Offline USB drive mirror is being maintained
# it is more efficient to update a master mirror from the FTP or Internet repositories, and
# then sync from it to any external USB mirror that is attached to the system. When 
# there is no local master copy at /data/wasta-offline/apt-mirror (a possible use-case for  
# field situations with poor/expensive Internet access), $UPDATINGLOCALDATA="NO" and the 
# update-mirror.sh script will simply update the external USB drive's wasta-offline mirror 
# directly - and won't call the sync_Wasta-Offline_to_Ext_Drive.sh script.
# If multiple Wasta-Offline USB drive mirrors are being maintained, subsequent USB drive
# mirrors can be attached to the computer containing the master mirror, and one can then
# call the sync_Wasta-Offline_to_Ext_Drive.sh script directly to update the USB drive's
# mirror. Since all USB drive's should have the same label "LM-UPDATES" do not attach more
# than one of such USB drives at a time to the computer with a master mirror, as doing so
# may result in LM-UPDATES drives being mounted with underscores suffixed to the LM-UPDATES
# label used in mount points.
if [ -d $WASTAOFFLINELOCALAPTMIRRORPATH ]; then
  LOCALMIRRORSPATH=$WASTAOFFLINELOCALAPTMIRRORPATH # /data/wasta-offline/apt-mirror
  UPDATINGLOCALDATA="YES"
else
  if [ "x$WASTAOFFLINEEXTERNALAPTMIRRORPATH" = "x" ]; then
    echo -e "\nA USB drive labeled LM-UPDATES was not found."
    echo "Cannot update Wasta-Offline Mirror. Aborting..."
    exit 1
  fi
  LOCALMIRRORSPATH=$WASTAOFFLINEEXTERNALAPTMIRRORPATH # /media/LM-UPDATES/wasta-offline/apt-mirror or /media/$USER/LM-UPDATES/wasta-offline/apt-mirror
  UPDATINGLOCALDATA="NO"
fi

echo -e "\nThe current working directory is: $CURRDIR"
echo "The mirror to receive updates is at: $LOCALMIRRORSPATH"
echo -e "\nAre we updating a master copy of the mirror? $UPDATINGLOCALDATA"

# Check for some necessary files that are needed for this script.
# Check that the needed files and scripts exist in a subfolder called apt-mirror-setup 
# which is within the current directory (the directory in which this script is running).
# Check for existence of postmirror.sh in $CURRDIR$APTMIRRORSETUPDIR
if [ ! -f $CURRDIR$APTMIRRORSETUPDIR/$POSTMIRRORSCRIPT ]; then
  echo -e "\nSorry, the $POSTMIRRORSCRIPT file was not found. It should be at:"
  echo "  $CURRDIR$APTMIRRORSETUPDIR/$POSTMIRRORSCRIPT"
  echo "  in the $APTMIRRORSETUPDIR subfolder of the $CURRDIR directory."
  echo "Aborting $UPDATEMIRRORSCRIPT processing! Please try again..."
  exit 1
fi
# Check for existence of postmirror2.sh in $CURRDIR$/APTMIRRORSETUPDIR
if [ ! -f $CURRDIR$APTMIRRORSETUPDIR/$POSTMIRROR2SCRIPT ]; then
  echo -e "\nSorry, the $POSTMIRROR2SCRIPT file was not found. It should be at:"
  echo "  $CURRDIR$APTMIRRORSETUPDIR/$POSTMIRROR2SCRIPT"
  echo "  in the $APTMIRRORSETUPDIR subfolder of the $CURRDIR directory."
  echo "Aborting $UPDATEMIRRORSCRIPT processing! Please try again..."
  exit 1
fi
# Ensure the postmirror.sh and postmirror2.sh scripts are freshly copied from the
# $CURRDIR/apt-mirror-setup folder to the $CURRDIR/wasta-offline/apt-mirror/var folder.
echo -e "\nCopying postmirror*.sh files to $CURRDIR$WASTAOFFLINEDIR$APTMIRRORDIR$VARDIR..."
# Here is the main rsync command. The rsync options are:
#   -a archive mode (recurses thru dirs, preserves symlinks, permissions, times, group, owner)
#   -v verbose
#   -z compress file data during transfer
#   --progress show progress during transfer
#   --update overwrite only if file is newer than existing file
rsync -avz --progress --update $CURRDIR$APTMIRRORSETUPDIR/*.sh $CURRDIR$WASTAOFFLINEDIR$APTMIRRORDIR$VARDIR
# Ensure that postmirror.sh and postmirror2.sh scripts are executable for everyone.
chmod ugo+rwx $CURRDIR$WASTAOFFLINEDIR$APTMIRRORDIR$VARDIR/*.sh

# Check and ensure that wasta-offline is installed. This may not be the
# case initially for some users especially if they installed a custom mint 
# OS before wasta-linux was fully developed, or otherwise don't have
# wasta-offline installed. 
# Since this updata-mirror.sh script would normally be executed from an
# LM-UPDATES external USB drive, the latest 32bit and 64bit wasta-offline
# debian packages should be available in the root dir of the LM-UPDATES
# drive, and hence the appropriate wasta-offline package can be installed
# using dpkg without needing to download one from the Internet.
if is_program_installed $WASTAOFFLINE ; then
  echo -e "\n$WASTAOFFLINE is already installed on this computer."
else
  echo -e "\nInstalling $WASTAOFFLINE on this computer."
  # Detect whether 32bit or 64bit package should be installed
  # and use dpkg to install the package on the external drive
  MACHINE_TYPE=`uname -m`
  if [ ${MACHINE_TYPE} == 'x86_64' ]; then
    echo "This is a 64bit machine"
    DEB64=`find $CURRDIR/$WASTAOFFLINE*amd64.deb`
    echo "Installing $WASTAOFFLINE via: dpkg -i $DEB64"
    dpkg -i $DEB64
  else
    echo "This is a 32bit machine"
    DEB32=`find $CURRDIR/$WASTAOFFLINE*i386.deb`
    echo "Installing $WASTAOFFLINE via: dpkg -i $DEB32"
    dpkg -i $DEB32
  fi
fi

# Here is the main menu:
# Query the user where to get software updates: from the Internet or from a local network FTP server.
# The prompt counts down from 60 to 0 at which time it selects 4) unless user selects differently.
#echo -e "\n"
echo "Where should the Wasta-Offline Mirror get its software updates?"
echo "  1) Get software updates from the SIL Ukarumpa local network FTP server."
echo "  2) Get software updates directly from the Internet (might be expensive!)"
echo "  3) Get software updates from a custom network path that I will provide."
echo "  4) Quit - I don't want to get any software updates at this time."
for (( i=$WAIT; i>0; i--)); do
    printf "\rPlease press the 1, 2, 3, or 4 key, or hit any key to abort - countdown $i "
    read -s -n 1 -t 1 SELECTION
    if [ $? -eq 0 ]
    then
        break
    fi
done

if [ ! $SELECTION ]; then
  echo -e "\nNo selection made, or no reponse within $WAIT seconds. Assuming response of 4)"
  echo "No software updates will be downloaded at this time. Script completed."
  exit 0
fi

echo -e "\nYour choice was $SELECTION"
case $SELECTION in
  "1")
    # ping the FTP server to check for server access
    ping -c1 -q ftp://ftp.sil.org.pg
    if [ "$?" != 0 ]; then
      echo -e "\nFTP access to the ftp.sil.org.pg server is not available."
      echo "This script cannot run without access to the SIL FTP server."
      echo "Make sure the computer has access to the FTP server, then try again."
      echo "Aborting..."
      exit 1
    else
      echo -e "\nFTP access to the ftp.sil.org.pg server appears to be available!"
      # First, ensure that apt-mirror is installed
      if smart_install_program $APTMIRROR -q ; then
        # The apt-mirror program is installed
        echo -e "\nThe $APTMIRROR program is installed"
        # Create a custom mirror.list config file for this option
        if generate_mirror_list_file $FTPUkarumpaURLPrefix ; then
          echo -e "\nSuccessfully generated $MIRRORLIST at $MIRRORLISTPATH."
        else
          echo -e "\nError: Could not generate $MIRRORLIST at $MIRRORLISTPATH. Aborting..."
          exit $LASTERRORLEVEL
        fi
        echo -e "\nCalling apt-mirror - getting data from local Ukarumpa FTP site at:"
        echo "$FTPUkarumpaURLPrefix..."
        # Note: For this option, the user's /etc/apt/mirror.list file now points to repositories with 
        # this path prefix:
        # ftp://ftp.sil.org.pg/Software/CTS/Supported_Software/Ubuntu_Repository/mirror/..."
        apt-mirror
        # TODO: Error checking on apt-mirror call above???
        # Note: Before apt-mirror finishes it will call postmirror.sh to clean the mirror and 
        # optionally call postmirror2.sh to correct any Hash Sum mismatches.
        # Ensure that ownership of the mirror tree is apt-mirror:apt-mirror (otherwise cron won't run) 
        # The $LOCALMIRRORSPATH is determined in the generate_mirror_list_file() call above
        echo "Make $LOCALMIRRORSPATH dir owner be $APTMIRROR:$APTMIRROR"
        chown -R $APTMIRROR:$APTMIRROR $LOCALMIRRORSPATH # chown -R apt-mirror:apt-mirror /media/LM-UPDATES/wasta-offline/apt-mirror
        
        # If apt-mirror updated the master local mirror (at /data/wasta-offline/...), then sync 
        # it to the external USB mirror.
        if [ "$UPDATINGLOCALDATA" = "YES" ]; then
          # Call sync_Wasta_Offline_to_Ext_Drive.sh without any parameters: 
          #   the $COPYFROMDIR will be /data/wasta-offline/
          #   the $COPYTODIR will be /media/LM-UPDATES/wasta-offline
          bash $DIR/$SYNCWASTAOFFLINESCRIPT
        fi
      else
        echo -e "\nError: Could not install $APTMIRROR. Aborting..."
        exit $LASTERRORLEVEL
      fi
    fi
   ;;
  "2")
    # Check if the full wasta-offline mirror is running and plugged in - we can install apt-mirror from it
    if is_program_running $WASTAOFFLINE ; then
      echo "$WASTAOFFLINE is running"
      # Check if it's the LM-UPDATES full USB mirror that is plugged in
      if is_dir_available $WASTAOFFLINEEXTERNALAPTMIRRORPATH ; then  # /media/LM-UPDATES/wasta-offline/apt-mirror
        echo "LM-UPDATES is plugged in"
        # Go ahead and install the apt-mirror program
        if smart_install_program $APTMIRROR -q ; then
          # The apt-mirror program is installed
          echo -e "\nThe $APTMIRROR program is installed"
        else
          # We cannot continue if apt-mirror is not/cannot be installed
          echo -e "\nError: Could not install $APTMIRROR. Aborting..."
          exit $LASTERRORLEVEL
        fi
      fi
    else
      echo "$WASTAOFFLINE is not in use - checking for Internet access"
    fi
    # ping the Internet to check for Internet access to www.archive.ubuntu.com
    ping -c1 -q www.archive.ubuntu.com
    if [ "$?" != 0 ]; then
      echo -e "\nInternet access to www.archive.ubuntu.com not currently available."
      echo "This script cannot continue without access to the Internet."
      echo "Make sure the computer has access to the Internet, then try again."
      echo "Or, alternately, run wasta-offline and install software without Internet access"
      echo "Aborting..."
      exit 1
    else
      echo -e "\nInternet access to www.archive.ubuntu.com appears to be available!"
      # First, ensure that apt-mirror is installed
      if smart_install_program $APTMIRROR -q ; then
        # The apt-mirror program is installed
        echo -e "\nThe $APTMIRROR program is installed"
      else
        # We cannot continue if apt-mirror is not/cannot be installed
        echo -e "\nError: Could not install $APTMIRROR. Aborting..."
        exit $LASTERRORLEVEL
      fi
      # Create a custom mirror.list config file for this option
      if generate_mirror_list_file $InternetURLPrefix ; then
        echo -e "\nSuccessfully generated $MIRRORLIST at $MIRRORLISTPATH."
      else
        echo -e "\nError: Could not generate $MIRRORLIST at $MIRRORLISTPATH. Aborting..."
        exit $LASTERRORLEVEL
      fi
      echo -e "\nCalling apt-mirror - getting data from Internet ($InternetURLPrefix)"
      # Note: For this option, the user's /etc/apt/mirror.list file now points to repositories with this path prefix:
      # http://..."
      apt-mirror
      # TODO: Error checking on apt-mirror call above???
      # Note: Before apt-mirror finishes it will call postmirror.sh to clean the mirror and 
      # optionally call postmirror2.sh to correct any Hash Sum mismatches.
      # The $LOCALMIRRORSPATH is determined in the generate_mirror_list_file() call above
      echo "Make $LOCALMIRRORSPATH dir owner be $APTMIRROR:$APTMIRROR"
      chown -R $APTMIRROR:$APTMIRROR $LOCALMIRRORSPATH # chown -R apt-mirror:apt-mirror /media/LM-UPDATES/wasta-offline/apt-mirror
      # If apt-mirror updated the master local mirror (at /data/wasta-offline/...), then sync 
      # it to the external USB mirror.
      if [ "$UPDATINGLOCALDATA" = "YES" ]; then
        # Call sync_Wasta_Offline_to_Ext_Drive.sh without any parameters: 
        #   the $COPYFROMDIR will be /data/wasta-offline/
        #   the $COPYTODIR will be /media/LM-UPDATES/wasta-offline
        bash $DIR/$SYNCWASTAOFFLINESCRIPT
      fi
    fi
   ;;
  "3")
      # Query the user for a $CustomURLPrefix path to be used for the mirror updates.
      # With this option the user's supplied path prefix will be used in generating the mirror.list file 
      # so that they point to the user's input path.

      echo -e "\nType the URL prefix to the mirror on the server, or just Enter to abort:"
      echo "For example: ftp://ftp.organization.org/linux/software/mirror"
      echo -n "URL: "
      read CustomURLPrefix
      if [[ "x$CustomURLPrefix" != "x" ]]; then
        # Check for server access
        ping -c1 -q $CustomURLPrefix
        if [ "$?" != 0 ]; then
          echo -e "\nCannot access the $CustomURLPrefix server!"
          echo "Cannot get apt-mirror updates without access to the appropriate server."
          echo "Make sure the computer has access to the server, and determine the exact"
          echo "URL prefix to the mirror directory on the server, then try 3) again -"
          echo "Or, use one of the other menu selections 1) or 2) to get software updates."
          echo "Aborting..."
          exit 1
        else
          echo -e "\nAccess to the $CustomURLPrefix server appears to be available!"
          # Create a custom mirror.list config file for this option
          if generate_mirror_list_file $CustomURLPrefix ; then
            echo -e "\nSuccessfully generated $MIRRORLIST at $MIRRORLISTPATH."
          else
            echo -e "\nError: Could not generate $MIRRORLIST at $MIRRORLISTPATH. Aborting..."
            exit $LASTERRORLEVEL
          fi
          echo -e "\nCalling apt-mirror - getting data from Internet ($InternetURLPrefix)"
          # Note: For this option, the user's /etc/apt/mirror.list file now points to repositories with this path prefix:
          # "$CustomURLPrefix..."
          apt-mirror
          # TODO: Error checking on apt-mirror call above???
          # Note: Before apt-mirror finishes it will call postmirror.sh to clean the mirror and 
          # optionally call postmirror2.sh to correct any Hash Sum mismatches.
          # The $LOCALMIRRORSPATH is determined in the generate_mirror_list_file() call above
          echo "Make $LOCALMIRRORSPATH dir owner be $APTMIRROR:$APTMIRROR"
          chown -R $APTMIRROR:$APTMIRROR $LOCALMIRRORSPATH # chown -R apt-mirror:apt-mirror /media/LM-UPDATES/wasta-offline/apt-mirror
          # If apt-mirror updated the master local mirror (at /data/wasta-offline/...), then sync 
          # it to the external USB mirror.
          if [ "$UPDATINGLOCALDATA" = "YES" ]; then
            # Call sync_Wasta_Offline_to_Ext_Drive.sh without any parameters: 
            #   the $COPYFROMDIR will be /data/wasta-offline/
            #   the $COPYTODIR will be /media/LM-UPDATES/wasta-offline
            bash $DIR/$SYNCWASTAOFFLINESCRIPT
          fi
        fi
      else
        # User didn't type anything - abort
        echo -e "\nNo URL prefix was entered..."
        echo "Cannot get apt-mirror updates without access to the appropriate server."
        echo "Make sure the computer has access to the server, and determine the exact"
        echo "URL prefix to the mirror directory on the server, then try 3) again -"
        echo "Or, use one of the other menu selections 1) or 2) to get software updates."
        echo "Aborting..."
        exit 1
      fi
   ;;
  "4")
    echo -e "\nThe $APTMIRROR program was not called. The $UPDATEMIRRORSCRIPT script completed."
    exit 0
   ;;
  *)
    echo "Unrecognized response. Aborting..."
    exit 1
  ;;
esac
echo -e "\nThe $UPDATEMIRRORSCRIPT script has finished."

