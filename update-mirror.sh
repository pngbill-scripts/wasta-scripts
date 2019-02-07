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
#      Used a new get_file_system_type_of_partition () function to determine
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
# and automatically configuring the computer's apt-mirror mirror.list configuration  
# file (at: /etc/apt/mirror.list) depending on the user's choice of sources (from 
# a menu) for such apt-mirror updates.
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
# Wasta-Offline USB drive are being maintained, it is more efficient to use this script to
# update the master mirror from the Local server or Internet repositories, and then sync 
# from that master mirror to any external USB mirror that is attached to the system,
# removing the update USB drive and attaching another USB drive, and calling the 
# sync_Wasta-Offline_to_Ext_Drive.sh script for each additional USB drive mirror that needs
# updating.
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
# Usage: TODO: Revise below probably disallowing use of a <path-prefix> option
#
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

#echo "SUDO_USER is: $SUDO_USER"

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
UPDATEMIRRORSCRIPT="update-mirror.sh"
APTMIRROR="apt-mirror"
DATADIR="/data"
MASTERDIR="/master"
APTMIRRORDIR="/$APTMIRROR" # /apt-mirror
WASTAOFFLINE="wasta-offline"
WASTAOFFLINEDIR="/wasta-offline"
WASTAOFFLINELOCALDIR=$DATADIR$MASTERDIR$WASTAOFFLINEDIR # /data/master/wasta-offline
WASTAOFFLINELOCALAPTMIRRORPATH=$DATADIR$MASTERDIR$WASTAOFFLINEDIR$APTMIRRORDIR # default to /data/master/wasta-offline/apt-mirror
LOCALMIRRORSPATH=$WASTAOFFLINELOCALAPTMIRRORPATH # default to $WASTAOFFLINELOCALAPTMIRRORPATH above [may be changed below]
ROOT_DIRECTORY_OF_MASTER=$DATADIR # default to /data
LOCALBASEDIR=$DATADIR$MASTERDIR # default to /data/master
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

# ------------------------------------------------------------------------------
# Main program starts here
# ------------------------------------------------------------------------------

echo -e "\n[*** Now executing the $UPDATEMIRRORSCRIPT script ***]"
sleep 3s

# Get information about the master mirror if it exists. If a master mirror
# exists, we need to verify its location on the local computer, and also we would
# like to verify its file system type by determining the "root" directory of its
# location path, and from that its file system type.
# Normally the file system type for a master mirror on a Linux computer would be
# Ext4 (or possibly Ext3 or Ext2), but we want to verify that in order to use the
# appropriate -avh or -rvh rsync options when copying the postmirror.sh and 
# postmirror2.sh scripts to the .../var directory where apt-mirror will look for them.

# See if there is a full master mirror at the default location /data/master/wasta-offline
if is_there_a_wasta_offline_mirror_at $WASTAOFFLINELOCALDIR ; then
  # We found a full wasta-offline mirror at the default location
  MASTER_MIRROR_FOUND="TRUE"
  UPDATINGLOCALDATA="YES"
  # This variable remains set to its initial default (set above): $WASTAOFFLINELOCALAPTMIRRORPATH
  # This variable remains set to its initial default (set above): $LOCALMIRRORSPATH
  # This variable remains set to its initial default (set above): $LOCALBASEDIR
