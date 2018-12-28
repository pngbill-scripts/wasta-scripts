#!/bin/bash
# Author: Bill Martin <bill_martin@sil.org>
# Date: 4 November 2014
# Revisions: 
#   - 7 November 2014 Modified for Trusty mount points having embedded $USER 
#      in $USBMOUNTPOINT path as: /media/$USER/<DISK_LABEL> whereas Precise was: 
#      /media/<DISK_LABEL>
#   - 26 April 2016 Revised to use a default source master mirror location of
#      /data/master/. If a master mirror still exists at the old /data location
#      the script now offers to quickly move (mv) the master mirror from its
#      /data location to the more recommended /data/master location.
#     Added a script version number "0.1" to the script to make future updates
#      easier.
#   - 29 August 2017 Added some code to update the wasta-scripts files from 
#      the external GitHub repo - if Internet access is chosed as the update
#      method. Also the added code clones/updates the bills-wasta-docs files
#      from its external GitHub repo.
#   - 23 November 2018 Changed the path to the internal server at Ukarumpa
#      to http://linuxrepo.sil.org.pg/mirror/
#      Since the new path uses the http:// protocol rather than ftp:// I changed
#      the bash variable name from FTPUkarumpaURLPrefix to UkarumpaURLPrefix
#      and removed reference to FTP in other places.
#      Revised to make the script more generalized.
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
#      Added sleep statements to paus output for better monitoring of progress.
#      Made Abort warnings more visible in console output.
#      Removed 'export' from all variables - not needed for variable visibility.
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
# either the Internet or from a local Ukarumpa network server (as exists at Ukarumpa 
# PNG). It can be used to keep a master copy of the mirror up-to-date on a local
# computer or server, or to update an external USB drive such as the Full Wasta-Offline 
# drive supplied by Bill Martin, up to date. This script may also be used to do 
# the initial setup of apt-mirror on a computer (installing apt-mirror if needed), 
# and automatically configuring the computer's apt-mirror configuration file 
# (/etc/apt/mirror.list) depending on the user's choice of sources (from a menu) 
# for such apt-mirror updates.
#
# NOTE: These Wasta-Offline scripts are for use by administrators and not normal
# Wasta-Linux users. The Wasta-Offline program itself need not be running when you, 
# as administrator are running these scripts. Hence, when you plug in a USB drive 
# containing the full Wasta-Offline Mirror - intending to update a master mirror with 
# this update-mirror.sh script - and the Authentication/Password message appears,
# you as administrator, should just click Cancel - to stop wasta-offline from
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
# NOTE: 
# Updating the "master" wasta-offline mirror is handled a bit differently than the external
# USB drive's mirror. If there is a local /data/master/wasta-offline/apt-mirror directory, 
# $UPDATINGLOCALDATA="YES" and update-mirror.sh will update the local master wasta-offline 
# mirror instead of the external USB drive's wasta-offline mirror. If an external USB 
# drive with a wasta-offline mirror on it is plugged in, another variable named 
# $UPDATINGEXTUSBDATA="YES" and update-mirror.sh will ALSO conveniently call the 
# sync_Wasta-Offline_to_Ext_Drive.sh script to synchronize the external USB drive's mirror 
# to be identical with the newly updated master copy of the mirror.
# It can be very useful to have a master on a dedicated computer and use updata-mirror.sh
# to keep that master mirror updated. With a master mirror, if more than one portable
# Wasta-Offline USB drive is being maintained, it is more efficient to use this script to
# update the master mirror from the Local server or Internet repositories, and then sync 
# from the master mirror to any external USB mirror that is attached to the system. 
#
# When multiple Wasta-Offline portable USB drive mirrors are being maintained (as at 
# Ukarumpa), subsequent USB drive mirrors can be attached to the computer containing the 
# master mirror - one at a time - and for each successive USB drive, the administrator
# can call the sync_Wasta-Offline_to_Ext_Drive.sh script directly to update the USB 
# drive's mirror. 
#
# Note: Since each of the multiple USB drives may have the same disk label ("UPDATES" for
# example), you should not attach more than one of such USB drives at a time to the 
# computer hosting the master mirror to get updated. Update only one USB drive at a time! 
# The reason for this is that, if more than one USB drive is attached with identical disk 
# labels, only the first drive that was plugged into a USB port will be used/updated. 
# For example, if two full wasta-offline drives are mounted at the same time, and both 
# have the same disk label of "UPDATES", the system will temporarily mount additional
# USB drives with adjuste disk label names - as "UPDATES1" or "UPDATES_". This script
# will only update the first USB drive containing a wasta-offline mirror that is 
# mounted to the master mirror computer system.

