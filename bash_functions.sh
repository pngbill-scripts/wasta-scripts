#!/bin/bash
# Author: Bill Martin <bill_martin@sil.org>
# Date: 7 November 2014
#   - 17 April 2016 Revised some functions to update them and correct logic errors:
#     get_valid_LM_UPDATES_mount_point () drive space needed increased from 400 to 1TB
#     copy_mirror_base_dir_files () to find the wasta-offline deb files (now .._all.deb),
#       and remove any old _i386.deb and _amd64.deb files
#     generate_mirror_list_file () removed older libreoffice distros and added new ones. Also
#       added Linux Mint rosa to the repo lists, added ...-experimental to packages.sil.org list.
#     is_there_a_wasta_offline_mirror_at () had some logic errors fixed, removed the libreoffice
#       distros from UBUNTUMIRRORS to be scanned.
#   - 3 May 2016 Added Sarah and Xenial repos to the generate_mirror_list_file () function
#   - 20 June 2017 Added the LibreOffice libreoffice-5-2 and libreoffice-5-3 repos to Trusty and Xenial
#   -   Added the Linux Mint Serena and Sonya repos to the list
#   - 13 July 2017 added wasta-offline-setup deb packages to root dir files
#   - 28 August 2017 Changed apt-mirror ownersip top level dir to wasta-offline dir
#      and made ownership of apt-mirror-setup dir also be apt-mirror in set_mirror_ownership_and_permissions ()
#   - 23 November 2018 Revised to remove hard coded "LM-UPDATES" disk label and make the main scripts more 
#      generalized. Removed the "PREP_NEW_USB" parameter option from which was unused. 
#      Streamlined the detection of the USB drive's mount point using echoed output from the new
#      get_wasta_offline_usb_mount_point () function.
#      Added a new get_file_system_type_of_partition () function.
#      Added a new get_device_name_of_usb_mount_point () function.
#      Added a new get_a_default_path_for_COPYFROMDIR () function.
#      Added a new get_a_default_path_for_COPYTODIR () function.
#      Did a general cleanup of the scripts and comments.
#      Removed 'export' from all variables - not needed for variable visibility.
#      Added [currently unused] for move_mirror_from_data_to_data_master () function
#   - 8 January 2019 Revised functions/routines that used lsblk to be able to better handle <DISK_LABEL>
#      with embedded spaces.
#      Added a new get_rsync_options () function
#   - 17 June 2020 updated the generate_mirror_list_file () function to include Ubuntu Focal and remove
#      obsolete items includig the trusty repo which is no longer supported.
# Name: bash_functions.sh
# Distribution: 
# This script is included with all Wasta-Offline Mirrors supplied by Bill Martin.
# The scripts are maintained on GitHub at:
# https://github.com/pngbill-scripts/wasta-scripts
# If you make changes to this script to improve it or correct errors, please send
# your updated script to Bill Martin bill_martin@sil.org
#
# Purpose: This is a source repository script that defines the following bash functions:
#   is_dir_available ()
#   is_program_installed ()
#   is_program_running ()
#   get_file_system_type_of_partition ()
#   get_device_name_of_usb_mount_point ()
#	get_wasta_offline_usb_mount_point ()
#   smart_install_program ()
#   get_base_path_of_mirror_list_file ()
#   get_a_default_path_for_COPYFROMDIR ()
#   get_a_default_path_for_COPYTODIR ()
#   get_rsync_options ()
#   copy_mirror_base_dir_files ()
#   set_mirror_ownership_and_permissions ()
#   ensure_user_in_apt_mirror_group ()
#   generate_mirror_list_file ()
#   is_there_a_wasta_offline_mirror_at ()
#   is_this_mirror_older_than_that_mirror ()
#   get_sources_list_protocol ()
#   move_mirror_from_data_to_data_master () [currently unused]
#   date2stamp () [currently unused]
#   stamp2date () [currently unused]
#   dateDiff () [currently unused]
#
# The above functions are used by the main Wasta-Offline scripts, including the following 
# wasta-offline related scripts:
# 1. update-mirror.sh  (may call the sync_Wasta-Offline_to_Ext_Drive.sh script)
# 2. sync_Wasta-Offline_to_Ext_Drive.sh
# 3. make_Master_for_Wasta-Offline.sh (calls the sync_Wasta-Offline_to_Ext_Drive.sh script)
#
# Usage: This bash_functions.sh script file should be in the same directory as the calling
# bash scripts, and/or referenced with one of the following syntax:
#  source <relative-path>/bash_functions.sh
#  .  <relative-path>/bash_functions.sh
# Hence, the bash functions in this file are made available to a given script (which should
# be in the same directory as this bash_functions.sh file) by including the following
# two lines at the beginning of the given script file:
#   DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
#   . $DIR/bash_functions.sh # $DIR is the path prefix to bash_functions.sh as well as to the current script

# ------------------------------------------------------------------------------
# Bash script functions
# ------------------------------------------------------------------------------

# A bash function that checks whether a dir exists/is available. Returns 0 if the
# directory exists/is available. Returns 1 if dir doesn't exist or is not available.
# First parameter is manditory and should be the absolute path to a directory.
is_dir_available ()
{
  # This function should not produce any echo output other than its return value
  if [ -d "$1" ]; then
    return 0
  else
    return 1
  fi
}

# A bash function that checks whether a program is installed on this computer. Returns a
# zero value if the program is installed; returns non-zero if the program is not installed.
# One parameter is manditory and should be the name of the program we are checking its
# install status. The program's name should be its name as it would be invoked from a command
# line.
is_program_installed ()
{
  # This function should not produce any echo output other than its return value
  hash $1 2>/dev/null  # hash returns a non-zero value if $1 is not installed
  LASTERRORLEVEL=$?
  return $LASTERRORLEVEL
}

# A bash function that checks whether a program is currently running. Returns a zero value
# if the program is running; returns non-zero (1) if the program is not currently running.
# First parameter is manditory and should be the name of a program (as invoked from command line).
# An optional second parameter of -q (or any string value) can be used to suppress the echo output.
# Note: The $1 used within this funtion is the parameter invoked with this install_program, bash
# function, not the $1 representing the first command-line parameter from invocation of the calling 
# script.
is_program_running ()
{
  # Use ps, grep, and wc to determine the number of $1 processes running
  NUMBEROFPROCESSES=$(ps -ef | grep "$1" | grep -v "grep" | wc -l)
  if [ ! $NUMBEROFPROCESSES -eq 0  ]; then
    if [ "x$2" = "x" ]; then
      # 'x' is used in the string comparison because bash is broken and in some versions could 
      # fail the equality test with empty strings.
      echo "The $1 program is currently running."
    fi
    # In bash logic success/true is 0
    return 0 # $NUMBEROFPROCESSES # will be > 0
  else
    if [ "x$2" = "x" ]; then
      # 'x' is used in the string comparison because bash is broken and in some versions could 
      # fail the equality test with empty strings.
      echo "The $1 program is not currently running."
    fi
    # In bash logic failure/false is >= 1
    return 1 # $NUMBEROFPROCESSES # will be 0
  fi
}

# A bash function that echos the file system type of the USB mount point.
# A directory path must be passed to this function as the first parameter $1.
# We extract the directory path's 'root' directory as only that is what can match
# lsblk's MOUNTPOINT output i.e., /media/bill/UPDATES or /data [not /data/master]
# If the $1 parameter is not found, this function echos an empty string,
# otherwise, if the root directory of the path in $1 was found, this function
# echos the file system type, i.e., ext4, ntfs, vfat.
# No echo statements should appear in this function other than the echo "$FSTYPE" 
# at the last line of the function.
get_file_system_type_of_partition ()
{
	MNTPT=$1 # Passed in Root Directory, for example /media/bill/UPDATES, or /media/bill/SP PHD U3, or /data
	# which must match the lsblk's MOUNTPOINT output.
	# Note: The lsblk command's MOUNTPOINT option never has a / at the end of its output string,
	# so remove any final / from MNTPT (esp since Tab auto-completion puts a final / on path)	
	MNTPT=${MNTPT%/}
	DEVNAME=$(lsblk -o FSTYPE,NAME,MOUNTPOINT -pr | sed 's/\\x20/ /g' | grep "$MNTPT" | cut -f2 -d" ")
	# For an accurate look up of FSTYPE, we have to grep for the root directory
	ROOT_DIR="/"$(echo "$MNTPT" | cut -d "/" -f2) # normally /media or /data
    
    # Note on lsblk options/switches below: 
    #   -o FSTYPE,NAME,MOUNTPOINT selects the 3 columns listed with FSTYPE first, separated by a space
    #     and having the MOUNTPOINT (which may have spaces) last option allows better delimiter 
    #     selection of FSTYPE and NAME [i.e., /dev/sdb1] which won't have internal spaces
    #   -p (full path) optionlists full device as, for example, /dev/sdb1
    #   -r (raw output) eliminates graphic tree chars prefixing device path
    # NOTE: lsblk command's MOUNTPOINT option embeds \x20 chars in place of space chars
    # so we can use sed to replace \x20 with plain space in the piped stream, in order
    # for grep to be able to match the "$MNTPT", which won't have \x20 for spaces.
    # Add a pipe to grep "$DEVNAME" to narrow down the FSTYPE in case more than one
    # /media/... devices are plugged in.
	FSTYPE=$(lsblk -o FSTYPE,NAME,MOUNTPOINT -pr | sed 's/\\x20/ /g' | grep "$DEVNAME" | grep "$ROOT_DIR" | cut -f1 -d" ")
	# Note: Use of lsblk doesn't require sudo and is more flexible than blkid
	# A less reliable, more obscure way using blkid is given below:
	#BLKID=`blkid ! grep $MNTPT`
	#FSTYPE=`echo $BLKID | grep -oP 'TYPE="\K[^"]+'`
	echo "$FSTYPE"
}

# A bash function that echos the device name of the USB mount point.
# The $USBMOUNTDIR must be passed to this function as the first parameter $1.
# If $USBMOUNTDIR parameter is not found, this function echos an empty string,
# No echo statements should appear in this function other than the echo "$DEVNAME" line
# at the last line of the function.
get_device_name_of_usb_mount_point ()
{
    MNTPT=$1
    # Note on lsblk options/switches below: 
    #   -o FSTYPE,NAME,MOUNTPOINT selects the 3 columns listed with FSTYPE first, separated by a space
    #     and having the MOUNTPOINT (which may have spaces) allows better delimiter selection
    #     of FSTYPE and NAME [i.e., /dev/sdb1] which won't have internal spaces
    #   -p (full path) optionlists full device as, for example, /dev/sdb1
    #   -r (raw output) eliminates graphic tree chars prefixing device path
    # NOTE: lsblk command's MOUNTPOINT option embeds \x20 chars in place of space chars
    # so we need to use sed to replace \x20 with plain space in the piped stream, in order
    # for grep to be able to match the "$MNTPT".
    # NOTE: The MOUNTPOINT stored in the lsblk output only includes the path up to the main/root 
    # dir, i.e., /media/$USER/<DISK_LABEL>. So the incoming $1 parameter for MNTPT must
    # be $USBMOUNTDIR rather than $USBMOUNTPOINT in the caller.
	# Note: The lsblk command's MOUNTPOINT option never has a / at the end of its output string,
	# so remove any final / from MNTPT (esp since Tab auto-completion puts a final / on path)
	MNTPT=${MNTPT%/}	
    DEVNAME=$(lsblk -o FSTYPE,NAME,MOUNTPOINT -pr | sed 's/\\x20/ /g' | grep "$MNTPT" | cut -f2 -d" ")
    # Note: Use of lsblk is more flexible and reliable than df -h 
    # A less reliable way using df is given below:
    #DEVNAME=`df -h | grep $MNTPT | cut -f1 -d" "`
    echo "$DEVNAME"
}