else
  MASTER_MIRROR_FOUND="FALSE" # may be changed below
  UPDATINGLOCALDATA="NO" # may be changed below
  # It is possible that an apt-mirror maintained wasta-offline mirror exists elsewhere
  # on the local computer other than at the default location /data/master/wasta-offline.
  # If one exists, it should be set by the base_path variable of a mirror.list file.
  # Get the BASEPATH_TO_MIRROR and ROOT_DIRECTORY_OF_MASTER if a mirror.list file exists.
  # The base_path would most likely be:
  #   /data/master/wasta-offline/apt-mirror, if mirror.list it exists, or possibly
  #   /media/<User-Name>/<DISK_LABEL>/wasta-offline/apt-mirror (see below), or
  #   an empty string if the mirror.list file doesn't exist.
  BASEPATH_FROM_MIRROR_LIST=`get_base_path_of_mirror_list_file` # expect default of /data/master/wasta-offline/apt-mirror
  if [[ "x$BASEPATH_FROM_MIRROR_LIST" = "x" ]]; then
    # No base_path exists, probably because no mirror.list exists, but check for a mirror
    # at the default location of /data/master/wasta-offline
    MASTER_MIRROR_FOUND="FALSE" # may be changed below
    UPDATINGLOCALDATA="NO" # may be changed below
  else
    # Found a mirror.list set base_path, which most likely will be either:
    # /data/master/wasta-offline/apt-mirror or possibly /media/<User-Name>/<DISK_LABEL>/wasta-offline/apt-mirror.
    # A base path at /data/master/wasta-offline/apt-mirror is the default location if
    # an administrator set up the master mirror using the make_Master_for_Wasta-Offline.sh
    # script.
    # The presence of a mirror.list file containing a base_path setting, doesn't mean
    # that an actual mirror exists at the location of the base_path.
    # So we need to check if there is an actual full mirror at the specified location.
    # Get some paths based on the extracted base_path value:
    # Extract a base path up to the apt-mirror directory (BASEPATH_TO_APT_MIRROR):
    BASEPATH_TO_APT_MIRROR=${BASEPATH_FROM_MIRROR_LIST%/wasta-offline/apt-mirror/*} # /data/master/wasta-offline
    # Use $BASEPATH_TO_APT_MIRROR to see if there is an actual full mirror at that location:
    if is_there_a_wasta_offline_mirror_at $BASEPATH_TO_APT_MIRROR ; then
      # Extract a base path up to the wasta-offline directory (BASEPATH_TO_MIRROR):
      BASEPATH_TO_MIRROR=${BASEPATH_FROM_MIRROR_LIST%/wasta-offline/*} # /data/master
      # Extract a "root" directory ($ROOT_DIRECTORY_OF_MASTER) from the BASEPATH_FROM_MIRROR_LIST. 
      ROOT_DIRECTORY_OF_MASTER="/"$(echo "$BASEPATH_TO_MIRROR" | cut -d "/" -f2)
    
      # If the full mirror exists and its "root" directory is NOT "/media"
      # then we proceed with confidence that we've found the master mirror.
  
      if [[ "x$ROOT_DIRECTORY_OF_MASTER" != "x" ]]; then
        if [[ "$ROOT_DIRECTORY_OF_MASTER" != "/media" ]]; then
          MASTER_MIRROR_FOUND="TRUE"
          UPDATINGLOCALDATA="YES"
          # Set some variables that point to the master mirror
          WASTAOFFLINELOCALAPTMIRRORPATH=$BASEPATH_FROM_MIRROR_LIST
          if [ -d "$WASTAOFFLINELOCALAPTMIRRORPATH" ]; then
            LOCALMIRRORSPATH=$WASTAOFFLINELOCALAPTMIRRORPATH # /data/master/wasta-offline/apt-mirror
            LOCALBASEDIR="$BASEPATH_TO_MIRROR"
          fi
          echo -e "\nFound a full wasta-offline mirror at: $BASEPATH_TO_APT_MIRROR"
          #echo "Debug: The root directory of the master mirror is: $ROOT_DIRECTORY_OF_MASTER"
        else
          # The "root" directly from the base_path is /media
          # A base_path at /media/... might be the case if an administrator had been using
          # the update-mirror.sh script to have apt-mirror directly update a USB drive's 
          # mirror (at /media/...) without having a master mirror present where this script 
          # is being called from. An administrator, of course, could have set up a master 
          # mirror apart from using the make_Master_for_Wasta-Offline.sh script to do so,
          # and in the process of doing so didn't reconfigure the mirror.list to have its 
          # base_path updated to the current master mirror (the make_Master... script
          # would have ensured that the base_path in mirror.list points to the actual master
          # mirror). While unlikely, we attempt to determine if a master mirror is actually
          # present at a different path on a fixed drive even while the mirror.list file 
          # says the base_path is at a /media/... location.
          # Use find to search from root / for a master mirror tree of the form 
          # /.../wasta-offline/apt-mirror/mirror/archive.ubuntu.com
          # find options:
          #   /  <-- start finding from root /
          #   -not -path "/media/*" ... <--this will exclude looking in dirs at /media/*, /bin/* ... etc (to speed up find)
          #   2>/dev/null <-- don't echo any error output
          #   -name "archive.ubuntu.com" <-- find this directory name
          # The pipe to grep ensures that any path returned has the form .../wasta-offline/apt-mirror/mirror/archive.ubuntu.com
          echo "Searching for a master mirror on this computer. This may take a while..."
          TEMP_PATH=$(find / -not -path "/media/*" -not -path "/bin/*" -not -path "/usr/*" -not -path "/tmp/*" \
          -not -path "/sys/*" -not -path "/proc/*" -not -path "/etc/*" -not -path "/lib*/*" \
          -not -path "/opt/*" -not -path "/run/*" -not -path "/root/*" -not -path "/dev/*" \
          -not -path "/var/*" -not -path "/sbin/*" -not -path "/boot/*" -not -path "/lost+found/*" \
          2>/dev/null -name "archive.ubuntu.com" | grep "/wasta-offline/apt-mirror/mirror/archive.ubuntu.com")
          #TEMP_PATH=$(find / -not -path "/media/*" 2>/dev/null -name "archive.ubuntu.com" | grep "/wasta-offline/apt-mirror/mirror/archive.ubuntu.com")
          if [ "x$TEMP_PATH" = "x" ]; then
            echo "No master mirror found."
          else
            # TODO: Need to test scenario below
            # Get the $BASEPATH_TO_MIRROR from TEMP_PATH, i.e., the first part of the path 
            # up to "/wasta-offline/apt-mirror/mirror/archive.ubuntu.com"
            # if TEMP_PATH is: /mydata/master/wasta-offline/apt-mirror/mirror/archive.canonical.com
            # the BASEPATH_TO_MIRROR would be /mydata/master, and the $ROOT_DIRECTORY_OF_MASTER would be /mydata
            # Also get the BASE_PATH_TO_APT_MIRROR from TEMP_PATH, i.e., the path up to the .../mirror/ dir
            BASE_PATH_TO_APT_MIRROR=${TEMP_PATH%/mirror/*} # /mydata/master/wasta-offline/apt-mirror
            echo "Debug: Base path up to /mirror/ dir is: $BASE_PATH_TO_APT_MIRROR"
            BASEPATH_TO_MIRROR=${TEMP_PATH%/wasta-offline/*} # /mydata/master
            echo "Debug: Base path to mirror dir is: $BASEPATH_TO_MIRROR"
            ROOT_DIRECTORY_OF_MASTER="/"$(echo "$BASEPATH_TO_MIRROR" | cut -d "/" -f2) # /mydata
            echo "Debug: The root directory of the master mirror is: $ROOT_DIRECTORY_OF_MASTER"
            MASTER_MIRROR_FOUND="TRUE"
            UPDATINGLOCALDATA="YES"
            echo "Found master mirror at: $BASEPATH_TO_MIRROR"
            WASTAOFFLINELOCALAPTMIRRORPATH=$BASEPATH_FROM_MIRROR_LIST
            if [ -d "$WASTAOFFLINELOCALAPTMIRRORPATH" ]; then
              LOCALMIRRORSPATH=$WASTAOFFLINELOCALAPTMIRRORPATH # /data/master/wasta-offline/apt-mirror
              LOCALBASEDIR="$BASEPATH_TO_MIRROR"
            fi
          fi
        fi
      else
        # The $ROOT_DIRECTORY_OF_MASTER is a blank string
        MASTER_MIRROR_FOUND="FALSE"
        UPDATINGLOCALDATA="NO"
      fi
    else
      # There is no full wasta-offline mirror at the base_path location; it may be a different mirror.
      MASTER_MIRROR_FOUND="FALSE"
      UPDATINGLOCALDATA="NO"
    fi
  fi
fi

# Use the get_wasta_offline_usb_mount_point () function to get a value for USBMOUNTPOINT, if it exists.
USBMOUNTPOINT=`get_wasta_offline_usb_mount_point` # normally USBMOUNTPOINT is /media/$USER/<DISK_LABEL>/wasta-offline

if [ "x$USBMOUNTPOINT" = "x" ]; then
  # $USBMOUNTPOINT for a USB drive containing the wasta-offline data was not found
  USBMOUNTDIR=""
  WASTAOFFLINEEXTERNALAPTMIRRORPATH=""
  UPDATINGEXTUSBDATA="NO"
  # The $USBMOUNTPOINT variable is empty, i.e., a wasta-offline subdirectory on /media/... was not found
  echo "Wasta-Offline data was NOT found on a USB drive."
else
  # The USBMOUNTDIR value should be the path up to, but not including /wasta-offline of $USBMOUNTPOINT
  USBMOUNTDIR=$USBMOUNTPOINT # normally USBMOUNTDIR is /media/$USER/<DISK_LABEL>
  if [[ "$USBMOUNTPOINT" == *"wasta-offline"* ]]; then 
    USBMOUNTDIR=$(dirname "$USBMOUNTPOINT")
  fi
  WASTAOFFLINEEXTERNALAPTMIRRORPATH=$USBMOUNTPOINT$APTMIRRORDIR # /media/$USER/<DISK_LABEL>/wasta-offline/apt-mirror
  UPDATINGEXTUSBDATA="YES"
  echo "Wasta-Offline data found on USB drive at: $USBMOUNTPOINT"
  USBDEVICENAME=`get_device_name_of_usb_mount_point "$USBMOUNTDIR"`
  #echo "Debug: Device Name of USB at $USBMOUNTDIR: $USBDEVICENAME"
  USBFILESYSTEMTYPE=`get_file_system_type_of_partition "$USBMOUNTDIR"`
  #echo "Debug: File system TYPE of USB Drive at $USBMOUNTDIR: $USBFILESYSTEMTYPE"
fi
sleep 3s

# NOTE: If a second USB drive is mounted with the same DISK_LABEL, the second USB drive  
# will get a modified suffix added to the USB drive's label name - something like
# "UPDATES1" or "UPDATES_" - with a number or underscore character suffixed to its DISK_LABEL. 
# This script will only detect the mount point of the first USB drive inserted having a
# Wasta-Offline mirror. Any second or additional USB drives mounted with the same DISK_LABEL
# name will be ignored. 

# If neither a local master mirror nor a USB drive with the full mirror is found notify
# the user of the problem and abort, otherwise continue.
if [[ "$UPDATINGLOCALDATA" == "NO" ]] && [[ "$UPDATINGEXTUSBDATA" == "NO" ]]; then
  echo -e "\n****** WARNING ******"
  echo "Could not find a local master mirror, nor a USB drive with a mirror to update."
  echo "You can plug in an existing full mirror on USB drive to be updated,"
  echo "or, if you want to create a master mirror, run the make_Master_for_Wasta-Offline.sh"
  echo "script instead of this script."
  echo "****** WARNING ******"
  echo "Aborting..."
  exit 1
fi

#echo "Debug: Some calculated variable values (useful for debugging):"
#echo "Debug:  USBMOUNTPOINT: $USBMOUNTPOINT"
#echo "Debug:  USBMOUNTDIR: $USBMOUNTDIR"
#echo "Debug:  WASTAOFFLINEEXTERNALAPTMIRRORPATH: $WASTAOFFLINEEXTERNALAPTMIRRORPATH"
#echo "Debug:  WASTAOFFLINELOCALAPTMIRRORPATH: $WASTAOFFLINELOCALAPTMIRRORPATH"
#echo "Debug:  LOCALMIRRORSPATH: $LOCALMIRRORSPATH"
#sleep 3s

# Check for the postmirror.sh and postmirror2.sh scripts that are needed for this script.
# These postmirror scripts should exist in a subfolder called apt-mirror-setup in the
# $LOCALBASEDIR. Warn user if the scripts are not found.
# Check for existence of postmirror.sh in $LOCALBASEDIR$APTMIRRORSETUPDIR
if [[ "$UPDATINGLOCALDATA" == "YES" ]]; then
  if [ ! -f "$LOCALBASEDIR$APTMIRRORSETUPDIR/$POSTMIRRORSCRIPT" ]; then
    echo -e "\n****** WARNING ******"
    echo "The $POSTMIRRORSCRIPT file was not found. It should be at:"
    echo "  $LOCALBASEDIR$APTMIRRORSETUPDIR/$POSTMIRRORSCRIPT"
    echo "  in the $APTMIRRORSETUPDIR subfolder of the $LOCALBASEDIR directory."
    echo "Cannot continue $UPDATEMIRRORSCRIPT processing! Please try again..."
    echo "****** WARNING ******"
    echo "Aborting..."
    exit 1
  fi
  # Check for existence of postmirror2.sh in $LOCALBASEDIR$/APTMIRRORSETUPDIR
  if [ ! -f "$LOCALBASEDIR$APTMIRRORSETUPDIR/$POSTMIRROR2SCRIPT" ]; then
    echo -e "\n****** WARNING ******"
    echo "The $POSTMIRROR2SCRIPT file was not found. It should be at:"
    echo "  $LOCALBASEDIR$APTMIRRORSETUPDIR/$POSTMIRROR2SCRIPT"
    echo "  in the $APTMIRRORSETUPDIR subfolder of the $LOCALBASEDIR directory."
    echo "Cannot continue $UPDATEMIRRORSCRIPT processing! Please try again..."
    echo "****** WARNING ******"
    echo "Aborting..."
    exit 1
  fi
fi

#echo "Debug: Mirror to receive updates is: $LOCALMIRRORSPATH"
#echo "Debug: Base dir to receive wasta-scripts updates is: $LOCALBASEDIR"
echo -e "\nAre we updating the master copy of the mirror? $UPDATINGLOCALDATA"
sleep 2s
echo "Are we updating a portable USB drive's mirror? $UPDATINGEXTUSBDATA"
sleep 2s

# There are 3 possible configurations to consider for rsync copying of the postmirror.sh and
# postmirror2.sh scripts from their apt-mirror-setup folder to the .../wasta-offline/apt-mirror/var
# destination:
#
# 1. No USB Drive is attached/mounted. In this case $USBMOUNTPOINT and $USBMOUNTDIR will both
# be empty strings. In this case there has to be a master mirror present to receive data or 
# the script aborts. In this configuration the update-mirror.sh script can only update the 
# master mirror, and:
#   $UPDATINGLOCALDATA will be "YES" 
#   $UPDATINGEXTUSBDATA will be "NO"
# Also, rsync's source root partition will be the same as the destination root partition - 
# and both will be of the same file system type, namely that of the master mirror's 
# partition on the dedicated computer.
#
# 2. A USB drive is attached/mounted, but there is NO master mirror available. In this case
# $USBMOUNTPOINT must be a valid path to a USB drive to receive the mirror data, and the
# script does not attempt to sync any data to a master mirror (nor does it try to create
# a master mirror). In this configuration the update-mirror.sh script can only update the
# USB drive's mirror with data, and:
#   $UPDATINGLOCALDATA will be "NO" 
#   $UPDATINGEXTUSBDATA will be "YES"
# Also, rsync's source root partition will be the same as the destination root partition -
# and both will be of the same file system type, namely that of the attached USB drive's 
# partition
#
# 3. A USB drive is attached/mounted, AND there is also a master mirror available. In this 
# case the master mirror will be the first to receive mirror updates, and once that process 
# is finished, this update-mirror.sh script calls the sync_Wasta-Offline_to_Ext_Drive.sh 
# script to sync the newly updated master mirror data to the external USB drive. In this
# configuration the update-mirror.sh script updates BOTH the master mirror's data and the 
# USB drive's mirror data, and:
#   $UPDATINGLOCALDATA will be "YES" 
#   $UPDATINGEXTUSBDATA will be "YES"
#
# Get RSYNC_OPTIONS_LOCAL and RSYNC_OPTIONS_USB
# The rsync options are:
# For FSTYPE of "ext4" (Linux):
#   -a archive mode (recurses thru dirs, preserves symlinks, permissions, times, group, owner)
#   -v verbose
#   -h human readable
#   -q quiet
#   --update overwrite only if file is newer than existing file
# For FSTYPE of "ntfs" or "vfat":
#   -r recursive mode (recurses thru dirs)
#   -v verbose
#   -h human readable
#   --size-only
#   -q quiet
RSYNC_OPTIONS_LOCAL=$(get_rsync_options "$LOCALBASEDIRR") 
RSYNC_OPTIONS_USB=$(get_rsync_options "$USBMOUNTDIR")
# Get FSTYPE_LOCAL and FSTYPE_USB
FSTYPE_LOCAL=$(get_file_system_type_of_partition "$LOCALBASEDIR")
FSTYPE_USB=$(get_file_system_type_of_partition "$USBMOUNTDIR")

if [[ "$UPDATINGLOCALDATA" == "YES" ]] && [[ "$UPDATINGEXTUSBDATA" == "YES" ]]; then
  # Both local and usb are YES, so local can do all copying: first copy local to local, and then local to usb
  # First, local to local - since destination is local use RSYNC_OPTIONS_LOCAL and FSTYPE_LOCAL
  rsync $RSYNC_OPTIONS_LOCAL -q "$LOCALBASEDIR$APTMIRRORSETUPDIR/"*.sh "$LOCALBASEDIR$WASTAOFFLINEDIR$APTMIRRORDIR$VARDIR"
  echo -e "\nCopying postmirror*.sh files (locally to local):"
  echo "   from: $LOCALBASEDIR$APTMIRRORSETUPDIR [$FSTYPE_LOCAL]"
  echo "   to:   $LOCALBASEDIR$WASTAOFFLINEDIR$APTMIRRORDIR$VARDIR [$FSTYPE_LOCAL]"   
  # Ensure that destination postmirror.sh and postmirror2.sh scripts are executable for everyone
  # but only for FSTYPEs that are not "ntfs" or "vfat"
  if [[ "$FSTYPE_LOCAL" != "ntfs" ]] && [[ "$FSTYPE_LOCAL" != "vfat" ]]; then
    chmod ugo+rwx "$LOCALBASEDIR$WASTAOFFLINEDIR$APTMIRRORDIR$VARDIR/"*.sh
  fi
  # Then, local to usb - since destination is usb use RSYNC_OPTIONS_USB and FSTYPE_USB
  rsync $RSYNC_OPTIONS_USB -q "$LOCALBASEDIR$APTMIRRORSETUPDIR/"*.sh "$USBMOUNTDIR$WASTAOFFLINEDIR$APTMIRRORDIR$VARDIR"
  echo "Copying postmirror*.sh files (local to USB drive):"
  echo "   from: $LOCALBASEDIR$APTMIRRORSETUPDIR [$FSTYPE_LOCAL]"
  echo "   to:   $USBMOUNTDIR$WASTAOFFLINEDIR$APTMIRRORDIR$VARDIR [$FSTYPE_USB]"
  # Ensure that destination postmirror.sh and postmirror2.sh scripts are executable for everyone
  # but only for FSTYPEs that are not "ntfs" or "vfat"
  if [[ "$FSTYPE_USB" != "ntfs" ]] && [[ "$FSTYPE_USB" != "vfat" ]]; then
    chmod ugo+rwx "$USBMOUNTDIR$WASTAOFFLINEDIR$APTMIRRORDIR$VARDIR/"*.sh
  fi
else
  # Either local or usb are NO
  if [[ "$UPDATINGLOCALDATA" == "YES" ]]; then
    # local is YES, but usb is NO, so just copy local to local
    rsync $RSYNC_OPTIONS_LOCAL -q "$LOCALBASEDIR$APTMIRRORSETUPDIR/"*.sh "$LOCALBASEDIR$WASTAOFFLINEDIR$APTMIRRORDIR$VARDIR"
    echo -e "\nCopying postmirror*.sh files (locally to local):"
    echo "   from: $LOCALBASEDIR$APTMIRRORSETUPDIR [$FSTYPE_LOCAL]"
    echo "   to:   $LOCALBASEDIR$WASTAOFFLINEDIR$APTMIRRORDIR$VARDIR [$FSTYPE_LOCAL]"   
    # Ensure that destination postmirror.sh and postmirror2.sh scripts are executable for everyone
    # but only for FSTYPEs that are not "ntfs" or "vfat"
    if [[ "$FSTYPE_LOCAL" != "ntfs" ]] && [[ "$FSTYPE_LOCAL" != "vfat" ]]; then
      chmod ugo+rwx "$LOCALBASEDIR$WASTAOFFLINEDIR$APTMIRRORDIR$VARDIR/"*.sh
    fi
  else
    # usb is YES and local is NO, so just copy usb to usb
    rsync $RSYNC_OPTIONS_USB -q "$USBMOUNTDIR$APTMIRRORSETUPDIR/"*.sh "$USBMOUNTDIR$WASTAOFFLINEDIR$APTMIRRORDIR$VARDIR"
    echo -e "\nCopying postmirror*.sh files (USB drive to USB drive):"
    echo "   from: $USBMOUNTDIR$APTMIRRORSETUPDIR [$FSTYPE_USB]"
    echo "   to:   $USBMOUNTDIR$WASTAOFFLINEDIR$APTMIRRORDIR$VARDIR [$FSTYPE_USB]"
    # Ensure that destination postmirror.sh and postmirror2.sh scripts are executable for everyone
    # but only for FSTYPEs that are not "ntfs" or "vfat"
    if [[ "$FSTYPE_USB" != "ntfs" ]] && [[ "$FSTYPE_USB" != "vfat" ]]; then
      chmod ugo+rwx "$USBMOUNTDIR$WASTAOFFLINEDIR$APTMIRRORDIR$VARDIR/"*.sh
    fi
    # When usb is YES and local is NO, the mirror.list needs to point to the
    # mirror on the USB drive. The $LOCALMIRRORSPATH variable becomes the
    # base_path in this situation.
    LOCALMIRRORSPATH=$USBMOUNTDIR$WASTAOFFLINEDIR$APTMIRRORDIR
  fi
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
  echo "Find string: $LOCALBASEDIR/$WASTAOFFLINE*$LTSVERNUM*.deb"
  DEB=`find "$LOCALBASEDIR"/$WASTAOFFLINE*$LTSVERNUM*.deb`
  if [ "x$DEB" = "x" ]; then
    echo "Cannot install wasta-offline. A local deb package was not found."
    echo "You will need to install wasta-offline before you can use the mirror."
  else
    echo "Installing $WASTAOFFLINE via: dpkg -i $DEB"
    dpkg -i $DEB
  fi 
fi
sleep 2s

# Make sure there is an apt-mirror group on the user's computer and
# add the non-root user to the apt-mirror group
echo -e "\nEnsuring apt-mirror group exists and user $SUDO_USER is in apt-mirror group..."
sleep 2s
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
      if smart_install_program "$APTMIRROR" -q ; then
        # The apt-mirror program is installed
        echo -e "\nThe $APTMIRROR program is installed"
        # Create a custom mirror.list config file for this option
        if generate_mirror_list_file "$UkarumpaURLPrefix" ; then
          echo "Successfully generated $MIRRORLIST at $MIRRORLISTPATH."
        else
          echo -e "\n****** WARNING ******"
          echo "Error: Could not generate $MIRRORLIST at $MIRRORLISTPATH."
          echo "****** WARNING ******"
          echo "Aborting..."
          exit $LASTERRORLEVEL
        fi
        echo " "
        echo "*******************************************************************************"
        echo "Calling apt-mirror - getting data from local Ukarumpa site"
        echo "  URL Prefix: $UkarumpaURLPrefix"
        echo "*******************************************************************************"
        echo " "
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
    if is_program_running "$WASTAOFFLINE" ; then
      echo "$WASTAOFFLINE is running"
      # Check if it's the full wasta-offline USB mirror that is plugged in
      if is_dir_available "$WASTAOFFLINEEXTERNALAPTMIRRORPATH" ; then  # /media/$USER/<DISK_LABEL>/wasta-offline/apt-mirror
        echo "Full Wasta-Offline mirror is plugged in"
        # Go ahead and install the apt-mirror program
        if smart_install_program "$APTMIRROR" -q ; then
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
      echo "****** WARNING ******"
      echo "Aborting..."
      exit 1
    else
      echo -e "\nInternet access to www.archive.ubuntu.com appears to be available!"
      # First, ensure that apt-mirror is installed
      if smart_install_program "$APTMIRROR" -q ; then
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
      if generate_mirror_list_file "$InternetURLPrefix" ; then
        echo "Successfully generated $MIRRORLIST at $MIRRORLISTPATH."
      else
        echo -e "\n****** WARNING ******"
        echo "Error: Could not generate $MIRRORLIST at $MIRRORLISTPATH. Aborting..."
        echo "****** WARNING ******"
        echo "Aborting..."
        exit $LASTERRORLEVEL
      fi
      echo " "
      echo "*******************************************************************************"
      echo "Calling apt-mirror - getting data from Internet"
      echo "  URL Prefix: $InternetURLPrefix"
      echo "*******************************************************************************"
      echo " "
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
      #echo -e "\n"
      #echo "The LOCALBASEDIR is: $LOCALBASEDIR"
      cd "$LOCALBASEDIR"
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
      echo "The bills-wasta-docs path is: $LOCALBASEDIR$BILLSWASTADOCSDIR"
      if [ -d "$LOCALBASEDIR$BILLSWASTADOCSDIR" ]; then
        #echo "The BILLSWASTADOCS dir exists"
        cd "$LOCALBASEDIR$BILLSWASTADOCSDIR"
        git pull
        chown -R $SUDO_USER:$SUDO_USER "$LOCALBASEDIR$BILLSWASTADOCSDIR"
      else
        git clone https://github.com/pngbill-scripts/bills-wasta-docs.git
        chown -R $SUDO_USER:$SUDO_USER "$LOCALBASEDIR$BILLSWASTADOCSDIR"
      fi
      # No need for a .gitignore file in bills-wasta-docs repo
      
      #echo "Change back to $LOCALBASEDIR"
      cd "$LOCALBASEDIR"
    fi
   ;;
  "3")
      # Query the user for a $CustomURLPrefix path to be used for the mirror updates.
      # With this option the user's supplied path prefix will be used in generating the mirror.list file 
      # so that they point to the user's input path.

      echo -e "\nType the URL prefix to the mirror on the server, or just Enter to abort:"
      echo "For example: ftp://ftp.organization.org/linux/software/mirror/ [use final /]"
      echo -n "URL prefix: "
      read CustomURLPrefix
      if [[ "x$CustomURLPrefix" != "x" ]]; then
        # Check for server access
        ping -c1 -q "$CustomURLPrefix"
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
          if generate_mirror_list_file "$CustomURLPrefix" ; then
            echo "Successfully generated $MIRRORLIST at $MIRRORLISTPATH."
          else
            echo -e "\nError: Could not generate $MIRRORLIST at $MIRRORLISTPATH. Aborting..."
            exit $LASTERRORLEVEL
          fi
          echo " "
          echo "*******************************************************************************"
          echo "Calling apt-mirror - getting data from custom server site"
          echo "  URL Prefix: $CustomURLPrefix"
          echo "*******************************************************************************"
          echo " "
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

# The apt-mirror has finished updating the local master mirror (at /data/master/wasta-offline/...), 
# now sync the master mirror to the external USB mirror, if it is plugged in.
if [ "$UPDATINGEXTUSBDATA" = "YES" ]; then
  # Call sync_Wasta_Offline_to_Ext_Drive.sh without any parameters: 
  #   the $COPYFROMDIR will be /data/master/wasta-offline/
  #   the $COPYTODIR will be /media/$USER/<DISK_LABEL>/wasta-offline
  echo "[*** End of apt-mirror post-processing ***]"
  bash "$DIR/$SYNCWASTAOFFLINESCRIPT"
else
  # Only updating a local master mirror
  # Ensure that ownership of the mirror tree is apt-mirror:apt-mirror (otherwise cron won't run) 
  # The $LOCALMIRRORSPATH is determined near the main beginning of this script
  echo "Make $LOCALMIRRORSPATH owner be $APTMIRROR:$APTMIRROR"
  chown -R $APTMIRROR:$APTMIRROR "$LOCALMIRRORSPATH" # chown -R apt-mirror:apt-mirror /media/$USER/<DISK_LABEL>/wasta-offline/apt-mirror
fi
        
echo -e "\nThe $UPDATEMIRRORSCRIPT script has finished."