# When there is no local master copy at /data/master/wasta-offline/apt-mirror (a possible 
# use-case for field situations with only poor/expensive Internet access), the variable 
# $UPDATINGLOCALDATA="NO" and the update-mirror.sh script will simply update the external 
# USB drive's wasta-offline mirror directly - and won't call the 
# sync_Wasta-Offline_to_Ext_Drive.sh script.

# NOTE: The inventory of software repositories apt-mirror downloads updates from is
#       controlled by the bash function below called generate_mirror_list_file ().
#       The current full Wasta-Offline mirror has about 750GB of data.
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
#    from its /data/... location to the more recommended /data/master/... location. 
# 3. Determines whether there is a wasta-offline software mirror at the prescribed
#    master location of /data/master/wasta-offline/apt-mirror/mirror. If so, it assumes 
#    the local copy of the mirror is a "master" mirror and the one to be updated, 
#    and the wasta-offline software mirror on the external USB drive at 
#    /media/$USER/<DISK_LABEL>... will be synchronized with the local mirror after  
#    the updates have been completed. The script syncs the ext drive by calling the
#    sync_Wasta-Offline_to_Ext_Drive.sh script. If no local copy of the full wasta-
#    offline software mirror is at /data/master/wasta-offline/apt-mirror/mirror/,
#    the wasta-offline mirror on the external USB drive at /media/$USER/<DISK_LABEL>...
#    (where this script is normally run from) will receive the software updates
#    directly without first updating a master mirror.
# 4. Checks that the necessary *.sh files are available within the apt-mirror-setup 
#    subfolder - of the same external USB hard drive that is being used to invoke 
#    this script.
# 5. Checks to see if apt-mirror is installed on the user's computer. If not it
#    offers to install apt-mirror, or quit.
# 6. It queries the user to determine where the apt-mirror software updates should 
#    come from, presenting the following menu of choices:
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Where should the Wasta-Offline Mirror get its software updates?
#   1) Get software updates from the SIL Ukarumpa local network server.
#   2) Get software updates directly from the Internet (might be expensive!)
#   3) Get software updates from a custom network path that I will provide.
#   4) Quit - I don't want to get any software updates at this time.
# Please press the 1, 2, 3, or 4 key, or hit any key to abort - countdown 60
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#    If no response is given within 60 seconds, 4) Quit ... is automatically selected
#    and the script will end without getting any software updates.
# 7. Depending on the user's choice above, ensures that the user's /etc/apt/mirror.list
#    file and the /media/$USER/<DISK_LABEL>/wasta-offline/apt-mirror/var/postmirror* script 
#    files are configured properly to get software mirror updates from the user's
#    selected source for obtaining the software updates: the Internet, a local 
#    Ukarumpa network server, or a custom URL network path supplied by the user.
# 8. Calls the apt-mirror program to download software updates to the full mirror.
#    After fetching the software updates, the apt-mirror program itself calls the
#    postmirror.sh script (which may at the user's option call postmirror2.sh) to tidy 
#    up the updated software mirror.
# 9. If there is a local /data/master/wasta-offline/apt-mirror directory, 
#    $UPDATINGLOCALDATA="YES" and update-mirror.sh will first update the local master 
#    wasta-offline mirror. If an external USB drive with a wasta-offline mirror on it
#    is plugged in, $UPDATINGEXTUSBDATA="YES" and update-mirror.sh will ALSO 
#    conveniently call the sync_Wasta-Offline_to_Ext_Drive.sh script to synchronize 
#    the external USB drive's mirror to be identical with the newly updated master 
#    copy of the mirror.
#
# Usage: 
#   Automatic: bash update-mirror.sh - or, use the File Manager to navigate to the
#      master mirror or external USB drive containing the Full Wasta-Offline Mirror.
#      If the external USB drive is formatted with Linux partition(s), double-click 
#      on the update-mirror.sh and select "Run in Terminal" to start the script running
#      from the USB drive.
#      If the external USB drive is formatted as NTFS or FAT32, and the update-mirror.sh
#      script is only available there, you must first copy the scripts from the NTFS/FAT32 
#      formatted drive over to the Linux computer them from from the Linux computer as
#      described above.
#   Manual: Can be run manually with the following invocation and optional parameters: 
#      bash update-mirror.sh <path-prefix>
#      <path-prefix> option: a different http://... or ftp://... URL address may be 
#      given in the parameter representing the URL location of the source mirror to
#      copy FROM. 
#   Requires sudo/root privileges - password requested at run-time.


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