# A bash function that checks whether a USB drive is mounted that has a subdirectory called
# 'wasta-offline' at /media/*/*/wasta-offline, or /media/*/wasta-offline. Returns non-zero (1) 
# if a USB device mounted at /media/... is not found with a .../wasta-offline subdirectory.
# If two or more USB drives on /media/... are found (with identical disk labels such as UPDATES
# - in which the second drive's label gets renamed to UPDATES1), the | sort -r pipe option
# causes the output to only detect the first non-numerically-suffixed one that is found. 
# For example if two USB drives each labeled UPDATES are plugged in, the second one will have
# its label become UPDATES1 or UPDATES_, and this function will detect only the first drive 
# plugged in (UPDATES rather than UPDATES1 or UPDATES_).
# Returns zero (0) if such directory is found and assigns the absolute path prefix up to, 
# and including the /wasta-offline folder, to the variable START_FOLDER. For example, 
# it might return /media/bill/<DISK_LABEL>/wasta-offline as the value stored in START_FOLDER.
# Note: whm 23 November 2018 revised to echo the value of $START_FOLDER so the function
# is normally used within back ticks to return the USB mount point value as a string, 
# for example: USBMOUNTPOINT=`get_wasta_offline_usb_mount_point`
# No echo statements should appear in this function other than the echo "$START_FOLDER" line.
get_wasta_offline_usb_mount_point ()
{
    START_FOLDER=""
	# whm Note: code below borrowed from the wasta-offline program script.
    # first, look for wasta-offline folder under /media/$USER (12.10 and newer)
    # 2014-04-24 rik: $USER, $(logname), $(whoami), $(who) all not working when
    #   launch with gksu.  So, just setting to /media/*/*/wasta-offline :-(
    START_FOLDER=$(ls -1d /media/*/*/wasta-offline 2> /dev/null | sort -r | head -1)
    # whm 7Jan2019 removed following test as it can give false if disk label has space char 
    # in it, and is obsolete as we no longer support 12.04.
    #if [ -z "$START_FOLDER" ]
    #then
    #    # second, look for wasta-offline folder under /media (12.04 and older)
    #    START_FOLDER=$(ls -1d /media/*/wasta-offline 2>/dev/null | sort -r | head -1)
    #fi
    # The following echo returns the USB mount point as a string when the function is
    # assigned to a variable, i.e., USBMOUNTPOINT=`get_wasta_offline_usb_mount_point`
    # No other echo statements should appear in this function.
    echo "$START_FOLDER"

	# Handle situation where no wasta-offline subdirectory was found, in which case
	# USB mount point will be an empty string.
	if [ "x$START_FOLDER" = "x" ]; then
		# The $START_FOLDER variable is empty, i.e., a wasta-offline subdirectory on /media/... was not found
		return 1 # failure - no USB mount point found
	fi
	return 0 # Success
}

# A bash function that first checks whether a program $1 is installed by calling the bash 
# function is_program_installed. If the program is already installed this function does nothing 
# but returns 0.
# $1  the program to be installed
# $2  -q (quiet - don't prompt to install, go ahead and install the program)
# If the program is not installed, it installs the program using either wasta-offline (if 
# wasta-offline is running and is the full mirror), the local Ukarumpa server, or the Internet 
# (after prompting if OK to access the Internet).
# The function takes a single parameter which should be the name of the program as it would
# be invoked at a command line. For example: smart_install_program "apt-mirror".
# If wasta-offline is running and using the full mirror USB drive, it installs program from 
# the full wasta-offline mirror, otherwise, if Internet is available, it prompts the user if
# the program should be downloaded and installed from the Internet instead.
# Note: The $1 used within this funtion is the parameter invoked with this install_program, bash
# function, not the $1 representing the first command-line parameter from invocation of the 
# calling script.
smart_install_program ()
{
  # Check if $1 is already installed. If not, offer to install the $1 program.
  echo " "
  echo -n "Checking if $1 is installed..."
  if (is_program_installed "$1"); then
    echo "YES"
    # Program already installed, so do nothing more just return 0
    return 0
  else 
    echo "NO"
    # The $1 program is not installed
    # We can help guide the user through the installation if we know what the current URL protocol
    # is being used in their /etc/apt/sources.list file. The URL protocol should be one of three
    # possibilities:
    # 1. http:// This protocol would indicate that the user currently has access the 
    #    Internet or, if http:// is followed by linuxrepo.sil.org.pg/mirror, has access to
    #    Linux mirrors on the SIL PNG LAN, to install the $1 program.
    # 2. file:   This protocol would indicate that the user is currently running the wasta-offline
    #    program, and if the full wasta-offline USB drive is mounted, the program can be installed 
    #    offline from the full mirror on the external hard drive.
    # 3. ftp://  This protocol would indicate that the user would currently need to access a ftp 
    #    LAN server such as the FTP server at Ukarumpa to install the $1 program.

    # call our get_sources_list_protocol () function to determine the current sources.list protocol
    PROTOCOL=`get_sources_list_protocol`
    case $PROTOCOL in
      $UkarumpaURLPrefix)
        # The source.list indicates that software installs will potentially be done by 
        # access to the Ukarumpa linux mirrors at http://linuxrepo.sil.org.pg/mirror/
        # User should be warned and given the opportunity to bail out.
        response="y"
        if [[ "x$2" = "x" ]]; then
          read -r -n 1 -p "The $1 program is not installed on this computer. Install it? [y/n] " response
        fi
        case $response in
          [yY][eE][sS]|[yY]) 
              # ping the Ukarumpa server to check for access to http://linuxrepo.sil.org.pg/mirror
              ping -c1 -q http://linuxrepo.sil.org.pg/mirror
              if [ "$?" != 0 ]; then
                echo "Internet access to http://linuxrepo.sil.org.pg/mirror not currently available."
                echo "This script cannot continue without access to the Ukarumpa server."
                echo "Make sure the computer has access to the server, then try again."
                echo "Or, alternately, run wasta-offline and install software without Internet access"
                echo "Aborting the installation..."
                return 1
              fi
              echo -e "calling apt-get update"
              apt-get -qq update
              echo -e "\nInstalling $1..."
              apt-get -qq install $1
              LASTERRORLEVEL=$?
              if [ $LASTERRORLEVEL != 0 ]; then
                 #echo "Could not install the $1 program. Aborting..."
                 return $LASTERRORLEVEL
              fi
              ;;
           *)
              #echo "Please install the $1 program, then try again"
              return 1
              ;;
        esac
      ;;
      $InternetURLPrefix)
        # The source.list indicates that software installs will potentially be done by direct
        # access to the Internet. User should be warned and given the opportunity to bail out.
        response="y"
        if [[ "x$2" = "x" ]]; then
          read -r -n 1 -p "The $1 program is not installed on this computer. Install it? [y/n] " response
        fi
        case $response in
          [yY][eE][sS]|[yY]) 
              # ping the Internet to check for Internet access to www.archive.ubuntu.com
              ping -c1 -q www.archive.ubuntu.com
              if [ "$?" != 0 ]; then
                echo "Internet access to www.archive.ubuntu.com not currently available."
                echo "This script cannot continue without access to the Internet."
                echo "Make sure the computer has access to the Internet, then try again."
                echo "Or, alternately, run wasta-offline and install software without Internet access"
                echo "Aborting the installation..."
                return 1
              fi
              echo -e "calling apt-get update"
              apt-get -qq update
              echo -e "\nInstalling $1..."
              apt-get -qq install $1
              LASTERRORLEVEL=$?
              if [ $LASTERRORLEVEL != 0 ]; then
                 #echo "Could not install the $1 program. Aborting..."
                 return $LASTERRORLEVEL
              fi
              ;;
           *)
              #echo "Please install the $1 program, then try again"
              return 1
              ;;
        esac
      ;;
      $FTPURLPrefix)
        # The sources.list indicates that software can potentially be installed from mirrors on
        # an FTP server. User should be warned if the FTP server cannot be contacted.
        # ping the FTP server to check for server access
        ping -c1 -q ftp://ftp.sil.org.pg
        if [ "$?" != 0 ]; then
          echo "FTP access to the ftp.sil.org.pg server is not available."
          echo "This script cannot run without access to the SIL FTP server."
          echo "Make sure the computer has access to the FTP server, then try again."
          echo "Or, alternately, run wasta-offline and install software without Internet access"
          echo "Aborting the installation..."
          return 1
        fi
        echo -e "calling apt-get update"
        apt-get -qq update
        echo -e "\nInstalling $1..."
        apt-get -qq install $1
        LASTERRORLEVEL=$?
        if [ $LASTERRORLEVEL != 0 ]; then
           #echo "Could not install the $1 program. Aborting..."
           return $LASTERRORLEVEL
        fi
      ;;
      $FileURLPrefix)
        # The sources.list indicates wasta-offline is active and software can potentially be 
        # installed using a full wasta-offline USB drive. User should be warned if wasta-offline
        # is not actually running, or a full mirror at /media/$USER/<DISK_LABEL>/wasta-offline/... 
        # can't be found.
        if (is_program_running "$WASTAOFFLINE"); then
          # wasta-offline is running
          # If wasta-offline is running against the full mirror it should be mounted at /media/.../<DISK_LABEL>
          if (is_dir_available "$USBMOUNTDIR"); then
            echo "The $WASTAOFFLINE program is running with the full mirror on:"
            echo "   $USBMOUNTDIR."
          else
            echo "The $WASTAOFFLINE program is running but full mirror in NOT on: $USBMOUNTDIR"
            # An error message will appear in the apt-get install $1 call below
          fi
          echo -e "calling apt-get update"
          apt-get -qq update
          echo -e "\nInstalling $1..."
          apt-get -qq install $1
          LASTERRORLEVEL=$?
          if [ $LASTERRORLEVEL != 0 ]; then
             echo "Could not install the $1 program. Aborting..."
             return $LASTERRORLEVEL
          fi
        else
          # wasta-offline is NOT running
          echo "Your computer expects to get software by using wasta-offline, "
          echo "but wasta-offline is not currently running, so the installation of"
          echo "$1 was aborted."
          echo "You should start wasta-offline and while it is running start this"
          echo "script again..."
          return 1
        fi
      ;;
    esac
    return 0
  fi
}