echo "SUDO_USER is: $SUDO_USER"

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
UPDATEMIRRORSCRIPT="update-mirror.sh"
APTMIRROR="apt-mirror"
DATADIR="/data"
MASTERDIR="/master"
APTMIRRORDIR="/$APTMIRROR" # /apt-mirror
WASTAOFFLINE="wasta-offline"
WASTAOFFLINEDIR="/wasta-offline"
WASTAOFFLINELOCALAPTMIRRORPATH=$DATADIR$MASTERDIR$WASTAOFFLINEDIR$APTMIRRORDIR # /data/master/wasta-offline/apt-mirror
LOCALMIRRORSPATH=$WASTAOFFLINELOCALAPTMIRRORPATH # default to $WASTAOFFLINELOCALAPTMIRRORPATH above [may be changed below]
MIRRORLIST="mirror.list"
SOURCESLIST="sources.list"
ETCAPT="/etc/apt/"
MIRRORLISTPATH=$ETCAPT$MIRRORLIST # /etc/apt/mirror.list
SAVEEXT=".save" # used in generate_mirror_list_file () function
APTMIRRORSETUPDIR="/apt-mirror-setup"
POSTMIRRORSCRIPT="postmirror.sh"
POSTMIRROR2SCRIPT="postmirror2.sh"
SYNCWASTAOFFLINESCRIPT="sync_Wasta-Offline_to_Ext_Drive.sh"
FTP="ftp"
WAIT=60
BILLSWASTADOCSDIR="/bills-wasta-docs"
GITIGNORE=".gitignore"
GENERATEDSIGNATURE="###_This_file_was_generated_by_the_update-mirror.sh_script_###"
# The OLD SIL Ukarumpa FTP site's URL was:
#FTPUkarumpaURLPrefix="ftp://ftp.sil.org.pg/Software/CTS/Supported_Software/Ubuntu_Repository/mirror/"
# Use the NEW Ukarumpa linuxrepo server's URL:
UkarumpaURLPrefix="http://linuxrepo.sil.org.pg/mirror/"
# The above UkarumpaURL may be overridden if the user invokes this script manually and uses a
# different URL in a parameter at invocation.
InternetURLPrefix="http://"
FTPURLPrefix="ftp://"
FileURLPrefix="file:"
VARDIR="/var"
UPDATINGLOCALDATA="YES" # [may be changed below]
UPDATINGEXTUSBDATA="YES" # [may be changed below]

echo -e "\n[*** Now executing the $UPDATEMIRRORSCRIPT script ***]"
sleep 3s

# Use the get_wasta_offline_usb_mount_point () function to get a value for USBMOUNTPOINT
USBMOUNTPOINT=`get_wasta_offline_usb_mount_point` # normally USBMOUNTPOINT is /media/$USER/<DISK_LABEL>/wasta-offline

if [ "x$USBMOUNTPOINT" = "x" ]; then
  # $USBMOUNTPOINT for a USB drive containing the wasta-offline data was not found
  USBMOUNTDIR=""
  WASTAOFFLINEEXTERNALAPTMIRRORPATH=""
  UPDATINGEXTUSBDATA="NO"
  # The $USBMOUNTPOINT variable is empty, i.e., a wasta-offline subdirectory on /media/... was not found
  echo -e "\nWasta-Offline data was NOT found at /media/..."
else
  USBMOUNTDIR=$USBMOUNTPOINT # normally USBMOUNTPOINT is /media/<DISK_LABEL>/wasta-offline or /media/$USER/<DISK_LABEL>/wasta-offline
  WASTAOFFLINEEXTERNALAPTMIRRORPATH=$USBMOUNTDIR$APTMIRRORDIR # /media/$USER/<DISK_LABEL>/wasta-offline/apt-mirror
  UPDATINGEXTUSBDATA="YES"
  echo -e "\nWasta-Offline data found at mount point: $USBMOUNTPOINT"
  USBDEVICENAME=`get_device_name_of_usb_mount_point $USBMOUNTPOINT`
  echo "Device Name of USB at $USBMOUNTPOINT: $USBDEVICENAME"
  USBFILESYSTEMTYPE=`get_file_system_type_of_usb_partition $USBDEVICENAME`
  echo "File system TYPE of USB Drive at $USBDEVICENAME: $USBFILESYSTEMTYPE"
fi
sleep 3s

CURRDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#echo "Some calculated variable values (useful for debugging):"
#echo "   USBMOUNTPOINT: $USBMOUNTPOINT"
#echo "   USBMOUNTDIR: $USBMOUNTDIR"
#echo "   WASTAOFFLINEEXTERNALAPTMIRRORPATH: $WASTAOFFLINEEXTERNALAPTMIRRORPATH"
#echo "   WASTAOFFLINELOCALAPTMIRRORPATH: $WASTAOFFLINELOCALAPTMIRRORPATH"
#echo "   LOCALMIRRORSPATH: $LOCALMIRRORSPATH"
#echo "   "
#sleep 3s

# ------------------------------------------------------------------------------
# Main program starts here
# ------------------------------------------------------------------------------

# the second USB drive with modified suffix added to the USB drive's label name - something
# like "UPDATES1" or "UPDATES_" - with a number or underscore character suffixed. 
# These scripts will only detect the mount point of the first USB drive inserted having a
# Wasta-Offline mirror. Any second or additional USB drives mounted with the same disk label
# name will be ignored. 

# If neither a local master mirror nor a USB drive with the full mirror is found notify
# the user of the problem and abort, otherwise continue.
if [ -d $WASTAOFFLINELOCALAPTMIRRORPATH ]; then
  LOCALMIRRORSPATH=$WASTAOFFLINELOCALAPTMIRRORPATH # /data/master/wasta-offline/apt-mirror
  LOCALBASEDIR=$DATADIR$MASTERDIR # /data/master
  UPDATINGLOCALDATA="YES"
else
  if [ "x$WASTAOFFLINEEXTERNALAPTMIRRORPATH" = "x" ]; then
    echo -e "\n****** WARNING ******"
    echo "A USB drive with wasta-offline data was not found."
    echo "Cannot update Wasta-Offline Mirror."
    echo "****** WARNING ******"
    echo "Aborting..."
    exit 1
  fi
  LOCALMIRRORSPATH=$WASTAOFFLINEEXTERNALAPTMIRRORPATH # /media/$USER/<DISK_LABEL>/wasta-offline/apt-mirror
  LOCALBASEDIR=$USBMOUNTDIR # /media/$USER/<DISK_LABEL>
  UPDATINGLOCALDATA="NO"
fi

# Check for the postmirror.sh and postmirror2.sh scripts that are needed for this script.
# These postmirror scripts should exist in a subfolder called apt-mirror-setup in the
# $CURRDIR (the directory in which this script is running). Warn user if the scripts are
# not found.
# Check for existence of postmirror.sh in $CURRDIR$APTMIRRORSETUPDIR
if [ ! -f $CURRDIR$APTMIRRORSETUPDIR/$POSTMIRRORSCRIPT ]; then
  echo -e "\n****** WARNING ******"
  echo "The $POSTMIRRORSCRIPT file was not found. It should be at:"
  echo "  $CURRDIR$APTMIRRORSETUPDIR/$POSTMIRRORSCRIPT"
  echo "  in the $APTMIRRORSETUPDIR subfolder of the $CURRDIR directory."
  echo "Cannot continue $UPDATEMIRRORSCRIPT processing! Please try again..."
  echo "****** WARNING ******"
  echo "Aborting..."
  exit 1
fi
# Check for existence of postmirror2.sh in $CURRDIR$/APTMIRRORSETUPDIR
if [ ! -f $CURRDIR$APTMIRRORSETUPDIR/$POSTMIRROR2SCRIPT ]; then
  echo -e "\n****** WARNING ******"
  echo "The $POSTMIRROR2SCRIPT file was not found. It should be at:"
  echo "  $CURRDIR$APTMIRRORSETUPDIR/$POSTMIRROR2SCRIPT"
  echo "  in the $APTMIRRORSETUPDIR subfolder of the $CURRDIR directory."
  echo "Cannot continue $UPDATEMIRRORSCRIPT processing! Please try again..."
  echo "****** WARNING ******"
  echo "Aborting..."
  exit 1
fi

echo -e "\nCurrent working directory is: $CURRDIR"
echo "Mirror to receive updates is: $LOCALMIRRORSPATH"
echo "Base dir to receive wasta-scripts updates is: $LOCALBASEDIR"
echo -e "\nAre we updating the master copy of the mirror? $UPDATINGLOCALDATA"
sleep 2s
echo "Are we updating a portable USB drive's mirror? $UPDATINGEXTUSBDATA"