# This function echos the base_path that is set in the user's /etc/apt/mirror.list file
# This function takes no parameters. Typically returns: /data/master/wasta-offline/apt-mirror
# but could potentially return something like /media/bill/UPDATES/wasta-offline/apt-mirror
# if the computer being used, ran update-mirror.sh script (without it having a master mirror)
# and just updating the mirror on an external USB drive.
# If there is no mirror.list file at /etc/apt/ or no base_path is set in mirror.list
# this function returns an empty string.
# No echo statements should be added to this function, other than the 
# echo "$BasePath" line at the end of the function.
get_base_path_of_mirror_list_file ()
{
  PathToMirrorListFile="/etc/apt/mirror.list"
  FILE=$PathToMirrorListFile
  SetBasePath="set base_path"
  BasePath=""
  if [ -e "$PathToMirrorListFile" ]; then
    while read -r line
    do
      [[ $line = \#* ]] && continue
      if [[ $line == $SetBasePath* ]]; then
        # Get the following path part
        BasePath=${line#$SetBasePath}
        # Remove leading space
        BasePath=${BasePath//[[:blank:]]/}
        #BasePath=`echo $BasePath` # echo also removes leading space
        # No need to process any more of mirror.list
        break;
      fi
    done < $FILE
  fi
  echo "$BasePath"
}

# This function echos a default value that can be used initially for the $COPYFROMDIR source.
# It calls the get_wasta_offline_usb_mount_point () function to get a USB mount point from any 
# attached/mounted USB drive that has a /media/$USER/<DISK_LABEL>/wasta-offline tree.
# If no value was obtained for the USB mount point, the function echos a default value of "UNKNOWN".
# If a USB mount point exists, the function echos that as return value.
get_a_default_path_for_COPYFROMDIR ()
{
  USBMNTPT=`get_wasta_offline_usb_mount_point` 
  if [ "x$USBMNTPT" = "x" ]; then
    # USBMNTPT is empty string, i.e., no USB media found with /media/$USER/<DISK_LABEL>/wasta-offline
    echo "UNKNOWN"
  else
    echo "$USBMNTPT"  # /media/$USER/<DISK_LABEL>/wasta-offline
  fi
}

# This function echos a default value that can be used initially for the $COPYTODIR destination.
# It calls the get_base_path_of_mirror_list_file () function to get a BasePath from any 
# /etc/apt/mirror.list file existing on the computer. After stripping off the final .../apt-mirror 
# dir, it tests if the value is empty (no mirror.list existed), or has a string value (mirror.list existed).
# If no value was gotten from a mirror.list file the function echos a default value of /data/master/wasta-offline.
# If a base_path existed from a mirror.list file the function echos that as return value.
get_a_default_path_for_COPYTODIR ()
{
  BasePath=""
  BasePath=`get_base_path_of_mirror_list_file` # most likely /data/master/wasta-offline/apt-mirror, if it exists
  # We'll sync to the wasta-offline directory (one level higher up), so remove /apt-mirror part.
  COPYTODIRFROMMIRRORLISTFILE=`dirname "$BasePath"` # strip off the .../apt-mirror dir, i.e., /data/master/wasta-offline
  if [[ "x$COPYTODIRFROMMIRRORLISTFILE" == "x" ]]; then
    # COPYTODIRFROMMIRRORLISTFILE is empty string, i.e., no mirror.list value was retrieved for base_path
    # In this case echo a default value of /data/master/wasta-offline as return value
    echo "/data/master/wasta-offline"
  else
    # COPYTODIRFROMMIRRORLISTFILE had a value so echo it as return value
    echo "$COPYTODIRFROMMIRRORLISTFILE" 
  fi
}

# This function echos a string of the main options to be used with rsync calls:
# The function takes one parameter:
#   parameter $1 must be the 'base directory' of the destination path that will be 
#   used in the rsync command, for example: /media/<username>/<DISK_LABEL>, 
#   or /data/master. Since it is easy to wrongly use parameters that include
#   the .../wasta-offline directory as a parameter to this function, we proactively 
#   make sure that doesn't happen by removing any .../wasta-offline directory from $1.
# Note: other parameters like -q (quiet) and --progress can be added to individual
#   rsync calls - the -q option should be used for rsync calls that copy the root dir
#   files from source to destination, but not for the main rsync call in 
#   sync_Wasta-Offline_to_Ext_Drive.sh, and the --progress options should be used
#   for the main rsync call in sync_Wasta-Offline_to_Ext_Drive.sh.
# The function determines if the destination path includes "/media" in the path,
# and, if so, calls the get_file_system_type_of_partition () function to see
# if that destination USB drive also represents a "ntfs" or "vfat" file system. 
# If both conditions are true, then the alternate set of rsync options
# are used that are safer for rsync operations to non-Linux formatted drives.
# This get_rsync_options () function calls another function 
# get_file_system_type_of_partition () to get the USB file system type of the
# destination drive indicated by parameter $1.
get_rsync_options ()
{
  USBMNTDIR=$1
  # Remove any .../wasta-offline directory from the input parameter $1
  if [[ "$1" == *"wasta-offline"* ]]; then 
    USBMNTDIR=$(dirname "$1")
  fi

  # If the $1 parameter (destination) root dir is "/media", and if the file sys type 
  # is "ntfs" or "vfat", set rsync options to "-rvh --size-only" to avoid messing
  # too much with ownership/permissions on a Windows format drive, otherwise use the
  # default rsync options of "-avh --update" for a Linux format drive.
  RSYNC_OPTS="-avh --update" # default rsync options for destination drive is formatted Linux ext4, ext3, etc.
  ROOT_DIR_OF_COPYTOBASEDIR="/"$(echo "$USBMNTDIR" | cut -d "/" -f2) # normally /media or /data
  if [[ "$ROOT_DIR_OF_COPYTOBASEDIR" == "/media" ]]; then
    USBFSTYPE=$(get_file_system_type_of_partition "$USBMNTDIR")
    if [[ "$USBFSTYPE" == "ntfs" ]] || [[ "$USBFSTYPE" == "vfat" ]]; then
      RSYNC_OPTS="-rvh --size-only"
    fi
  fi
  echo "$RSYNC_OPTS"
}



# This function uses rsync to copy the base directory and apt-mirror-setup directory
# files from a source mirror's base directory to a destination mirror's base directory.
# This function takes two parameters: 
#   $1 a source mirror's base path - usually "$COPYFROMBASEDIR"
#   $2 a destination mirror's base path - usually "$COPYTOBASEDIR".
# The calling script should have assigned values to the following variables:
#   $BILLSWASTADOCSDIR
#   $WASTAOFFLINEDIR
#   $APTMIRRORDIR
#   $APTMIRRORSETUPDIR
# This function is currently only used within the sync_Wasta-Offline_to_Ext_Drive.sh script.
#
# Note that the sync_Wasta-Offline_to_Ext_Drive.sh script can be used with its $COPYTOBASEDIR
# pointing to either the master mirror - as when make_Master_for_Wasta-Offline.sh script is
# being called to initialize/kickstart a master mirror from a USB drive, or when $COPYTOBASEDIR
# is pointing to the USB drive when updating the mirror (or creating a new one) on the USB drive.
# We need to detect when the destination ($COPYTOBASEDIR) is formatted as ntfs or vfat, and
# if so, we use the -rvh --size-only options with the rsync command (to avoid trying to mess with  
# ownership and permissions). Otherwise, when the destination ($COPYDOBASEDIR) is formatted as  
# ext4 (Linux), we use the normal -avh --update options with the rsync command (in order to 
# preserve ownership and permissions). The same considerations must be followed within the 
# set_mirror_ownership_and_permissions () function farther below.

# Revised 5Jan2019 to support copying/syncing to a destination drive that is formatted as
# ntfs or vfat - normally a ntfs or vfat formatted drive would be at the destination only 
# when the destination drive is a removable USB drive (the master mirror should always be 
# located on a Linux Ext4 formatted partition on a dedicated computer).
copy_mirror_base_dir_files ()
{
  VARDIR="/var"
  # FYI: It would be possible to grab the wasta-offline*.deb packages directly
  # from the Internet repos using wget, but it should be sufficient to just
  # copy the latest ones in the source mirror tree to the base directories
  # of both the source mirror and the destination mirror.
  # Here is how to do it from the Internet (commented out below):
  #echo -e "\nRetrieving latest version(S) of wasta-offline deb package at:"
  #echo $WASTAOFFLINEPKGURL
  # Make the /data/ dir current for wget download below
  #cd $DATADIR
  # Use wget to download the 32bit and 64bit wasta-offline*.deb packages from the ppa.launchpad.net repo
  #wget --recursive --no-directories --level 1 -A.deb $WASTAOFFLINEPKGURL/
  
  # Determine the rsync options to use for destination $2 and source $1 to apply later below.
  # Use the bash function get_rsync_options () to determine the correct rsync options:
  # If the destination's path root dir is "/media", and if it determines the file system
  # there is "ntfs" or "vfat", it sets rsync options to "-rvh --size-only" to avoid
  # messing with ownership/permissions on a Windows format drive, otherwise it uses the
  # default rsync options of "-avh --update" for a Linux format drive.
  # For this copy_mirror_base_dir_files () function we use the -q (quiet) option
  # to minimize output to the console for the file copying.
  RSYNC_OPTIONS_1=$(get_rsync_options "$1") 
  RSYNC_OPTIONS_2=$(get_rsync_options "$2")
  USBFSTYPE_1=$(get_file_system_type_of_partition "$1")
  USBFSTYPE_2=$(get_file_system_type_of_partition "$2")
  #echo "  Debug: RSYNC_OPTIONS_1 for $1 are [$RSYNC_OPTIONS_1] USBFSTYPE_1 is [$USBFSTYPE_1]"
  #echo "  Debug: RSYNC_OPTIONS_2 for $2 are [$RSYNC_OPTIONS_2] USBFSTYPE_2 is [$USBFSTYPE_2]"
  #exit 1

  # $PKGPATH is assigned the path to the wasta-offline directory containing the deb packages 
  # deep in the ppa.launchpad.net part of the source mirror's "pool" repo:
  PKGPATH=$1$WASTAOFFLINEDIR$APTMIRRORDIR"/mirror/ppa.launchpad.net/wasta-linux/wasta-apps/ubuntu/pool/main/w/wasta-offline"

  #echo -e "\nExecuting copy_mirror_base_dir_files function..."
  #echo "The 1 parameter is: $1"
  #echo "The 2 parameter is: $2"
  #echo "The PKGPATH is: $PKGPATH"

  # Previously the wasta-offline debs were specifically packaged for i386 and amd64 packages, but
  # are currently packaged in an _all.deb package for each distro supported.
  # Due to a strange quirk I'm experiencing with the find command, it fails to find the deb files 
  # if the current directory is /data, so as a work-around, I'll temporarily change the directory
  # to / (root), execute the find command, and then change the current directory back to what it
  # was previously (!).
  OLDDIR=`pwd` # Save the working dir path
  cd / # temporarily change the working dir path to root of the drive script is running from.
  # Store the found deb files, along with their absolute paths prefixed in a DEBS variable
  DEBS=`find "$PKGPATH" -type f -name wasta-offline_*_all.deb -printf '%T@ %p\n' | sort -n | cut -f2 -d" "`
  # Handle any find failure that leaves the DEBS variable empty and, if no failures,
  # copy the deb packages to the root dir of both the source and destination locations.
  if [[ "x$DEBS" == "x" ]]; then
    echo -e "\nCould not find the wasta-offline deb packages in source mirror"
  else
    # Remove any old/existing deb files
    if ls "$1"/wasta-offline*.deb 1> /dev/null 2>&1; then
      rm "$1"/wasta-offline*.deb
    fi
    #echo -e "\nCopying packages from source mirror tree to: $1"
    echo -n "."
    # For these "base" level files we use --update option instead of the --delete option
    # which updates the destination only if the source file is newer.
    # The rsync command's options in $RSYNC_OPTIONS below become: '-rvh --size-only'
    # if destination USB drive is not Linux ext4 (ntfs), otherwise they are '-avh --update'
    rsync $RSYNC_OPTIONS_1 -q $DEBS "$1" # $1 is source mirror - use normal rsync options
    if ls "$2"/wasta-offline*.deb 1> /dev/null 2>&1; then
      rm "$2"/wasta-offline*.deb
    fi
    #echo -e "\nCopying packages from source mirror tree to: $2"
    echo -n "."
    # For these "base" level files we use --update option instead of the --delete option
    # which updates the destination only if the source file is newer.
    # The rsync command's options in $RSYNC_OPTIONS below become: '-rvh --size-only'
    # if destination USB drive is not Linux ext4 (ntfs), otherwise they are '-avh --update'
    rsync $RSYNC_OPTIONS_2 -q $DEBS "$2" # $2 is destination mirror
  fi
  
  # whm 13July2017 added wasta-offline-setup deb packages to root dir files
  # $PKGPATH is assigned the path to the wasta-offline directory containing the deb packages 
  # deep in the ppa.launchpad.net part of the source mirror's "pool" repo:
  # Note: Since COPYFROMDIR generally has a final /, append $APPMIRROR to it rather than $APPMIRRORDIR
  PKGPATH="$1"$WASTAOFFLINEDIR$APTMIRRORDIR"/mirror/ppa.launchpad.net/wasta-linux/wasta-apps/ubuntu/pool/main/w/wasta-offline-setup"
  # Store the found deb files, along with their absolute paths prefixed in a DEBS variable
  DEBS=`find "$PKGPATH" -type f -name wasta-offline-setup_*_all.deb -printf '%T@ %p\n' | sort -n | cut -f2 -d" "`
  # Handle any find failure that leaves the DEBS variable empty and, if no failures,
  # copy the deb packages to the root dir of both the source and destination locations.
  if [[ "x$DEBS" == "x" ]]; then
    echo -e "\nCould not find the wasta-offline-setup deb packages in source mirror"
  else
    # Remove any old/existing deb files
    if ls "$1"/wasta-offline-setup*.deb 1> /dev/null 2>&1; then
      rm "$1"/wasta-offline-setup*.deb
    fi
    #echo -e "\nCopying packages from source mirror tree to: $1"
    echo -n "."
    # For these "base" level files we use --update option instead of the --delete option
    # which updates the destination only if the source file is newer.
    # The rsync command's options in $RSYNC_OPTIONS below become: '-rvh --size-only'
    # if destination USB drive is not Linux ext4 (ntfs), otherwise they are '-avh --update'
    rsync $RSYNC_OPTIONS_1 -q $DEBS "$1" # $1 is source mirror - use normal rsync options
    if ls "$2"/wasta-offline-setup*.deb 1> /dev/null 2>&1; then
      rm "$2"/wasta-offline-setup*.deb
    fi
    #echo -e "\nCopying packages from source mirror tree to: $2"
    echo -n "."
    # For these "base" level files we use --update option instead of the --delete option
    # which updates the destination only if the source file is newer.
    # The rsync command's options in $RSYNC_OPTIONS below become: '-rvh --size-only'
    # if destination USB drive is not Linux ext4 (ntfs), otherwise they are '-avh --update'
    rsync $RSYNC_OPTIONS_2 -q $DEBS "$2"
  fi
  
  cd "$OLDDIR" # Restore the working dir to what it was

  # Copy the *.sh file in the $1$APTMIRRORSETUPDIR to their ultimate 
  # destination of "$1"$WASTAOFFLINEDIR$APTMIRRORDIR$VARDIR
  #echo -e "\ncopying the *.sh files from: "$1"$APTMIRRORSETUPDIR/*.sh"
  #echo "                                to "$1"$WASTAOFFLINEDIR$APTMIRRORDIR$VARDIR"
  # For these "base" level files we use --update option instead of the --delete option
  # which updates the destination only if the source file is newer.
  # The rsync command's options in $RSYNC_OPTIONS below become: '-rvh --size-only'
  # if destination USB drive is not Linux ext4 (ntfs), otherwise they are '-avh --update'
  rsync $RSYNC_OPTIONS_1 -q "$1"$APTMIRRORSETUPDIR/*.sh "$1"$WASTAOFFLINEDIR$APTMIRRORDIR$VARDIR # $1 is source mirror - use normal rsync options

  # Copy other needed files to the external drive's root dir
  
  # Find all Script files at base path $1 (-maxdepth 1 includes the $1 folder)
  # and rsync them to base path of $2.
  #echo -e "\n"
  for script in `find "$1" -maxdepth 1 -name '*.sh'` ; do 
    # The $script var will have the absolute path to the file in the source tree
    # We need to adjust the path to copy it to the same relative location in the 
    # destination tree. 
    # We remove the $1 part of the $script path and substitute the $2 part.
    # Handle any find failure that leaves the $script variables empty, and if no failures,
    # rsync the script to the destination mirror at same relative location. Create the
    # directory structure at the destination if necessary.
    destscript="$2"${script#"$1"}
    #echo -e "\nFound script in Base DIR $1"
    #echo "  at: $script"
    #echo "Dest at: $destscript"
    DIROFSCRIPT=${destscript%/*}
    #echo "Making directory at: $DIROFSCRIPT"
    mkdir -p "$DIROFSCRIPT"
    #echo "Synchronizing the script $script"
    #echo "  to $destscript"
    echo -n "."
    # For these "base" level files we use --update option instead of the --delete option
    # which updates the destination only if the source file is newer.
    # The rsync command's options in $RSYNC_OPTIONS below become: '-rvh --size-only'
    # if destination USB drive is not Linux ext4 (ntfs), otherwise they are '-avh --update'
    rsync $RSYNC_OPTIONS_2 -q "$script" "$destscript"
  done

  # Find all Script files in the apt-mirror-setup folder of $1  (-maxdepth 1 includes the 
  # $1/apt-mirror setup/ folder) and rsync them to apt-mirror-setup folder of $2
  #echo -e "\n"
  for script in `find "$1"$APTMIRRORSETUPDIR -maxdepth 1 -name '*.sh'` ; do 
    # The $script var will have the absolute path to the file in the source tree
    # We need to adjust the path to copy it to the same relative location in the 
    # destination tree. 
    # We remove the $1 part of the $script path and substitute the $2 part.
    # Handle any find failure that leaves the $script variables empty, and if no failures,
    # rsync the script to the destination mirror at same relative location. Create the
    # directory structure at the destination if necessary.
    destscript="$2"${script#"$1"}
    #echo "Found script in $1$APTMIRRORSETUPDIR at: $script"
    #echo "The destination script will be at: $destscript"
    DIROFSCRIPT=${destscript%/*}
    #echo "Making directory at: $DIROFSCRIPT"
    mkdir -p "$DIROFSCRIPT"
    #echo -e "\nSynchronizing the script file $script to $destscript"
    echo -n "."
    # For these "base" level files we use --update option instead of the --delete option
    # which updates the destination only if the source file is newer.
    # The rsync command's options in $RSYNC_OPTIONS below become: '-rvh --size-only'
    # if destination USB drive is not Linux ext4 (ntfs), otherwise they are '-avh --update'
    rsync $RSYNC_OPTIONS_2 -q "$script" "$destscript"
  done

  # Find all the other Script files at $1$WASTAOFFLINEDIR$APTMIRRORDIR$VARDIR (includes only 
  # the clean.sh postmirror.sh and postmirror2.sh scripts in the 
  # $1/wasta-offline/apt-mirror/var/ folder) and rsync them to parallel folder in $2
  for script in `find "$1"$WASTAOFFLINEDIR$APTMIRRORDIR$VARDIR -maxdepth 1 -name '*.sh'` ; do 
    # The $script var will have the absolute path to the file in the source tree
    # We need to adjust the path to copy it to the same relative location in the 
    # destination tree. 
    # We remove the $1 part of the $script path and substitute the $2 part.
    # Handle any find failure that leaves tje $script variables empty, and if no failures,
    # rsync the script to the destination mirror at same relative location.
    destscript="$2"${script#"$1"}
    #echo "Found script in $1$WASTAOFFLINEDIR$APTMIRRORDIR$VARDIR dir of source tree at: $script"
    #echo "The destination script will be at: $destscript"
    DIROFSCRIPT=${destscript%/*}
    #echo "Making directory at: $DIROFSCRIPT"
    mkdir -p "$DIROFSCRIPT"
    #echo -e "\nSynchronizing the script file $script to $destscript"
    echo -n "."
    # For these "base" level files we use --update option instead of the --delete option
    # which updates the destination only if the source file is newer.
    # The rsync command's options in $RSYNC_OPTIONS below become: '-rvh --size-only'
    # if destination USB drive is not Linux ext4 (ntfs), otherwise they are '-avh --update'
    rsync $RSYNC_OPTIONS_2 -q "$script" "$destscript"
  done
  
  #echo "Synchronizing the ReadMe file to $2..."
    # For these "base" level files we use --update option instead of the --delete option
    # which updates the destination only if the source file is newer.
    # The rsync command's options in $RSYNC_OPTIONS below become: '-rvh --size-only'
    # if destination USB drive is not Linux ext4 (ntfs), otherwise they are '-avh --update'
  rsync $RSYNC_OPTIONS_2 -q "$1"/ReadMe "$2"
  #echo "Synchronizing the .pdf documents"
  echo -n "."
    # For these "base" level files we use --update option instead of the --delete option
    # which updates the destination only if the source file is newer.
    # The rsync command's options in $RSYNC_OPTIONS below become: '-rvh --size-only'
    # if destination USB drive is not Linux ext4 (ntfs), otherwise they are '-avh --update'
  rsync $RSYNC_OPTIONS_2 -q "$1"/*.pdf "$2"
  #echo "Synchronizing the .git and .gitignore files to $2..."
  echo -n "."
    # For these "base" level files we use --update option instead of the --delete option
    # which updates the destination only if the source file is newer.
    # The rsync command's options in $RSYNC_OPTIONS below become: '-rvh --size-only'
    # if destination USB drive is not Linux ext4 (ntfs), otherwise they are '-avh --update'
  rsync $RSYNC_OPTIONS_2 -q "$1"/.git* "$2"
  
  if [ -d "$1"$BILLSWASTADOCSDIR ]; then
    #echo "Synchronizing the $BILLSWASTADOCS dir and contents to $2$BILLSWASTADOCSDIR..."
    # For these "base" level files we use --update option instead of the --delete option
    # which updates the destination only if the source file is newer.
    # The rsync command's options in $RSYNC_OPTIONS below become: '-rvh --size-only'
    # if destination USB drive is not Linux ext4 (ntfs), otherwise they are '-avh --update'
    rsync $RSYNC_OPTIONS_2 -q "$1"$BILLSWASTADOCSDIR/ "$2"$BILLSWASTADOCSDIR/
    if [ -L "$1"/docs-index ]; then
      #echo -e "\nSymbolic link docs-index already exists at $1"
      echo -n "."
    else
      #echo -e "\nCreating symbolic link docs-index at $1"
      echo -n "."
      if [[ "$USBFSTYPE_1" != "vfat" ]]; then
        ln -s "$1"$BILLSWASTADOCSDIR/index.html "$1"/docs-index
      fi
    fi
    if [ -L "$2"/docs-index ]; then
      #echo "Symbolic link docs-index already exists at $2"
      echo -n "."
    else
      #echo "Creating symbolic link docs-index at $2"
      echo -n "."
      if [[ "$USBFSTYPE_2" != "vfat" ]]; then
        ln -s "$2"$BILLSWASTADOCSDIR/index.html "$2"/docs-index
      fi
    fi
  fi
  #echo "Exiting copy_mirror_base_dir_files function."
  return 0
}

# A bash function that calls chown to set the ownership of the passed in mirror to apt-mirror:apt-mirror
# and sets the permissions to read-write-execute for *.sh scripts and read-write for the mirror tree and
# other files at the root of the mirror tree.
# This function must have two parameters:
#   $1 is the base directory where the chown and chmod operations are to initiate.
#   $2 the destination drive's format, i.e., "ext4", "ntfs", "vfat", etc.
# The calling script should have assigned values to the following variables:
#   $BILLSWASTADOCSDIR
#   $WASTAOFFLINEDIR
#   $APTMIRROR
#   $APTMIRRORDIR
# Revised to bypass setting of ownership/permissions when the drive 
# at the $1 ($COPYTOBASEDIR) location is of type 'ntfs' or 'vfat' and the
# location represented by $COPYTOBASEDIR is at a USB /media/... location.
set_mirror_ownership_and_permissions ()
{
  # Although the destination may be a tree with no content created by the 'mkdir -p $COPYTODIR' call 
  # we can go ahead and take care of any mirror ownership and permissions issues for those
  # directories and files that exist, in case something has changed them. We don't want ownership
  # or permissions issues on any existing content there to foul up the sync operation.
  #echo -e "\nExecuting set_mirror_ownership_and_permissions function..."
  #echo "The 1 parameter is: $1"
  
  # If the $1 parameter (destination) root dir is /media, and if the $2 parameter 
  # is "ntfs" or "vfat" don't attempt to set any ownership or permissions, just return 0.
  ROOT_DIR_OF_COPYTOBASEDIR="/"$(echo "$1" | cut -d "/" -f2)
  if [[ "$ROOT_DIR_OF_COPYTOBASEDIR" == "/media" ]]; then
    if [[ "$2" == "ntfs" ]] || [[ "$2" == "vfat" ]]; then
      return 0
    fi
  fi
  
  if [ "$1" ]; then
    # Set ownership of the mirror tree starting at the wasta-offline directory
    #echo "SUDO_USER is: $SUDO_USER"
    #echo "Setting $1$WASTAOFFLINEDIR owner: $APTMIRROR:$APTMIRROR"
    #echo -n "."
    errorExit=0
    chown -R $APTMIRROR:$APTMIRROR "$1"$WASTAOFFLINEDIR
    result=$?
    if [ $result -ne 0 ]; then
      echo "ERROR $?: chown -R $APTMIRROR:$APTMIRROR $1$WASTAOFFLINEDIR"
      errorExit=1
    fi
    # Set ownership of the mirror tree at the apt-mirror-setup directory
    #echo "Setting $1$APTMIRRORSETUPDIR owner: $APTMIRROR:$APTMIRROR"
    #echo -n "." 
    chown -R $APTMIRROR:$APTMIRROR "$1"$APTMIRRORSETUPDIR
    result=$?
    if [ $result -ne 0 ]; then
      echo "ERROR $?: chown -R $APTMIRROR:$APTMIRROR $1$APTMIRRORSETUPDIR"
      errorExit=1
    fi
    # Set ownership of scripts, ReadMe file, and bills-wasta-docs directory to $SUDO_USER
    echo "Setting $1/*.sh owner: $SUDO_USER:$SUDO_USER and permissions: a+rwx"
    #echo -n "." 
    chown $SUDO_USER:$SUDO_USER "$1"/*.sh
    result=$?
    if [ $result -ne 0 ]; then
      echo "ERROR $?: chown $SUDO_USER:$SUDO_USER $1/*.sh"
      errorExit=1
    fi
    chmod a+rwx "$1"/*.sh
    result=$?
    if [ $result -ne 0 ]; then
      echo "ERROR $?: chmod a+rwx $1/*.sh"
      errorExit=1
    fi
    #echo "Setting $1/ReadMe owner: $SUDO_USER:$SUDO_USER"
    #echo -n "." 
    chown $SUDO_USER:$SUDO_USER "$1"/ReadMe
    result=$?
    if [ $result -ne 0 ]; then
      echo "ERROR $?: chown $SUDO_USER:$SUDO_USER $1/ReadMe"
      errorExit=1
    fi
    #echo "Setting $1$BILLSWASTADOCSDIR owner: $SUDO_USER:$SUDO_USER"
    #echo -n "." 
    chown -R $SUDO_USER:$SUDO_USER "$1"$BILLSWASTADOCSDIR
    result=$?
    if [ $result -ne 0 ]; then
      echo "ERROR $?: chown -R $SUDO_USER:$SUDO_USER $1$BILLSWASTADOCSDIR"
    fi
    echo "Setting content at $1 read-write for all: chmod -R a+rwX"
    #echo "   ... please wait"
    # whm 9Dec2021 revision - Set all files at $1 using chmod -R a+rwX $1, to 
    # give full permissions to everyone (-a, or 'a'll), but only set the 
    # executable bit (ie: use +X, NOT +x) if it is either a directory, OR 
    # already set for one or more of "user", "group", or "other".
    # With this approach, we don't need the find loops below for special
    # treatment of the *.sh script files, since they should have been made
    # executable already.
    #echo -n "." 
    #chmod -R ugo+rw "$1"
    chmod -R a+rwX "$1"
    result=$?
    if [ $result -ne 0 ]; then
      echo "ERROR $?: chmod -R a+rwX $1"
      errorExit=1
    fi
    if [ $errorExit -ne 0 ]; then
      # Error message is echo'ed in caller
      #echo "ERROR: NOT ALL OWNERSHIP/PERMISSIONS COULD BE SET"
      return 1
    fi 
    # The following find loops should no longer be needed
    # Find all Script files at $1 and set them read-write-executable
    # Note: The for loops with find command below should echo those in the last half of the 
    # copy_mirror_base_dir_files () function above.
    # for script in `find "$1" -maxdepth 1 -name '*.sh'` ; do 
    #   #echo "Setting $script executable"
    #   echo -n "." 
    #   chmod ugo+rwx "$script"
    # done
    # for script in `find "$1"$APTMIRRORSETUPDIR -maxdepth 1 -name '*.sh'` ; do 
    #   #echo "Setting $script executable"
    #   echo -n "." 
    #   chmod ugo+rwx "$script"
    # done
    # for script in `find "$1"$WASTAOFFLINEDIR$APTMIRRORDIR$VARDIR -maxdepth 1 -name '*.sh'` ; do 
    #   #echo "Setting $script executable"
    #   echo -n "." 
    #   chmod ugo+rwx "$script"
    # done
  fi
  #echo "Exiting set_mirror_ownership_and_permissions function."
  return 0
}

# A bash function that checks to see if an apt-mirror group exists and that the user 
# is a member of the apt-mirror group.
# Requires one parameter passed in which should be the name of the user. We cannot use
# $USER here because the script is running as root and $USER will be root. The passed
# in $1 parameter should be determined in the calling script before the calling script
# is running as root.
ensure_user_in_apt_mirror_group ()
{
  # Add apt-mirror to list of groups
  addgroup apt-mirror
  # The return value from addgroup will be 1 if the apt-mirror group already 
  # exists, 0 if apt-mirror was successfully added, > 1 if it couldn't add the
  # apt-mirror group. If the apt-mirror group already exists, the terminal 
  # output will say: "addgroup: The group `apt-mirror' already exists."
  # We'll ignore the return value of addgroup since it self-documents.
  # Add the non-root user's name passed in as $1 to the apt-mirror group
  # First, if passed-in parameter $1 ends up being 'root', return 0 early
  # without making any calls.
  if [ "$1" = "root" ]; then
    echo "Parameter passed in to ensure_user_in_apt_mirror_group was: $1"
    return 1  
  fi
  usermod -a -G apt-mirror "$1"
  LASTERRORLEVEL=$?
  if [ $LASTERRORLEVEL != 0 ]; then
    #echo -e "\nWARNING: Could not add user: $1 to the apt-mirror group"
    return $LASTERRORLEVEL
  fi
  return 0  
}

# A bash function that checks to see if the user has the old default location of /data
# for their master mirror, rather than the new default location of /data/master. If not
# the function just returns 0. If a master mirror was detected at the /data location,
# the function warns the user about potential spurious launchings of wasta-offline, and
# asks if the user wants a quick move of the master mirror to a better /data/master
# location. If no y response is given within 60 seconds, n is assumed and the script
# returns 1 to the caller indicating the caller should abort the operation.
# Note: If the user responded with y to the prompt, after the move has been done, the 
# user's /etc/apt/mirror.list file is also adjusted to use the new location for its 
# base_path setting, if apt-mirror is installed and mirror.list exists.
# Since the master mirror location is actually a git repository, the script also copies
# the .git folder and .gitignore file to the new location if available.
# This function is currently used only in the sync_Wasta-Offline_to_Ext_Drive.sh
# Once a user responds with y, the script will not prompt the user again, unless the
# master mirror is moved back to its old /data location.
move_mirror_from_data_to_data_master () # [No longer used]
{
  # Set up some constants for use in function only
  DATADIR="/data"
  MASTERDIR="/master"
  WASTAOFFLINEDIR="/wasta-offline"
  APTMIRRORDIR="/apt-mirror"
  APTMIRRORSETUPDIR="/apt-mirror-setup"
  BASH_FUNCTIONS_SCRIPT="bash_functions.sh"
  SYNC_TO_EXT_DRIVE_SCRIPT="sync_Wasta-Offline_to_Ext_Drive.sh"
  UPDATE_MIRROR_SCRIPT="update-mirror.sh"
  MAKE_MASTER_SCRIPT="make_Master_for_Wasta-Offline.sh"
  MIRRORDIR="/mirror"
  WAIT=60
  
  # Note: In the if test below, we could use the bash function 
  # is_there_a_wasta_offline_mirror_at () in the test. However, that is a more extensive
  # test for a full mirror with certain standard repository directories. Here I think
  # a simpler test is warranted in which we just check to see if there is a directory
  # tree of /data/wasta-offline/apt-mirror/mirror (regardless of contents) on the local 
  # computer.
  if [ -d $DATADIR$WASTAOFFLINEDIR$APTMIRRORDIR$MIRRORDIR ]; then
    echo -e "\nThere appears to be a master mirror at: "
    echo "   $DATADIR$WASTAOFFLINEDIR"
    echo "Your current mirror location at $DATADIR$WASTAOFFLINEDIR can cause spurious"
    echo "launchings of the wasta-offline program at bootup. We highly recommend"
    echo "your mirror be relocated a level deeper within $DATADIR to a $MASTERDIR"
    echo "sub-directory within the $DATADIR directory. This script can move the existing"
    echo "mirror for you using the mv command without having to copy data."
    echo "Do you want this script to do a fast move (mv) of your existing mirror to:"
    echo "   $DATADIR$MASTERDIR$WASTAOFFLINEDIR [y/n]?"
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
        mkdir -p $DATADIR$MASTERDIR
        # Check if /data/master already has files/data. If so, warn user to move/rename it first.
        # If /data/master dir exists, but it empty, all is OK for the move
        if [ "$(ls -A $DATADIR$MASTERDIR)" ]; then
          echo -e "\nCannot move master mirror directories to $DATADIR$MASTERDIR!"
          echo "A non-empty $MASTERDIR directory already exists in $DATADIR"
          echo "Move $MASTERDIR elsewhere out of $DATADIR or rename it, then run this script again."
          echo "Aborting..."
          return $LASTERRORLEVEL
        else
          echo "$DATADIR$MASTERDIR already exists but is empty"
        fi
        echo "Setting ownership of master directory to apt-mirror:apt-mirror"
        echo "Setting permissions of master directory to ugo+rw"
        chown -R apt-mirror:apt-mirror $DATADIR$MASTERDIR
        chmod -R ugo+rw $DATADIR$MASTERDIR
        echo "Relocating the master mirror from $DATADIR to: $DATADIR$MASTERDIR"
        #mv /data/wasta-offline /data/master/wasta-offline
        mv $DATADIR$WASTAOFFLINEDIR $DATADIR$MASTERDIR$WASTAOFFLINEDIR
        LASTERRORLEVEL=$?
        if [ $LASTERRORLEVEL != 0 ]; then
          echo -e "\nCannot move (mv) the master mirror directories to: $DATADIR$MASTERDIR"
          echo "Aborting..."
          return $LASTERRORLEVEL
        fi
        # Relocate the wasta-offline root dir scripts and git repo files/dirs if they exist
        # if any of these moves fail is it not really grounds for doing an abort
        if [ -f $DATADIR/$BASH_FUNCTIONS_SCRIPT ]; then
          echo "Relocating $BASH_FUNCTIONS_SCRIPT to: $DATADIR$MASTERDIR"
          mv $DATADIR/$BASH_FUNCTIONS_SCRIPT $DATADIR$MASTERDIR
        fi
        if [ -f $DATADIR/$SYNC_TO_EXT_DRIVE_SCRIPT ]; then
          echo "Relocating $SYNC_TO_EXT_DRIVE_SCRIPT to: $DATADIR$MASTERDIR"
          mv $DATADIR/$SYNC_TO_EXT_DRIVE_SCRIPT $DATADIR$MASTERDIR
        fi
        if [ -f $DATADIR/$UPDATE_MIRROR_SCRIPT ]; then
          echo "Relocating $UPDATE_MIRROR_SCRIPT from: $DATADIR to: $DATADIR$MASTERDIR"
          mv $DATADIR/$UPDATE_MIRROR_SCRIPT $DATADIR$MASTERDIR
        fi
        if [ -f $DATADIR/$MAKE_MASTER_SCRIPT ]; then
          echo "Relocating $MAKE_MASTER_SCRIPT to: $DATADIR$MASTERDIR"
          mv $DATADIR/$MAKE_MASTER_SCRIPT $DATADIR$MASTERDIR
        fi
        if [ -d $DATADIR/$APTMIRRORSETUPDIR ]; then
          echo "Relocating apt-mirror-setup dir and postmirror*.sh to: $DATADIR$MASTERDIR"
          mv $DATADIR/$APTMIRRORSETUPDIR $DATADIR$MASTERDIR
        fi
        # get array of any wasta-offline_*.deb files, and test if at least one exists
        wasta_offline_debs=( $DATADIR/wasta-offline_*.deb )
        if [ -e ${wasta_offline_debs[0]} ]; then
          echo "Relocating master mirror wasta-offline deb packages to: $DATADIR$MASTERDIR"
          mv $DATADIR/wasta-offline_*.deb $DATADIR$MASTERDIR
        fi
        if [ -f $DATADIR/ReadMe ]; then
          echo "Relocating master mirror ReadMe file to: $DATADIR$MASTERDIR"
          mv $DATADIR/ReadMe $DATADIR$MASTERDIR
        fi
        #mv $DATADIR/README.md $DATADIR$MASTERDIR
        if [ -d $DATADIR/.git ]; then
          echo "Relocating the .git directory to: $DATADIR$MASTERDIR"
          mv $DATADIR/.git $DATADIR$MASTERDIR
        fi
        if [ -f $DATADIR/.gitignore ]; then
          echo "Relocating the .gitignore file to: $DATADIR$MASTERDIR"
          mv $DATADIR/.gitignore $DATADIR$MASTERDIR
        fi
        # Adjust the user's mirror.list file to point to the new master mirror location
        echo "Modifying base_path in mirror.list file to use the new base_path: "
        echo "   $DATADIR$MASTERDIR$WASTAOFFLINEDIR$APTMIRRORDIR"
        sed -i 's|'$DATADIR$WASTAOFFLINEDIR$APTMIRRORDIR'|'$DATADIR$MASTERDIR$WASTAOFFLINEDIR$APTMIRRORDIR'|g' /etc/apt/mirror.list
        # All moves now completed so just return 0 for success
        return 0
        ;;
     *)
        echo -e "\nNo action taken! Aborting..."
        return 1
        ;;
    esac
  else
    # no old /data mirror location detected, so just return 0
    return 0
  fi
}

generate_mirror_list_file ()
{
  # A bash function that generates a custom mirror.list file with the proper settings and
  # URL protocol prefixes needed for the location of the user's mirror.
  # The URL protocol must be passed as the single parameter, i.e., $UkarumpaURLPrefix,
  # $InternetURLPrefix, or $CustomURLPrefix.
  # If this function succeeds it returns 0. If it fails it returns 1.
  # This function makes a backup of any existing mirror.list file to mirror.list.save if the 
  # following line is NOT already present at the top of the existing mirror.list file:
  # ###_This_file_was_generated_by_the_update-mirror.sh_script_###
  # The main program ensures that apt-mirror has already been installed, but there is no problem
  # if this routine were to create a custom mirror.list before apt-mirror gets installed.
  # NOTE: The inventory of software repositories that get downloaded by apt-mirror is
  # controlled by the "here-document" part of this function below, between the cat <<EOF ...
  # and EOF lines. Existing repositories can be removed by commenting out the appropriate
  # deb-amd64 and deb-i386 lines or adding additional repositories. The Full Wasta-Offline Mirror
  # supplied by Bill Martin will always have both deb-amd64 and deb-i386 packages for the
  # "full" mirror.
  # The "full" mirror generated by this function, currently manages about 750GB of mirror data.
  # The calling script should have assigned values to the following variables:
  #   $GENERATEDSIGNATURE
  #   $LOCALMIRRORSPATH
  #   $ETCAPT
  #   $MIRRORLIST
  #   $SAVEEXT
  #
  # Variables that get expanded while generating the mirror.list file:
  #   $GENERATEDSIGNATURE is "###_This_file_was_generated_by_the_update-mirror.sh_script_###"
  #   $1 is the URL Prefix passed in as the parameter of the function call (http://, ftp://..., 
  #   http://linuxrepo.sil.org.pg/mirror/..., etc).
  #   $LOCALMIRRORSPATH is base path to the mirror (usually /media/<DISK_LABEL>/wasta-offline/apt-mirror,
  #      or /media/$USER/<DISK_LABEL>/wasta-offline/apt-mirror, but can also be 
  #      /data/wasta-offline/apt-mirror for the master copy of the full mirror)
  #   $ARCHIVESECURITY is either "archive" (for Ukarumpa FTP mirror), or "security" (for the
  #      remote Internet mirror).
  # This function is currently used in the updata-mirror.sh, and make_Master_for_Wasta-Offline.sh scripts.
  # Revised 22 March 2016 by Bill Martin:
  #   Change LibreOffice versions to include 4-2, 4-4, 5-0, 5-1
  #   Add Linux Mint Rosa to the list
  # Revised 3 May 2016 by Bill Martin:
  #   Added the Ubuntu Xenial and Linux Mint Sarah repos to the list
  #   Note: LibreOffice versions 5-X and above only are supported in Xenial and Sarah
  # Revised 20 June 2017 by Bill Martin:
  #   Added the LibreOffice libreoffice-5-2 and libreoffice-5-3 repos to Trusty and Xenial
  #   Added the Linux Mint Serena and Sonya repos to the list
  # Revised 30 September 2018 by Bill Martin:
  #   Added the Ubuntu Bionic repos to the list
  #   Removed the precise/maya repos as they are no longer supported
  #   Added the LibreOffice libreoffice-5-4 and libreoffice-6-0 repos 
  #   Added the Linux Mint Sylvia 18.3 Tara 19 and Tessa 19.1 repos to the list
  #   Added special https protocol for Skype repo
  # Revised 25 January 2019 by Bill Martin:
  #   Removed the security.ubuntu.com repository which only duplicates the <dist>-security repos in archive.ubuntu.com
  # Revised 17 June 2020 by Bill Martin:
  #   Removed no-longer-supported Linux Mint distros 17.x
  #   Added the Ubuntu Focal repos to the list
  #   Added the LibreOffice libreoffice-6-1 through 6-4 to Bionic
  #   Updated the clean list by adding libreoffice-6-1 through 6-4

  # If this is the first generation of mirror.list, first back up the user's existing mirror.list
  # to mirror.list.save. The existing mirror.list file won't have the $GENERATEDSIGNATURE in the
  # file. The grep -Fq command below returns non-zero if it fails to find the signature.
  grep -Fq "$GENERATEDSIGNATURE" $ETCAPT$MIRRORLIST
  GREPRESULTINT=$?
  if [ $GREPRESULTINT -ne 0 ]; then
    # The generated signature text was NOT found in the mirror.list file, so back up mirror.list 
    # to mirror.list.save 
    echo -e "\nBacking up $ETCAPT$MIRRORLIST to $ETCAPT$MIRRORLIST$SAVEEXT"
    cp -f $ETCAPT$MIRRORLIST $ETCAPT$MIRRORLIST$SAVEEXT
  fi

  #echo -e "\n"
  #echo "LOCALMIRRORSPATH is $LOCALMIRRORSPATH"
  
  # whm 23 November 2018 Note: The /etc/apt/sources.list configuration file of some 
  # Linux distributions pointed to security.ubuntu.com/ubuntu, whereas others pointed
  # to archive.ubuntu.com/ubuntu for security updates (trusty-security, xenial-security,
  # and bionic-security). The reality is that these *-security update repos are currently
  # located in both security.ubuntu.com/ubuntu and archive.ubuntu.com/ubuntu. Hence,
  # below we will only use the "archive" string for the $ARCHIVESECURITY variable. 
  # As of 25 January 2019 I've removed the security.ubuntu.com source from mirror.list, 
  # since it takes up an additional 165GB of space of duplicated data.
  # Note: According to Cambell Prince the packages.palaso.org repo no longer exists, so 
  # that all future palaso software will be released via the packages.sil.org repository.
  #if [ $1 = $FTPUkarumpaURLPrefix ]; then
    ARCHIVESECURITY="archive"
  #else
  #  ARCHIVESECURITY="security"
  #fi
  
  echo -e "\nGenerating $MIRRORLIST configuration file at $MIRRORLISTPATH..."
  
  SKYPEURL="repo.skype.com/deb"
  if [[ "$1" == "http://"* ]]; then 
    SKYPEPATH=${1#http://}
    SKYPEPREFIX="https://$SKYPEURL"
  else
    SKYPEPREFIX="$1"$SKYPEURL
  fi
  #echo "SKYPEPATH is: $SKYPEPATH"
  #echo "SKYPEPREFIX is: $SKYPEPREFIX"
  
  # The code below generates a custom /etc/apt/mirror.list configuration file on the fly for the user. 
  # Any changes deemed necessary to the content of mirror.list that gets generated by this script, 
  # should be made within the "here-document" content below, rather than directly to the user's 
  # /etc/apt/mirror.list file.
  #
  # The following uses "here-document" redirection which tells the shell to read from the current
  # source until the line containing EOF is seen. As long as the command is cat <<EOF and not quoted
  # as cat <<"EOF", parameter expansion happens for $LOCALMIRRORSPATH, $1, $SKYPEPREFIX and $ARCHIVESECURITY.
  # The /etc/apt/mirror.list file is created from scratch each time this script is run.
  # Within functions, $1 is the first parameter that is provided with the function call. In this
  # case, $1 is either $UkarumpaURLPrefix, $FTPUkarumpaURLPrefix, $InternetURLPrefix, or 
  # $CustomURLPrefix depending on the user's selection in the main program (see below).
  #
cat <<EOF >$MIRRORLISTPATH
$GENERATEDSIGNATURE
############# config ##################
#
set base_path    $LOCALMIRRORSPATH
#
# set mirror_path  $LOCALMIRRORSPATH/mirror
# set skel_path    $LOCALMIRRORSPATH/skel
# set var_path     $LOCALMIRRORSPATH/var
# set cleanscript $LOCALMIRRORSPATH/var/clean.sh
# set defaultarch  <running host architecture>
# set postmirror_script $LOCALMIRRORSPATH/var/postmirror.sh
# set run_postmirror 0
set nthreads     20
set _tilde 0
#
############# end config ##############

# whm 23 November 2018 Note: the precise (12.04) distribution is no longer supported

# ######### trusty #############
# whm 17Jun2020 NOTE: The trusty repo below ended "standard support" April 2019, and 
# will be at its "End of Life" in April 2022. In order to fit all distros on a 
# 1TB external drive, I've removed trusty repo and the Linux Mint distros (those 
# before sarah) that are aliases for trusty.
# ######### trusty #############

# ######### Linux Mint packages repo ###############################
# Note: the following are for wasta 14.04.2 / Linux Mint 17.1 Rebecca
# whm 17Jun2020 Removed Linux Mint 17.1 Rebecca
# Note: the following are for wasta 14.04.3 / Linux Mint 17.2 Rafaela
# whm 17Jun2020 Removed Linux Mint 17.2 Rafaela
# Note: the following are for Linux Mint 17.3 Rosa
# whm 17Jun2020 Removed Linux Mint 17.3 Rosa
# whm 29Nov2021 Removed Linux Mint 17.3 Rosa
# whm added 3 May 2016 Linux Mint 18.0 Sarah
# whm 29Nov2021 Removed Linux Mint 18.0 Sarah
# whm added 16 June 2017 Linux Mint 18.1 Serena
# whm 29Nov2021 Removed  Linux Mint 18.1 Serena
# whm added 16 June 2017 Linux Mint 18.2 Sonya
# whm 29Nov2021 Removed Linux Mint 18.2 Sonya
# whm added 30 September 2018 Linux Mint 18.3 Sylvia
# whm added 29Nov2021 Removed 2018 Linux Mint 18.3 Sylvia

# whm added 30 September 2018 Linux Mint 19 Tara
deb-amd64 $1packages.linuxmint.com/ tara main upstream import backport
deb-i386 $1packages.linuxmint.com/ tara main upstream import backport

# whm added 30 September 2018 Linux Mint 19.1 Tessa
deb-amd64 $1packages.linuxmint.com/ tessa main upstream import backport
deb-i386 $1packages.linuxmint.com/ tessa main upstream import backport

# whm added 17 June 2020 Linux Mint 19.2 Tina
deb-amd64 $1packages.linuxmint.com/ tina main upstream import backport
deb-i386 $1packages.linuxmint.com/ tina main upstream import backport

# whm added 17 June 2020 Linux Mint 19.3 Tricia
deb-amd64 $1packages.linuxmint.com/ tricia main upstream import backport
deb-i386 $1packages.linuxmint.com/ tricia main upstream import backport

# whm added 17 June 2020 Linux Mint 20.0 Ulyana
deb-amd64 $1packages.linuxmint.com/ ulyana main upstream import backport
deb-i386 $1packages.linuxmint.com/ ulyana main upstream import backport

# whm added 29Nov2021 Linux Mint 20.1 Ulyssa
deb-amd64 $1packages.linuxmint.com/ ulyssa main upstream import backport
deb-i386 $1packages.linuxmint.com/ ulyssa main upstream import backport

# whm added 29Nov2021 Linux Mint 20.2 Uma
deb-amd64 $1packages.linuxmint.com/ uma main upstream import backport
deb-i386 $1packages.linuxmint.com/ uma main upstream import backport

# whm added 29Nov2021 Linux Mint 20.3 Una
deb-amd64 $1packages.linuxmint.com/ una main upstream import backport
deb-i386 $1packages.linuxmint.com/ una main upstream import backport
# ######### Linux Mint packages repo ###############################

# ######### xenial #############
# whm added 3 May 2016 xenial repos below:
deb-amd64 $1archive.ubuntu.com/ubuntu xenial main restricted universe multiverse
deb-i386 $1archive.ubuntu.com/ubuntu xenial main restricted universe multiverse
deb-amd64 $1archive.ubuntu.com/ubuntu xenial-updates main restricted universe multiverse
deb-i386 $1archive.ubuntu.com/ubuntu xenial-updates main restricted universe multiverse
# whm 29Nov2021 removed xenial-backports
#deb-amd64 $1archive.ubuntu.com/ubuntu xenial-backports main restricted universe multiverse
#deb-i386 $1archive.ubuntu.com/ubuntu xenial-backports main restricted universe multiverse

# The Ukarumpa mirrors point to archive.ubuntu.com/ubuntu <dist>-security.  
# Note: The remote mirrors at archive.ubuntu.com/ubuntu <dist>-security and 
# security.ubuntu.com/ubuntu <dist>-security contain the same packages and updates.
deb-amd64 $1$ARCHIVESECURITY.ubuntu.com/ubuntu xenial-security main restricted universe multiverse
deb-i386 $1$ARCHIVESECURITY.ubuntu.com/ubuntu xenial-security main restricted universe multiverse

deb-amd64 $1archive.canonical.com/ubuntu xenial partner
deb-i386 $1archive.canonical.com/ubuntu xenial partner

deb-amd64 $1packages.sil.org/ubuntu xenial main
deb-i386 $1packages.sil.org/ubuntu xenial main
deb-amd64 $1packages.sil.org/ubuntu xenial-experimental main
deb-i386 $1packages.sil.org/ubuntu xenial-experimental main
#deb-amd64 $1download.virtualbox.org/virtualbox/debian xenial contrib
#deb-i386 $1download.virtualbox.org/virtualbox/debian xenial contrib

# Note: the following are referenced in separate .list files in /etc/apt/sources.list.d/
deb-amd64 $1ppa.launchpad.net/keymanapp/keyman/ubuntu xenial main
deb-i386 $1ppa.launchpad.net/keymanapp/keyman/ubuntu xenial main
deb-amd64 $1ppa.launchpad.net/wasta-linux/cinnamon-3-6/ubuntu xenial main
deb-i386 $1ppa.launchpad.net/wasta-linux/cinnamon-3-6/ubuntu xenial main
deb-amd64 $1ppa.launchpad.net/wasta-linux/wasta-apps/ubuntu xenial main
deb-i386 $1ppa.launchpad.net/wasta-linux/wasta-apps/ubuntu xenial main
deb-amd64 $1ppa.launchpad.net/wasta-linux/wasta/ubuntu xenial main
deb-i386 $1ppa.launchpad.net/wasta-linux/wasta/ubuntu xenial main

# libreoffice versions 5-1 and 6-0 are only versions available in xenial as of 29Nov2021
deb-amd64 $1ppa.launchpad.net/libreoffice/libreoffice-5-1/ubuntu xenial main
deb-i386 $1ppa.launchpad.net/libreoffice/libreoffice-5-1/ubuntu xenial main
deb-amd64 $1ppa.launchpad.net/libreoffice/libreoffice-6-0/ubuntu xenial main
deb-i386 $1ppa.launchpad.net/libreoffice/libreoffice-6-0/ubuntu xenial main
# ######### xenial #############

# ######### bionic #############
# whm added 30 September 2018 bionic repos below:
deb-amd64 $1archive.ubuntu.com/ubuntu bionic main restricted universe multiverse
deb-i386 $1archive.ubuntu.com/ubuntu bionic main restricted universe multiverse
deb-amd64 $1archive.ubuntu.com/ubuntu bionic-updates main restricted universe multiverse
deb-i386 $1archive.ubuntu.com/ubuntu bionic-updates main restricted universe multiverse
deb-amd64 $1archive.ubuntu.com/ubuntu bionic-backports main restricted universe multiverse
deb-i386 $1archive.ubuntu.com/ubuntu bionic-backports main restricted universe multiverse

# The Ukarumpa mirrors point to archive.ubuntu.com/ubuntu <dist>-security.  
# Note: The remote mirrors at archive.ubuntu.com/ubuntu <dist>-security and 
# security.ubuntu.com/ubuntu <dist>-security contain the same packages and updates.
deb-amd64 $1$ARCHIVESECURITY.ubuntu.com/ubuntu bionic-security main restricted universe multiverse
deb-i386 $1$ARCHIVESECURITY.ubuntu.com/ubuntu bionic-security main restricted universe multiverse

deb-amd64 $1archive.canonical.com/ubuntu bionic partner
deb-i386 $1archive.canonical.com/ubuntu bionic partner

# Note: the following are referenced in separate .list files in /etc/apt/sources.list.d/
deb-amd64 $1packages.sil.org/ubuntu bionic main
deb-i386 $1packages.sil.org/ubuntu bionic main
deb-amd64 $1packages.sil.org/ubuntu bionic-experimental main
deb-i386 $1packages.sil.org/ubuntu bionic-experimental main
deb-amd64 $1ppa.launchpad.net/keymanapp/keyman/ubuntu bionic main
deb-i386 $1ppa.launchpad.net/keymanapp/keyman/ubuntu bionic main
deb-amd64 $1ppa.launchpad.net/wasta-linux/cinnamon-3-8/ubuntu bionic main
deb-i386 $1ppa.launchpad.net/wasta-linux/cinnamon-3-8/ubuntu bionic main
deb-amd64 $1ppa.launchpad.net/wasta-linux/wasta-apps/ubuntu bionic main
deb-i386 $1ppa.launchpad.net/wasta-linux/wasta-apps/ubuntu bionic main
deb-amd64 $1ppa.launchpad.net/wasta-linux/wasta/ubuntu bionic main
deb-i386 $1ppa.launchpad.net/wasta-linux/wasta/ubuntu bionic main

# libreoffice versions 6-0 6-4 and 7-0 are the only versions available in bionic as of 29Nov2021
deb-amd64 $1ppa.launchpad.net/libreoffice/libreoffice-6-0/ubuntu bionic main
deb-i386 $1ppa.launchpad.net/libreoffice/libreoffice-6-0/ubuntu bionic main
deb-amd64 $1ppa.launchpad.net/libreoffice/libreoffice-6-4/ubuntu bionic main
deb-i386 $1ppa.launchpad.net/libreoffice/libreoffice-6-4/ubuntu bionic main
deb-amd64 $1ppa.launchpad.net/libreoffice/libreoffice-7-0/ubuntu bionic main
deb-i386 $1ppa.launchpad.net/libreoffice/libreoffice-7-0/ubuntu bionic main
# ######### bionic #############

# ######### focal #############
# whm modified 3Dec2021 focal repos below: (to include packages for i386 architecture)
deb-amd64 $1archive.ubuntu.com/ubuntu focal main restricted
deb-i386 $1archive.ubuntu.com/ubuntu focal main restricted
deb-amd64 $1archive.ubuntu.com/ubuntu focal-updates main restricted
deb-i386 $1archive.ubuntu.com/ubuntu focal-updates main restricted
deb-amd64 $1archive.ubuntu.com/ubuntu focal universe
deb-i386 $1archive.ubuntu.com/ubuntu focal universe
deb-amd64 $1archive.ubuntu.com/ubuntu focal-updates universe
deb-i386 $1archive.ubuntu.com/ubuntu focal-updates universe
deb-amd64 $1archive.ubuntu.com/ubuntu focal multiverse
deb-i386 $1archive.ubuntu.com/ubuntu focal multiverse
deb-amd64 $1archive.ubuntu.com/ubuntu focal-updates multiverse
deb-i386 $1archive.ubuntu.com/ubuntu focal-updates multiverse
deb-amd64 $1archive.ubuntu.com/ubuntu focal-backports main restricted universe multiverse
deb-i386 $1archive.ubuntu.com/ubuntu focal-backports main restricted universe multiverse
deb-amd64 $1archive.canonical.com/ubuntu focal partner
deb-i386 $1archive.canonical.com/ubuntu focal partner
deb-amd64 $1archive.ubuntu.com/ubuntu focal-security main restricted
deb-i386 $1archive.ubuntu.com/ubuntu focal-security main restricted
deb-amd64 $1archive.ubuntu.com/ubuntu focal-security universe
deb-i386 $1archive.ubuntu.com/ubuntu focal-security universe
deb-amd64 $1archive.ubuntu.com/ubuntu focal-security multiverse
deb-i386 $1archive.ubuntu.com/ubuntu focal-security multiverse

# The following are referenced in separate .list files in /etc/apt/sources.list.d/:
deb-amd64 $1packages.sil.org/ubuntu focal main
deb-i386 $1packages.sil.org/ubuntu focal main
deb-amd64 $1packages.sil.org/ubuntu focal-experimental main
deb-i386 $1packages.sil.org/ubuntu focal-experimental main
deb-amd64 $1ppa.launchpad.net/keymanapp/keyman/ubuntu focal main
deb-i386 $1ppa.launchpad.net/keymanapp/keyman/ubuntu focal main
deb-amd64 $1ppa.launchpad.net/wasta-linux/cinnamon-4-8/ubuntu focal main
deb-i386 $1ppa.launchpad.net/wasta-linux/cinnamon-4-8/ubuntu focal main
deb-amd64 $1ppa.launchpad.net/wasta-linux/wasta/ubuntu focal main
deb-i386 $1ppa.launchpad.net/wasta-linux/wasta/ubuntu focal main
deb-amd64 $1ppa.launchpad.net/wasta-linux/wasta-apps/ubuntu focal main
deb-i386 $1ppa.launchpad.net/wasta-linux/wasta-apps/ubuntu focal main

# libreoffice versions 6-4 and 7-0 are the only versions available in focal as of 29Nov2021
deb-amd64 $1ppa.launchpad.net/libreoffice/libreoffice-6-4/ubuntu focal main
deb-i386 $1ppa.launchpad.net/libreoffice/libreoffice-6-4/ubuntu focal main
deb-amd64 $1ppa.launchpad.net/libreoffice/libreoffice-7-0/ubuntu focal main
deb-i386 $1ppa.launchpad.net/libreoffice/libreoffice-7-0/ubuntu focal main
# Libreoffice "Fresh" version 7-1 is available for focal as of 25Nov2021
deb-amd64 $1ppa.launchpad.net/libreoffice/ppa/ubuntu focal main
deb-i386 $1ppa.launchpad.net/libreoffice/ppa/ubuntu focal main
# ######### focal #############

# Note: the following are referenced in separate .list files in /etc/apt/sources.list.d/
# whm added 26 November 2018 Skype repos below must use https:// protocol (see SKYPEPREFIX
# varirable calculation in generate_mirror_list_file () function in bash_functions.sh).
# Note: Skype for Linux is generic package not having specific versions for a given Linux 
# distribution.
deb-amd64 $SKYPEPREFIX stable main
deb-i386 $SKYPEPREFIX stable main
deb-amd64 $SKYPEPREFIX unstable main
deb-i386 $SKYPEPREFIX unstable main

# calling clean for obsolete repo items doesn't cause any error
clean $1packages.linuxmint.com/
clean $1extra.linuxmint.com/
clean $1archive.ubuntu.com/ubuntu
clean $1extras.ubuntu.com/ubuntu
clean $1archive.canonical.com/ubuntu
clean $1packages.sil.org/ubuntu
clean $SKYPEPREFIX
#clean $1download.virtualbox.org/virtualbox/debian
clean $1ppa.launchpad.net/wasta-linux/wasta-apps/ubuntu
clean $1ppa.launchpad.net/wasta-linux/wasta/ubuntu
clean $1ppa.launchpad.net/libreoffice/libreoffice-5-0/ubuntu
clean $1ppa.launchpad.net/libreoffice/libreoffice-5-1/ubuntu
clean $1ppa.launchpad.net/libreoffice/libreoffice-5-4/ubuntu
clean $1ppa.launchpad.net/libreoffice/libreoffice-6-0/ubuntu
clean $1ppa.launchpad.net/libreoffice/libreoffice-6-1/ubuntu
clean $1ppa.launchpad.net/libreoffice/libreoffice-6-2/ubuntu
clean $1ppa.launchpad.net/libreoffice/libreoffice-6-3/ubuntu
clean $1ppa.launchpad.net/libreoffice/libreoffice-6-4/ubuntu
clean $1ppa.launchpad.net/libreoffice/libreoffice-7-0/ubuntu
clean $1ppa.launchpad.net/libreoffice/ppa/ubuntu

EOF
  LASTERRORLEVEL=$?
  return $LASTERRORLEVEL
}

# A bash function that determines if a full wasta-offline mirror exists at the given
# path passed in as a single parameter. Parameter will be either $COPYFROMDIR or $COPYTODIR
# when the is_there_a_wasta_offline_mirror_at () function is called.
# Returns 0 if a full wasta-offline mirror exists at $1, otherwise returns 1.
# Revised: 17 April 2016 to correct logic and remove libreoffice repo tests
# A single optional parameter must be used which should be the absolute path to the
# wasta-offline directory of an apt-mirror generated mirror tree. For example,
# /data/master/wasta-offline or /media/$USER/<DISK_LABEL>/wasta-offline.
# A "full" wasta-offline mirror should have the following mirrors:
# List of Mirrors and Repos:
# As of January 2019 these are the mirrors and the repositories that we use in the
# full Wasta-Linux Mirror as supplied by Bill Martin
#   Mirror                                        Repos
#   --------------------------------------------------------------------------------
#   archive.canonical.com                          partner
#   archive.ubuntu.com                             main multiverse restricted universe
#   extras.ubuntu.com                              main
#   packages.linuxmint.com                         backport import main upstream
#   packages.sil.org                               main
#   *ppa.launchpad.net/libreoffice/libreoffice-5-0 main
#   *ppa.launchpad.net/libreoffice/libreoffice-5-1 main
#   *ppa.launchpad.net/libreoffice/libreoffice-5-4 main
#   *ppa.launchpad.net/libreoffice/libreoffice-6-0 main
#   ppa.launchpad.net/wasta-linux/wasta            main
#   ppa.launchpad.net/wasta-linux/wasta-apps       main
# 
# Note: the libreoffice mirrors above marked with * are not included in our test for presence of a wasta-offline mirror.
# For each of the above Repos we include both binary-i386 and binary-amd64 architecture packages. 
is_there_a_wasta_offline_mirror_at ()
{
  # The following constants are used exclusively in this is_there_a_wasta_offline_mirror_at () function:
  #The input parameter $1 is assigned to PATHTOMIRROR which varies between /data/master and /media/$USER/<DISK_LABEL>
  # 17 Apr 2016 whm removed the libreoffice mirrors from $UBUNTUMIRRORS list (they have repos for specific versions)
  PATHTOMIRROR=$1  # Assign the parameter, normally /data/master/wasta-offline or /media/$USER/<DISK_LABEL>/wasta-offline
  UBUNTUMIRRORS=("archive.ubuntu.com" "packages.sil.org" "ppa.launchpad.net/wasta-linux/wasta" "ppa.launchpad.net/wasta-linux/wasta-apps")
  UBUNTUDISTS=("xenial" "focal")
  LINUXMINTDISTS=("tara" "tessa" "tina")
  UBUNTUSECUREDISTS=("xenial-security")
  UBUNTUREPOS=("main" "multiverse" "restricted" "universe")
  LINUXMINTREPOS=("backport" "import" "main" "upstream")
  ARCHS=("binary-amd64")  # Note: "focal" doesn't have i386 architecture so I've removed "binary-i386" from ARCHS list
  full_mirror_exists="TRUE" # assume the mirrors exist unless one or more are missing

  # Check to see if there is a valid wasta-offline path at the $1 parameter location. If not,
  # return 1 (for failure)
  if [ ! -d "$1" ]; then
    return 1
  fi
  
  #echo "Performing checks in wasta-offline data tree..."
  # Note: We won't survey all the repos that exist for each of the mirrors in the above
  # chart. We will survey only one repo in each of the mirrors - the "main" repo in all
  # mirrors except for the canonical mirror which only has a "partner" repo. Hence, we won't
  # check for the existence of multiverse restricted and universe in the archive.ubuntu.com
  # and security.ubuntu.com mirrors, nor will we check for the existence of backport,
  # import and upstream in the packages.linuxmint.com mirror. Even so, 40 tests for existence
  # of directories will be made. If all are present the full_mirror_exists value will
  # remain "TRUE" and the function returns 0 for success. If any of those 40 are missing the 
  # full_mirror_exists value will be "FALSE" and the function returns 1 for failure.

  # Group 1 use three embedded for loops: outer loop for mirror in $UBUNTUMIRRORS, middle loop 
  # for dist in $UBUNTUDISTS; inner loop for arch in $ARCHS
  # Path: $PATHTOMIRROR/apt-mirror/mirror/$mirror/ubuntu/dists/$dist/main/$arch
  # Number of tests to be made: 28
  for mirror in "${UBUNTUMIRRORS[@]}"
  do
    for dist in "${UBUNTUDISTS[@]}"
    do
      for arch in "${ARCHS[@]}"
      do
        if [ ! -d "$PATHTOMIRROR/apt-mirror/mirror/$mirror/ubuntu/dists/$dist/main/$arch" ]; then
          full_mirror_exists="FALSE"
          echo -n "x"
          #echo "not found: $PATHTOMIRROR/apt-mirror/mirror/$mirror/ubuntu/dists/$dist/main/$arch"
          break
        else
          echo -n "." #"Found: $PATHTOMIRROR/apt-mirror/mirror/$mirror/ubuntu/dists/$dist/main/$arch"
        fi
      done
    done
  done

  # Group 2 use two embedded for loops: outer loop for dist in $UBUNTUDISTS; inner loop for arch in $ARCHS
  # Path: $PATHTOMIRROR/apt-mirror/mirror/archive.canonical.com/ubuntu/dists/$dist/partner/$arch
  # Number of tests to be made: 4
  for dist in "${UBUNTUDISTS[@]}"
  do
    for arch in "${ARCHS[@]}"
    do
      if [ ! -d "$PATHTOMIRROR/apt-mirror/mirror/archive.canonical.com/ubuntu/dists/$dist/partner/$arch" ]; then
        full_mirror_exists="FALSE"
        break
      else
        echo -n "." #"Found: $PATHTOMIRROR/apt-mirror/mirror/archive.canonical.com/ubuntu/dists/$dist/partner/$arch"
      fi
    done
  done

  # Group 3 use two embedded for loops: outer loop for dist in $LINUXMINTDISTS; inner loop for arch in $ARCHS
  # Path: $PATHTOMIRROR/apt-mirror/mirror/packages.linuxmint.com/dists/$dist/main/$arch
  # Number of tests to be made: 4
  for dist in "${LINUXMINTDISTS[@]}"
  do
    for arch in "${ARCHS[@]}"
    do
      if [ ! -d "$PATHTOMIRROR/apt-mirror/mirror/packages.linuxmint.com/dists/$dist/main/$arch" ]; then
        full_mirror_exists="FALSE"
        break
      else
        echo -n "." #"Found: $PATHTOMIRROR/apt-mirror/mirror/packages.linuxmint.com/dists/$dist/main/$arch"
      fi
    done
  done

  # whm 25Jan2019 removed the security.ubuntu.com tests, since security.ubuntu.com duplicates the <dist>-security
  # mirrors, and has been removed from the full Wasta-Offline Mirror.
  # Group 4 use two embedded for loops: outer loop for dist in $UBUNTUSECUREDISTS; inner loop for arch in $ARCHS
  # Path: $PATHTOMIRROR/apt-mirror/mirror/security.ubuntu.com/ubuntu/dists/$dist/main/$arch
  # Number of tests to be made: 4
  #for dist in "${UBUNTUSECUREDISTS[@]}"
  #do
  #  for arch in "${ARCHS[@]}"
  #  do
  #    if [ ! -d "$PATHTOMIRROR/apt-mirror/mirror/security.ubuntu.com/ubuntu/dists/$dist/main/$arch" ]; then
  #      full_mirror_exists="FALSE"
  #      break
  #    else
  #      echo -n "." #"Found: $PATHTOMIRROR/apt-mirror/mirror/security.ubuntu.com/ubuntu/dists/$dist/main/$arch"
  #    fi
  #  done
  #done

  if [ "$full_mirror_exists" = "TRUE" ]; then
    return 0
  else
    return 1
  fi
}

# A bash function that determines if one wasta-offline mirror is older, same or newer than 
# another one.
# The calling script should have assigned values to the following variables:
#   $LastAppMirrorUpdate
# Returns 0 if the mirror at $1 is older than the mirror at $2
# Returns 1 if the mirror at $1 is newer than the mirror at $2
# Returns 2 if the mirror at $1 has the same timestamp as the mirror at $2
# Returns 3 if failed to find a valid wasta-offline path at the $1 parameter
# Returns 4 if failed to find a valid wasta-offline path at the $2 parameter
# Returns 5 if failed due to a programming error (source and destination mirrors are the same)
# Returns 6 if failed due to a programming error (parameters to function not provided)
# Returns 7 if failed to find a $LastAppMirrorUpdate file in the destination mirror tree
# Must be called with 2 parameters. The first parameter should be the absolute path to the 
# wasta-offline directory of a wasta-offline mirror, that a previous call to 
# is_there_a_wasta_offline_mirror_at () has determined contains a wasta-offline mirror. 
# The second parameter likewise should be the absolute path to a different wasta-offline 
# directory, that a previous call to is_there_a_wasta_offline_mirror_at () has also 
# determined contains a wasta-offline mirror.
# Note: The script's command-line arguments $1, $2, etc, are not visible within functions 
# declared within the script - unless $1, $2, etc. are passed as parameters to the function
# in the function call.
is_this_mirror_older_than_that_mirror ()
{
  #echo "Destination mirror is at: $1"
  #echo "Source mirror is at: $2"
  # Check that both parameters were provided by caller
  if [[ "$1" = "" ]] || [[ "$2" = "" ]]; then
    # Programming Error
    return 6
  fi

  # Check that both parameters point to valid wasta-offline directories.
  # Check to see if there is a valid wasta-offline path at the $1 parameter location. If not,
  # return 1 (for failure)
  if [ ! -d "$1" ]; then
    return 3
  fi
  # Check to see if there is a valid wasta-offline path at the $2 parameter location. If not,
  # return 1 (for failure)
  if [ ! -d "$2" ]; then
    return 4
  fi

  # Check that the parateters given to this function point to different mirrors.
  if [ "$1" = "$2" ]; then
    # Programming Error
    return 5
  fi

  # Check to see if the destination mirror ($1) has a $LastAppMirrorUpdate file. If not we assume
  # that the destination tree is older
  LastAppMirrorUpdate="last-apt-mirror-update" # used in is_this_mirror_older_than_that_mirror () function
  if ! [ -f "$1/log/$LastAppMirrorUpdate" ]; then
    # No $LastAppMirrorUpdate file found at destination
    return 7
  fi

  # Check the Unix timestamps of the $1 mirror and $2 mirror. If the $1 mirror timestamp is the
  # same or newer (same or smaller number of seconds), then return 1 (False in Bash-logic). 
  # If the $1 timestamp is older (larger number of seconds) then return 0 (True in Bash-logic).

  # Get the $1 and $2 mirrors' timestamps and compare them
  echo -e "\nComparing time stamps of the destination and source mirrors..."
  timestamp1=$(head -n 1 "$2/log/$LastAppMirrorUpdate")
  echo "  Timestamp of mirror at destination is: $timestamp1"
  timestamp2=$(head -n 1 "$1/log/$LastAppMirrorUpdate")
  echo "  Timestamp of mirror at source is: $timestamp2"
  if [[ "$timestamp1" = "$timestamp2" ]]; then
    # The mirror at the destination has the same time stamp as the source mirror
    return 2
  elif [[ "$timestamp1" < "$timestamp2" ]]; then
    # The mirror at the destination appears to be newer 
    return 1
  else
    # The mirror at the destination appears to be older 
    return 0
  fi
}

# A bash function that checks the user's /etc/apt/sources.list file to determine what URL protocol
# is currently being used.
# This function takes no parameters.
# The calling script should have assigned values to the following variables:
#   $UkarumpaURLPrefix
#   $InternetURLPrefix
#   $FTPURLPrefix
#   $FileURLPrefix
#   $ETCAPT$SOURCESLIST
# This function simply echoes the string protocol as one of these possibilities:
#   http://linuxrepo.sil.org.pg/mirror/
#   http://
#   ftp://
#   file:
get_sources_list_protocol ()
{
  grep -Fq "$UkarumpaURLPrefix" $ETCAPT$SOURCESLIST
  GREPRESULTINT=$?
  if [ $GREPRESULTINT -eq 0 ]; then
     echo "$UkarumpaURLPrefix" # http://linuxrepo.sil.org.pg/mirror/
  fi
  grep -Fq "$InternetURLPrefix" $ETCAPT$SOURCESLIST
  GREPRESULTINT=$?
  if [ $GREPRESULTINT -eq 0 ]; then
     echo "$InternetURLPrefix" # http://
  fi
  grep -Fq "$FTPURLPrefix" $ETCAPT$SOURCESLIST
  GREPRESULTFTP=$?
  if [ $GREPRESULTFTP -eq 0 ]; then
     echo "$FTPURLPrefix" # ftp://
  fi
  grep -Fq "$FileURLPrefix" $ETCAPT$SOURCESLIST
  GREPRESULTFILE=$?
  if [ $GREPRESULTFILE -eq 0 ]; then
     echo "$FileURLPrefix" # file:
  fi
}

# ------------------------------------------------------------------------------
# Unused functions - which might come in handy later
# ------------------------------------------------------------------------------

date2stamp ()
{
    date --utc --date "$1" +%s
}

stamp2date ()
{
    date --utc --date "1970-01-01 $1 sec" "+%Y-%m-%d %T"
}

dateDiff ()
{
    case $1 in
        -s)   sec=1;      shift;;
        -m)   sec=60;     shift;;
        -h)   sec=3600;   shift;;
        -d)   sec=86400;  shift;;
        *)    sec=86400;;
    esac
    dte1=$(date2stamp $1)
    dte2=$(date2stamp $2)
    diffSec=$((dte2-dte1))
    if ((diffSec < 0)); then abs=-1; else abs=1; fi
    echo $((diffSec/sec*abs))
}