# Ensure the postmirror.sh and postmirror2.sh scripts are freshly copied from the
# $CURRDIR/apt-mirror-setup folder to the $CURRDIR/wasta-offline/apt-mirror/var folder,
# but only if there is a wasta-offline directory in $CURRDIR. There will be a wasta-offline
# dir if the user is running this script from either the master mirror at /data/master or
# from a mirror on the external drive at /media/$USER/<DISK_LABEL>
if [ -d $CURRDIR$WASTAOFFLINEDIR ]; then

  echo -e "\nCopying postmirror*.sh files to:"
  echo "   $CURRDIR$WASTAOFFLINEDIR$APTMIRRORDIR$VARDIR..."
  # Here is the main rsync command. The rsync options are:
  #   -a archive mode (recurses thru dirs, preserves symlinks, permissions, times, group, owner)
  #   -v verbose
  #   -z compress file data during transfer
  #   --progress show progress during transfer
  #   --update overwrite only if file is newer than existing file
  # TODO: Adjust rsync command to use options: -rvh --size-only --progress
  # if destination USB drive is not Linux ext4 (ntfs)
  rsync -avzq --progress --update $CURRDIR$APTMIRRORSETUPDIR/*.sh $CURRDIR$WASTAOFFLINEDIR$APTMIRRORDIR$VARDIR
  # Ensure that postmirror.sh and postmirror2.sh scripts are executable for everyone.
  chmod ugo+rwx $CURRDIR$WASTAOFFLINEDIR$APTMIRRORDIR$VARDIR/*.sh
fi

# Check and ensure that wasta-offline is installed. This may not be the
# case initially for some users especially if they installed a custom mint 
# OS before wasta-linux was fully developed, or otherwise don't have
# wasta-offline installed. 
# Since this updata-mirror.sh script would normally be executed from a
# Linux partition (either an external USB drive formatted as a Linux Ext4 partition
# or from a directory on the master Linux computer), the latest wasta-offline debian 
# packages should be available in the root dir of master Linux computer or the
# external USB drive containing the Full Wasta-Offline Mirror, and hence 
# the appropriate wasta-offline deb package can be installed using dpkg without 
# needing to download one from the Internet.
#
if is_program_installed $WASTAOFFLINE ; then
  echo -e "\n$WASTAOFFLINE is already installed on this computer."
else
  # Get the LTS version number, 12.04, 14.04, 16.04 or 18.04 in order to select the
  # appropriate wasta-offline deb file for possible installation
  LTSVERNUM="UNKNOWN"
  CODENAME=`lsb_release --short --codename`
  # Get the LTS version number from the codenames
  case "$CODENAME" in
#    "precise")
#        LTSVERNUM="12.04"
#        ;;
#    "maya")
#        LTSVERNUM="12.04"
#        ;;
    "trusty")
        LTSVERNUM="14.04"
        ;;
    "qiana")
        LTSVERNUM="14.04"
        ;;
    "rebecca")
        LTSVERNUM="14.04"
        ;;
    "rafaela")
        LTSVERNUM="14.04"
        ;;
    "rosa")
        LTSVERNUM="14.04"
        ;;
    "xenial")
        LTSVERNUM="16.04"
        ;;
    "sarah")
        LTSVERNUM="16.04"
        ;;
    "serena")
        LTSVERNUM="16.04"
        ;;
    "sonya")
        LTSVERNUM="16.04"
        ;;
    "sylvia")
        LTSVERNUM="16.04"
        ;;
    "bionic")
        LTSVERNUM="18.04"
        ;;
    "tara")
        LTSVERNUM="18.04"
        ;;
    "tessa")
        LTSVERNUM="18.04"
        ;;
     *)
        LTSVERNUM="UNKNOWN"
        ;;
  esac
  echo -e "\nCodename is: $CODENAME LTS Version is: $LTSVERNUM"

  # Use dpkg to install the wasta-offline package
  echo "Find string: $CURRDIR/$WASTAOFFLINE*$LTSVERNUM*.deb"
  DEB=`find $CURRDIR/$WASTAOFFLINE*$LTSVERNUM*.deb`
  if [ "x$DEB" = "x" ]; then
    echo "Cannot install wasta-offline. A local deb package was not found."
    echo "You will need to install wasta-offline before you can use the mirror."
  else
    echo "Installing $WASTAOFFLINE via: dpkg -i $DEB"
    dpkg -i $DEB
  fi 
fi

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

# Here is the main menu:
# Query the user where to get software updates: from the Internet or from the SIL Ukarumpa local server.
# The prompt counts down from 60 to 0 at which time it selects 4) unless user selects differently.
echo -e "\nMAIN MENU:"
echo "*******************************************************************************"
echo "Where should the Wasta-Offline Mirror get its software updates?"
echo "  1) Get software updates from the SIL Ukarumpa local server."
echo "  2) Get software updates directly from the Internet (might be expensive!)"
echo "  3) Get software updates from a custom network path that I will provide."
echo "  4) Quit - I don't want to get any software updates at this time."
echo "*******************************************************************************"
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
    # ping the Ukarumpa server to check for server access - can leave off final / here
    ping -c1 -q http://linuxrepo.sil.org.pg/mirror
    if [ "$?" != 0 ]; then
      echo -e "\n****** WARNING ******"
      echo "Access to the http://linuxrepo.sil.org.pg/mirror server is not available."
      echo "This script cannot run without access to the SIL server."
      echo "Make sure the computer has access to the server, then try again."
      echo "****** WARNING ******"
      echo "Aborting..."
      exit 1
    else
      echo -e "\nAccess to the http://linuxrepo.sil.org.pg/mirror server appears to be available!"
      # First, ensure that apt-mirror is installed
      if smart_install_program $APTMIRROR -q ; then
        # The apt-mirror program is installed
        echo -e "\nThe $APTMIRROR program is installed"
        # Create a custom mirror.list config file for this option
        if generate_mirror_list_file $UkarumpaURLPrefix ; then
          echo "Successfully generated $MIRRORLIST at $MIRRORLISTPATH."
        else
          echo -e "\n****** WARNING ******"
          echo "Error: Could not generate $MIRRORLIST at $MIRRORLISTPATH."
          echo "****** WARNING ******"
          echo "Aborting..."
          exit $LASTERRORLEVEL
        fi
        echo -e "\n"
        echo "*******************************************************************************"
        echo "Calling apt-mirror - getting data from local Ukarumpa site"
        echo "  URL Prefix: $UkarumpaURLPrefix"
        echo "*******************************************************************************"
        echo -e "\n"
        # Note: For this option, the user's /etc/apt/mirror.list file now points to repositories with 
        # this path prefix:
        # http://linuxrepo.sil.org.pg/mirror/..."
        sleep 3s
        
        apt-mirror
      
        LASTERRORLEVEL=$?
        if [ $LASTERRORLEVEL != 0 ]; then
          echo -e "\n****** WARNING ******"
          echo "The apt-mirror program failed!"
          echo "The error code from apt-mirror was: $LASTERRORLEVEL"
          echo "You might do these checks:"
          echo "   Look through the console output above to check for specific errors."
          echo "   Check the generated file mirror.list at /etc/apt/mirror.list for errors."
          echo "   If a repository on the Ukarumpa network didn't respond, try again later."
          echo "If you get a script error, please report it to bill_martin@sil.org"
          echo "****** WARNING ******"
          echo "Aborting..."
          return $LASTERRORLEVEL
        fi
        
        # Note: Before apt-mirror finishes it will call postmirror.sh to clean the mirror and 
        # optionally call postmirror2.sh to correct any Hash Sum mismatches.
        # Ensure that ownership of the mirror tree is apt-mirror:apt-mirror (otherwise cron won't run) 
        # The $LOCALMIRRORSPATH is determined near the main beginning of this script
        echo "Make $LOCALMIRRORSPATH owner be $APTMIRROR:$APTMIRROR"
        chown -R $APTMIRROR:$APTMIRROR $LOCALMIRRORSPATH # chown -R apt-mirror:apt-mirror /media/$USER/<DISK_LABEL>/wasta-offline/apt-mirror
        
        # If apt-mirror updated the master local mirror (at /data/master/wasta-offline/...), then sync 
        # it to the external USB mirror.
        if [ "$UPDATINGLOCALDATA" = "YES" ]; then
          # Call sync_Wasta_Offline_to_Ext_Drive.sh without any parameters: 
          #   the $COPYFROMDIR will be /data/master/wasta-offline/
          #   the $COPYTODIR will be /media/$USER/<DISK_LABEL>/wasta-offline
          bash $DIR/$SYNCWASTAOFFLINESCRIPT
        fi
      else
        echo -e "\n****** WARNING ******"
        echo "Error: Could not install $APTMIRROR."
        echo "****** WARNING ******"
        echo "Aborting..."
        exit $LASTERRORLEVEL
      fi
    fi
   ;;
  "2")
    # Check if the full wasta-offline mirror is running and plugged in - we can install apt-mirror from it
    echo -e "\n"
    if is_program_running $WASTAOFFLINE ; then
      echo "$WASTAOFFLINE is running"
      # Check if it's the full wasta-offline USB mirror that is plugged in
      if is_dir_available $WASTAOFFLINEEXTERNALAPTMIRRORPATH ; then  # /media/$USER/<DISK_LABEL>/wasta-offline/apt-mirror
        echo "Full Wasta-Offline mirror is plugged in"
        # Go ahead and install the apt-mirror program
        if smart_install_program $APTMIRROR -q ; then
          # The apt-mirror program is installed
          echo -e "\nThe $APTMIRROR program is installed"
        else
          # We cannot continue if apt-mirror is not/cannot be installed
          echo -e "\n****** WARNING ******"
          echo "Error: Could not install $APTMIRROR."
          echo "****** WARNING ******"
          echo "Aborting..."
          exit $LASTERRORLEVEL
        fi
      fi
    else
      echo "$WASTAOFFLINE is not in use - checking for Internet access"
    fi
    # ping the Internet to check for Internet access to www.archive.ubuntu.com
    ping -c1 -q www.archive.ubuntu.com
    if [ "$?" != 0 ]; then
      echo -e "\n****** WARNING ******"
      echo -"Internet access to www.archive.ubuntu.com not currently available."
      echo "This script cannot continue without access to the Internet."
      echo "Make sure the computer has access to the Internet, then try again."
      echo "Or, alternately, run wasta-offline and install software without Internet access"
      echo "****** WARNING ******"
      echo "Aborting..."
      exit 1
    else
      echo -e "\nInternet access to www.archive.ubuntu.com appears to be available!"
      # First, ensure that apt-mirror is installed
      if smart_install_program $APTMIRROR -q ; then
        # The apt-mirror program is installed
        echo "The $APTMIRROR program is installed"
      else
        # We cannot continue if apt-mirror is not/cannot be installed
        echo -e "\n****** WARNING ******"
        echo "Error: Could not install $APTMIRROR."
        echo "****** WARNING ******"
        echo "Aborting..."
        exit $LASTERRORLEVEL
      fi
      # Create a custom mirror.list config file for this option
      if generate_mirror_list_file $InternetURLPrefix ; then
        echo "Successfully generated $MIRRORLIST at $MIRRORLISTPATH."
      else
        echo -e "\n****** WARNING ******"
        echo "Error: Could not generate $MIRRORLIST at $MIRRORLISTPATH. Aborting..."
        echo "****** WARNING ******"
        echo "Aborting..."
        exit $LASTERRORLEVEL
      fi
      echo -e "\n"
      echo "*******************************************************************************"
      echo "Calling apt-mirror - getting data from Internet"
      echo "  URL Prefix: $InternetURLPrefix"
      echo "*******************************************************************************"
      echo -e "\n"
      # Note: For this option, the user's /etc/apt/mirror.list file now points to repositories with this path prefix:
      # http://..."
      sleep 3s
        
      apt-mirror
    
      LASTERRORLEVEL=$?
      if [ $LASTERRORLEVEL != 0 ]; then
        echo -e "\n****** WARNING ******"
        echo "The apt-mirror program failed!"
        echo "The error code from apt-mirror was: $LASTERRORLEVEL"
        echo "You might do these checks:"
        echo "   Look through the console output above to check for specific errors."
        echo "   Check the generated file mirror.list at /etc/apt/mirror.list for errors."
        echo "   If a Linux repository on the Internet didn't respond, try again later."
        echo "If you get a script error, please report it to bill_martin@sil.org"
        echo "****** WARNING ******"
        echo "Aborting..."
        return $LASTERRORLEVEL
      fi
        
      # Note: Before apt-mirror finishes it will call postmirror.sh to clean the mirror and 
      # optionally call postmirror2.sh to correct any Hash Sum mismatches.
      
      # whm added code below to update the wasta-scripts and bills-wasta-docs repos
      # Make sure git is installed
      if smart_install_program "git" -q ; then
        # The git program is installed
        echo "The git program is installed"
      else
        # We cannot continue if git is not/cannot be installed
        echo -e "\n****** WARNING ******"
        echo "Error: Could not install git."
        echo "****** WARNING ******"
        echo "Aborting..."
        exit $LASTERRORLEVEL
      fi
      # Update latest git repos for wasta-scripts and bills-wasta-docs
      echo -e "\n"
      echo "The LOCALBASEDIR is: $LOCALBASEDIR"
      cd $LOCALBASEDIR
      if [ -d ".git" ]; then
        echo "The local wasta-scripts repo .git file exists"
        echo "Pull in any updates"
        git pull
        chown $SUDO_USER:$SUDO_USER *.sh
        chown $SUDO_USER:$SUDO_USER ReadMe
      else
        echo "No local wasta-scripts repo .git file exists"
        echo "Clone the wasta-scripts repo to tmp"
        git clone https://github.com/pngbill-scripts/wasta-scripts.git tmp
        echo "Move the .git folder to current folder"
        mv tmp/.git .
        echo "Remove the tmp folder"
        rm -rf tmp
        echo "Get wasta-scripts repo updates"
        git reset --hard
        chown $SUDO_USER:$SUDO_USER *.sh
        chown $SUDO_USER:$SUDO_USER ReadMe
      fi
      echo "Create a .gitignore file for wasta-scripts"
      # User heredoc to create a .gitignore file with content below
cat > $GITIGNORE <<EOF
.Trash-1000/
bills-wasta-docs/
wasta-offline/
wasta-offline_1.*.deb
wasta-offline_2.*.deb
wasta-offline-setup_1.*.deb
docs-index
.gitignore
EOF
      chown $SUDO_USER:$SUDO_USER $GITIGNORE
      echo "The BILLSWASTADOCS path is: $LOCALBASEDIR$BILLSWASTADOCSDIR"
      if [ -d $LOCALBASEDIR$BILLSWASTADOCSDIR ]; then
        echo "The BILLSWASTADOCS dir exists"
        cd $LOCALBASEDIR$BILLSWASTADOCSDIR
        git pull
        chown -R $SUDO_USER:$SUDO_USER $LOCALBASEDIR$BILLSWASTADOCSDIR
      else
        git clone https://github.com/pngbill-scripts/bills-wasta-docs.git
        chown -R $SUDO_USER:$SUDO_USER $LOCALBASEDIR$BILLSWASTADOCSDIR
      fi
      # No need for a .gitignore file in bills-wasta-docs repo
      
      echo "Change back to $CURRDIR"
      cd $CURRDIR
      
      # The $LOCALMIRRORSPATH is determined near the main beginning of this script
      echo "Make $LOCALMIRRORSPATH owner be $APTMIRROR:$APTMIRROR"
      chown -R $APTMIRROR:$APTMIRROR $LOCALMIRRORSPATH # chown -R apt-mirror:apt-mirror /media/$USER/<DISK_LABEL>/wasta-offline/apt-mirror
      # If apt-mirror updated the master local mirror (at /data/master/wasta-offline/...), then sync 
      # it to the external USB mirror.
      if [ "$UPDATINGLOCALDATA" = "YES" ]; then
        # Call sync_Wasta_Offline_to_Ext_Drive.sh without any parameters: 
        #   the $COPYFROMDIR will be /data/master/wasta-offline/
        #   the $COPYTODIR will be /media/$USER/<DISK_LABEL>/wasta-offline
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
          echo -e "\n****** WARNING ******"
          echo "Cannot access the $CustomURLPrefix server!"
          echo "Cannot get apt-mirror updates without access to the appropriate server."
          echo "Make sure the computer has access to the server, and determine the exact"
          echo "URL prefix to the mirror directory on the server, then try 3) again -"
          echo "Or, use one of the other menu selections 1) or 2) to get software updates."
          echo "****** WARNING ******"
          echo "Aborting..."
          exit 1
        else
          echo -e "\nAccess to the $CustomURLPrefix server appears to be available!"
          # Create a custom mirror.list config file for this option
          if generate_mirror_list_file $CustomURLPrefix ; then
            echo "Successfully generated $MIRRORLIST at $MIRRORLISTPATH."
          else
            echo -e "\nError: Could not generate $MIRRORLIST at $MIRRORLISTPATH. Aborting..."
            exit $LASTERRORLEVEL
          fi
          echo -e "\n"
          echo "*******************************************************************************"
          echo "Calling apt-mirror - getting data from custom server site"
          echo "  URL Prefix: $CustomURLPrefix"
          echo "*******************************************************************************"
          echo -e "\n"
          # Note: For this option, the user's /etc/apt/mirror.list file now points to repositories with this path prefix:
          # "$CustomURLPrefix..."
          sleep 3s
      
          apt-mirror
      
          LASTERRORLEVEL=$?
          if [ $LASTERRORLEVEL != 0 ]; then
            echo -e "\n****** WARNING ******"
            echo "The apt-mirror program failed!"
            echo "The error code from apt-mirror was: $LASTERRORLEVEL"
            echo "You might do these checks:"
            echo "   Look through the console output above to check for specific errors."
            echo "   Check the generated file mirror.list at /etc/apt/mirror.list for errors"
            echo "     and ensure that all mirror.list repositories are in your network path."
            echo "   If a Linux repository didn't respond, try again later."
            echo "If you get a script error, please report it to bill_martin@sil.org"
            echo "****** WARNING ******"
            echo "Aborting..."
            return $LASTERRORLEVEL
          fi
        
          # Note: Before apt-mirror finishes it will call postmirror.sh to clean the mirror and 
          # optionally call postmirror2.sh to correct any Hash Sum mismatches.
          # The $LOCALMIRRORSPATH is determined near the main beginning of this script
          echo "Make $LOCALMIRRORSPATH owner be $APTMIRROR:$APTMIRROR"
          chown -R $APTMIRROR:$APTMIRROR $LOCALMIRRORSPATH # chown -R apt-mirror:apt-mirror /media/$USER/<DISK_LABEL>/wasta-offline/apt-mirror
          # If apt-mirror updated the master local mirror (at /data/master/wasta-offline/...), then sync 
          # it to the external USB mirror.
          if [ "$UPDATINGLOCALDATA" = "YES" ]; then
            # Call sync_Wasta_Offline_to_Ext_Drive.sh without any parameters: 
            #   the $COPYFROMDIR will be /data/master/wasta-offline/
            #   the $COPYTODIR will be /media/$USER/<DISK_LABEL>/wasta-offline
            bash $DIR/$SYNCWASTAOFFLINESCRIPT
          fi
        fi
      else
        # User didn't type anything - abort
        echo -e "\n****** WARNING ******"
        echo "No URL prefix was entered..."
        echo "Cannot get apt-mirror updates without access to the appropriate server."
        echo "Make sure the computer has access to the server, and determine the exact"
        echo "URL prefix to the mirror directory on the server, then try 3) again -"
        echo "Or, use one of the other menu selections 1) or 2) to get software updates."
        echo "****** WARNING ******"
        echo "Aborting..."
        exit 1
      fi
   ;;
  "4")
    echo -e "\nThe $APTMIRROR program was not called. The $UPDATEMIRRORSCRIPT script completed."
    exit 0
   ;;
  *)
    echo -e "\nUnrecognized response. Aborting..."
    echo "Aborting..."
    exit 1
  ;;
esac
echo -e "\nThe $UPDATEMIRRORSCRIPT script has finished."

