#!/bin/bash
# Author: Bill Martin <bill_martin@sil.org>
# Date: 7 November 2014
# Name: bash_functions.sh
# Distribution: 
# This script is included with all Wasta-Offline Mirrors supplied by Bill Martin.
# If you make changes to this script to improve it or correct errors, please send
# your updated script to Bill Martin bill_martin@sil.org
#
# Purpose: This is a source repository script the contains the various bash functions
# that are used by the other Wasta-Offline scripts, including the following scripts:
# 1. update-mirror.sh
# 2. sync_Wasta-Offline_to_Ext_Drive.sh
#
# Usage: This bash_functions.sh script should be in the same directory as the calling
# bash scripts, or referenced with a "source <relative-path>/bash_functions.sh" call is used
# to include any functions in a script that is located

# ------------------------------------------------------------------------------
# Bash script functions
# ------------------------------------------------------------------------------

# A bash function that checks whether a dir exists/is available. Returns 0 if the
# directory exists/is available. Returns 1 if dir doesn't exist or is not available.
# First parameter is manditory and should be the absolute path to a directory.
is_dir_available ()
{
  # This function should not produce any echo output other than its return value
  if [ -d $1 ]; then
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
      echo "The $1 program is currently running!"
    fi
    # In bash logic success/true is 0
    return 0 # $NUMBEROFPROCESSES # will be > 0
  else
    if [ "x$2" = "x" ]; then
      # 'x' is used in the string comparison because bash is broken and in some versions could 
      # fail the equality test with empty strings.
      echo "The $1 program is not running!"
    fi
    # In bash logic failure/false is >= 1
    return 1 # $NUMBEROFPROCESSES # will be 0
  fi
}

# A bash function that checks whether a USB drive is mounted that has "LM-UPDATES" as a label. 
# Returns a zero value if a USB "LM-UPDATES" drive was found mounted on the system (could be an
# empty LM-UPDATES labeled drive); returns non-zero (1) if a USB device having a "LM-UPDATES" 
# label was not found, or (if a parameter is passed in) could not be formatted and labeled as 
# such.
# By uncommenting an if test (see below) a single parameter can be passed to this function 
# (it must be "PREP_NEW_USB"), to make the function check to see if any USB drives are 
# attached that have the capacity to be used to make a clone of the Wasta-Offline full mirror, 
# and gives the user a list of them to possibly choose from. If the user chooses one, and the 
# USB drive has a non-Linux file system a warning is issued that the drive will be formatted 
# and any existing data on it destroyed. 
# If the user gives permission to continue, the drive is formatted to a Linux Ext4 file system, 
# and thus made ready for use to receive a rsync copy of a Wasta-Offline full mirror. When this 
# function has completed a return value of 0 means that an external USB drive is either mounted 
# and has an existing LM-UPDATES mirror on it, or it is empty and ready to receive such a mirror 
# copied to it. 
get_valid_LM_UPDATES_mount_point ()
{
  # Get the mount point for any plugged in external USB drive containing LM-UPDATES label that is 
  # part of the $COPYTODIR or $COPYFROMDIR paths
  export MOUNTPOINT=`mount | grep LM-UPDATES | cut -d ' ' -f3` # normally MOUNTPOINT is /media/LM-UPDATES
  #echo "MOUNTPOINT is: $MOUNTPOINT"

  # Handle situation in which the external LM-UPDATES gets mounted at .../LM-UPDATES_ with one
  # or more trailing underscore(s) rather than at /media/LM-UPDATES, or /media/$USER/LM-UPDATES as 
  # required for this script to run properly.
  if [[ $MOUNTPOINT == */LM-UPDATES_* ]]; then
    CORRECTMOUNTPOINT=${MOUNTPOINT%"/LM-UPDATES*"}
    CORRECTMOUNTPOINT=$CORRECTMOUNTPOINT"/LM-UPDATES"
    echo -e "\n******** WARNING *********** WARINING ********* WARNING ********"
    echo "The external USB drive is mounting at: $MOUNTPOINT"
    echo "(note the trailing underscore) instead of $CORRECTMOUNTPOINT."
    echo "Make sure that you do NOT have two USB LM-UPDATES drives mounted at"
    echo "the same time (both having the LM-UPDATES label). If two such drives"
    echo "are mounted at the same time, safely remove both USB drives, and then"
    echo "plug in only one of the LM-UPDATES drives, and try running this script"
    echo "again. If this warning message keeps appearing you will need to do the"
    echo "following steps to fix this problem:"
    echo "  1. Safely remove all UBS drives from the computer"
    echo "  2. Open a new terminal from the Accessories menu or by typing: Ctrl+Alt+T"
    echo "  3. In the terminal type this command: sudo rmdir $CORRECTMOUNTPOINT*"
    echo "  4. Type your password when prompted (blindly, as nothing will be shown)"
    echo "  5. Plug in the LM-UPDATES USB drive, and Cancel at the wasta-offline prompt."
    echo "  6. Try running this script again..."
    echo "Note: This script must Exit before you can safely remove this USB drive, and"
    echo "Correct the problem as described above."
    echo "Write down the command in step 3 (this terminal session will disappear)"
    echo "- then press ENTER to Exit this script."
    return 1
  fi

  # Handle situation if LM-UPDATES is not found as mount point. This might happen if a new
  # USB hard drive is being used that hasn't had its label changed to LM-UPDATES.
  if [ -z "$MOUNTPOINT" ] && [ "x$MOUNTPOINT" = "x" ]; then
    # The $MOUNTPOINT variable exists but is empty, i.e., the LM-UPDATES mount point was not found
    echo -e "\nThe LM-UPDATES USB drive was NOT found"

    # By uncommenting the if test below, the remainder of this block would only be 
    # available for callers who might want the USB hard drive formatting option to
    # be available to the script. When uncommented a caller would call this function 
    # with a single parameter consisting of "PREP_NEW_USB".
    #if [ "$1" = "PREP_NEW_USB" ]; then
      # S "PREP_NEW_USB" parameter was passed by the caller so make the following checks
      echo -e "\nSeaching for USB storage drive(s) on this computer..."
      USBINFOARRAY=() # Create an empty array for device info strings generated below
      USBMOUNTPTARRAY=() # Create an empty array for mount points
      USBDEVICEARRAY=() # Create an empty array for devices
      USBSIZEARRAY=() # Create an empty array for sizes (in GB)
      for udi in $(/usr/bin/hal-find-by-capability --capability storage)
      do
        device=$(hal-get-property --udi $udi --key block.device)
        USBDEVICEARRAY+=("$device")
        vendor=$(hal-get-property --udi $udi --key storage.vendor)
        model=$(hal-get-property --udi $udi --key storage.model)
        if [[ $(hal-get-property --udi $udi --key storage.bus) = "usb" ]]; then
            parent_udi=$(hal-find-by-property --key block.storage_device --string $udi)
            mount=$(hal-get-property --udi $parent_udi --key volume.mount_point)
            MOUNTPTARRAY+=("$mount")
            label=$(hal-get-property --udi $parent_udi --key volume.label)
            media_size=$(hal-get-property --udi $udi --key storage.removable.media_size)
            size=$(( media_size/(1000*1000*1000) ))
            USBSIZEARRAY+=("$size")
            USBINFOARRAY+=("$vendor:$model:$device:$mount:$label:${size}GB")
        fi
      done
      index=0
      total=0
      for item in "${USBINFOARRAY[@]}"; do
        let index=index+1
        printf " $index) $item \n"
        # Determine if $item has the "LM-UPDATES" string. If so, the drive is plugged in but not mounted
        if [ "${item/"LM-UPDATES"}" != "$item" ]; then
          echo -e "\nUSB device $index) above has 'LM-UPDATES' but is not mounted!"
          dev=$(echo $item | cut -d ':' -f3)
          echo "Attempting to mount 'LM-UPDATES' USB drive on device $dev""1"
          mkdir -p $LMUPDATESDIR # Create the /media/LM-UPDATES directory in case it doesn't exist
          mount $dev"1" $LMUPDATESDIR
          LASTERRORLEVEL=$?
          if [ $LASTERRORLEVEL != 0 ]; then
             echo -e "\nCould not mount the USB device at $LMUPDATESDIR."
             echo "Remove the USB drive and plug it back in again to see if it will"
             echo "automatically mount at $LMUPDATESDIR, then run this script again."
             return $LASTERRORLEVEL
          fi
          # If we get here we succeeded in mounting the USB drive, and we can return early
          echo "LM-UPDATES Mount Point is: $LMUPDATESDIR"
          return 0 # Success
        fi
        let total=total+1
      done
      # Note: arrays such as USBINFOARRAY() are zero based
      if [ $index -eq 0 ]; then
          echo -e "\nCould not find a USB drive on this system!"
          echo "Please connect an LM-UPDATES USB drive to receive software updates, or"
          echo "Alternately, connect an empty USB drive that meets these qualifications:"
          echo "  Is large enough to contain the full wasta-offline mirror (at least 400GB)"
          echo "  Can be formatted with a Linux Ext4 file system (destroying any existing data)"
          echo "  Can be renamed with this label: LM-UPDATES"
          echo "Then, run this script again. Aborting..."
          return 1
      else
        for (( i=$WAIT; i>0; i--)); do
          printf "\rType the number of the USB drive to use, or hit any key to abort - countdown $i "
          read -s -n 1 -t 1 SELECTION
          if [ $? -eq 0 ]; then
              break
          fi
        done

        if [[ ! $SELECTION ]] || [[ $SELECTION > $total ]] || [[ $SELECTION < 1 ]]; then
          echo -e "\n"
          echo "You typed $SELECTION"
          echo "Unrecognized selection made, or no reponse within $WAIT seconds."
          echo "Please connect an LM-UPDATES USB drive to receive software updates, or"
          echo "Alternately, connect an empty USB drive that meets these qualifications:"
          echo "  Is large enough to contain the full wasta-offline mirror (at least 400GB)"
          echo "  Can be formatted with a Linux Ext4 file system (destroying any existing data)"
          echo "  Can be renamed with this label: LM-UPDATES"
          echo "Then, run this script again. Aborting..."
          return 1
        fi
        # If we get this far, the user has typed a valid selection
        echo -e "\n"
        echo "Your choice was $SELECTION"
        # Check if USB drive has at least 400GB of space
        if [ ${USBSIZEARRAY[SELECTION-1]} -lt 400 ]; then
          echo "The selected USB drive has a capacity of ${USBSIZEARRAY[SELECTION-1]}GB"
          echo "The selected USB drive is too small - it has less than 400GB of disk space."
          echo "You need a USB hard drive that has at least 400GB of storage capacity."
          echo "Aborting..."
          return 1
        fi
        # Warn the user that this USB drive will be formatted and all data wiped out
        echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
        # Arrays are zero-based so current index is SELECTION-1
        echo "You have selected this USB device mounted at ${USBDEVICEARRAY[SELECTION-1]}:"
        echo "  ${USBINFOARRAY[SELECTION-1]}"
        echo -e "\nWARNING: This USB drive will be formatted - ALL data on it erased. OK (y/n)? "
        response='n'
        for (( i=$WAIT; i>0; i--)); do
          printf "\rType 'y' to proceed with formatting, any other key to abort - countdown $i "
          read -s -n 1 -t 1 response
          if [ $? -eq 0 ]; then
              break
          fi
        done
        printf "\rType 'y' to proceed with formatting, any other key to abort - countdown $i "
        case $response in
          [yY][eE][sS]|[yY]) 
            # Unmount the device - it must be unmounted before it can be formatted and labeled
            # Suffix a 1 to the device to unmount partition 1, eg, if device is sdd unmount sdd1.
            echo "Unmounting the USB drive..."
            umount ${USBDEVICEARRAY[SELECTION-1]}1
            LASTERRORLEVEL=$?
            if [ $LASTERRORLEVEL != 0 ]; then
               echo -e "\nCould not unmount the USB device."
               echo "If a program or terminal session is keeping it busy, close them and try again."
               return $LASTERRORLEVEL
            fi
            # Format the drive with Ext4 file system and assign the LM-UPDATES label by calling mkfs.ext4
            echo -e "\n\nFormatting the USB drive with a Linux Ext4 file system..."
            mkfs.ext4 -L "LM-UPDATES" ${USBDEVICEARRAY[SELECTION-1]}1
            LASTERRORLEVEL=$?
            if [ $LASTERRORLEVEL != 0 ]; then
               echo -e "\nCould not format the USB drive (Error #$LASTERRORLEVEL)."
               echo "You might try using the Disk Utility or Parted to format the drive with"
               echo "an Ext4 file system, then try running this script again."
               return $LASTERRORLEVEL
            fi
            # Mount the drive again - this time at /media/LM-UPDATES
            mkdir -p $LMUPDATESDIR # Create the /media/LM-UPDATES directory in case it doesn't exist
            mount ${USBDEVICEARRAY[SELECTION-1]}1 $LMUPDATESDIR
            LASTERRORLEVEL=$?
            if [ $LASTERRORLEVEL != 0 ]; then
               echo -e "\nCould not mount the USB device at $LMUPDATESDIR."
               echo "Remove the USB drive and plug it back in again to see if it will"
               echo "automatically mount at $LMUPDATESDIR, then run this script again."
               return $LASTERRORLEVEL
            fi
            export DRIVEWASFORMATTED="TRUE"
            ;;
          *)
            echo -e "\nProcess aborted by user!"
            return 1
            ;;
        esac
      fi
    #else  # uncomment this else block if want to include USB disk formatting option
    #  # LM-UPDATES not found and No "PREP_NEW_USB" parameter received, so abort
    #  return 1
    #fi
  else
    echo -e "\nThe LM-UPDATES USB drive was found"
  fi
  echo "LM-UPDATES Mount Point is: $MOUNTPOINT"
  return 0 # Success
}

# A bash function that checks the user's /etc/apt/sources.list file to determine what URL protocol
# is currently being used.
# This function takes no parameters.
# This function simply echoes the string protocol as one of these possibilities:
#   http://
#   ftp://
#   file:
get_sources_list_protocol ()
{
  grep -Fq "$InternetURLPrefix" $ETCAPT$SOURCESLIST
  GREPRESULTINT=$?
  if [ $GREPRESULTINT -eq 0 ]; then
     echo "$InternetURLPrefix"
  fi
  grep -Fq "$FTPURLPrefix" $ETCAPT$SOURCESLIST
  GREPRESULTFTP=$?
  if [ $GREPRESULTFTP -eq 0 ]; then
     echo "$FTPURLPrefix"
  fi
  grep -Fq "$FileURLPrefix" $ETCAPT$SOURCESLIST
  GREPRESULTFILE=$?
  if [ $GREPRESULTFILE -eq 0 ]; then
     echo "$FileURLPrefix"
  fi
}

# A bash function that first checks whether a program $1 is installed by calling the bash 
# function is_program_installed. If the program is already installed this function does nothing 
# but returns 0.
# $1  the program to be installed
# $2  -q (quiet - don't prompt to install, go ahead and install the program)
# If the program is not installed, it installs the program using either wasta-offline (if 
# wasta-offline is running and is the full mirror), local FTP server, or the Internet (after 
# prompting if OK to access the Internet).
# The function takes a single parameter which should be the name of the program as it would
# be invoked at a command line. For example: smart_install_program "apt-mirror".
# If wasta-offline is running and using the full mirror (LM-UPDATES), it installs program from 
# the full wasta-offline mirror, otherwise, if Internet is available, it prompts the user if
# the program should be downloaded and installed from the Internet instead.
# Note: The $1 used within this funtion is the parameter invoked with this install_program, bash
# function, not the $1 representing the first command-line parameter from invocation of the 
# calling script.
smart_install_program ()
{
  # Check if $1 is already installed. If not, offer to install the $1 program.
  echo -e "\n"
  echo -n "Checking if $1 is installed..."
  if (is_program_installed $1); then
    echo "YES"
    # Program already installed, so do nothing more just return 0
    return 0
  else 
    echo "NO"
    # The $1 program is not installed
    # We can help guide the user through the installation if we know what the current URL protocol
    # is being used in their /etc/apt/sources.list file. The URL protocol should be one of three
    # possibilities:
    # 1. http:// This protocol would indicate that the user would currently need to access the 
    #    Internet to install the $1 program.
    # 2. file:   This protocol would indicate that the user is currently running the wasta-offline
    #    program, and if LM-UPDATES drive is mounted, the program can be installed offline from
    #    the full mirror on the external hard drive.
    # 3. ftp://  This protocol would indicate that the user would currently need to access a ftp 
    #    LAN server such as the FTP server at Ukarumpa to install the $1 program.

    # call our get_sources_list_protocol () function to determine the current sources.list protocol
    PROTOCOL=`get_sources_list_protocol`
    case $PROTOCOL in
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
              echo -e "\nInstalling $1..."
              apt-get install $1
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
        echo -e "\nInstalling $1..."
        apt-get install $1
        LASTERRORLEVEL=$?
        if [ $LASTERRORLEVEL != 0 ]; then
           #echo "Could not install the $1 program. Aborting..."
           return $LASTERRORLEVEL
        fi
      ;;
      $FileURLPrefix)
        # The sources.list indicates wasta-offline is active and software can potentially be 
        # installed using a full wasta-offline LM-UPDATES. User should be warned if wasta-offline
        # is not actually running, or a full mirror at /media/.../LM-UPDATES can't be found.
        if (is_program_running $WASTAOFFLINE); then
          # wasta-offline is running
          # If wasta-offline is running against the full mirror it should be mounted at /media/.../LM-UPDATES
          if (is_dir_available $LMUPDATESDIR); then
            echo "The $WASTAOFFLINE program is running with the full mirror on: $LMUPDATESDIR."
          else
            echo "The $WASTAOFFLINE program is running but full mirror in NOT on: $LMUPDATESDIR"
            # An error message will appear in the apt-get install $1 call below
          fi
          echo -e "\nInstalling $1..."
          apt-get install $1
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

# This function uses rsync to copy the root directory and apt-mirror-setup directory
# files from a source mirror's base directory to a destination mirror's base directory.
# This function takes two parameters: $1 a source mirror's base path, and $2 a destination 
# mirror's base path.
# The calling script needs to export the following variables:
#   $OFFLINEDIR
#   $APTMIRRORDIR
#   $APTMIRRORSETUPDIR
copy_mirror_root_files ()
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

  # $PKGPATH is assigned the path to the wasta-offline directory containing the deb packages 
  # deep in the ppa.launchpad.net part of the source mirror's "pool" repo:
  # Note: Since COPYFROMDIR generally has a final /, append $APPMIRROR to it rather than $APPMIRRORDIR
  PKGPATH=$1$OFFLINEDIR$APTMIRRORDIR"/mirror/ppa.launchpad.net/wasta-linux/wasta-apps/ubuntu/pool/main/w/wasta-offline/"

  echo "The 1 parameter is: $1"
  echo "The 2 parameter is: $2"

  # Find the latest 32bit and 64bit deb packages, getting their absolute paths prefixed
  # Due to a strange quirk I'm experiencing with the find command, it fails to find the deb files 
  # if the current directory is /data, so as a work-around, I'll temporarily change the directory
  # to / (root), execute the find command, and then change the current directory back to what it
  # was previously (!).
  OLDDIR=`pwd` # Save the working dir path
  cd / # temporarily change the working dir path to root
  DEB32BITPKG=`find "$1$OFFLINEDIR$APTMIRRORDIR" -type f -name wasta-offline_*_i386.deb -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d" "`
  DEB64BITPKG=`find "$1$OFFLINEDIR$APTMIRRORDIR" -type f -name wasta-offline_*_amd64.deb -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d" "`
  # Handle any find failure that leaves the DEB*PKG variables empty and, if no failures,
  # copy the deb packages to the root dir of both the source and destination locations.
  if [[ "x$DEB32BITPKG" == "x" ]]; then
    echo -e "\nCould not find 32bit wasta-offline deb package in source mirror"
  else
    echo -e "\nRemoving any old $1/wasta-offline_*_i386.deb package(s)"
    rm $1/wasta-offline_*_i386.deb
    echo "Copying 32bit package from source mirror tree to: $1"
    # For these "root" level files we use --update option instead of the --delete option
    # which updates the destination only if the source file is newer
    rsync -avz --progress --update $DEB32BITPKG $1
    if [ -f $2/wasta-offline_*_i386.deb ]; then
      echo "Removing any existing $2/wasta-offline_*_i386.deb file"
      rm $2/wasta-offline_*_i386.deb
    fi
    echo "Copying 32bit package from source mirror tree to: $2"
    # For these "root" level files we use --update option instead of the --delete option
    # which updates the destination only if the source file is newer
    rsync -avz --progress --update $DEB32BITPKG $2
  fi
  if [[ "x$DEB64BITPKG" == "x" ]]; then
    echo -e "\nCould not find 64bit wasta-offline deb package in source mirror"
  else
    echo -e "\nRemoving any old $1/wasta-offline_*_amd64.deb package(s)"
    rm $1/wasta-offline_*_amd64.deb
    echo "Copying 64bit package from source mirror tree to: $1"
    # For these "root" level files we use --update option instead of the --delete option
    # which updates the destination only if the source file is newer
    rsync -avz --progress --update $DEB64BITPKG $1
    if [ -f $2/wasta-offline_*_amd64.deb ]; then
      echo "Removing any existing $2/wasta-offline_*_amd64.deb file"
      rm $2/wasta-offline_*_amd64.deb
    fi
    echo "Copying 64bit package from source mirror tree to: $2"
    # For these "root" level files we use --update option instead of the --delete option
    # which updates the destination only if the source file is newer
    rsync -avz --progress --update $DEB64BITPKG $2
  fi
  cd $OLDDIR # Restore the working dir to what it was

  # Copy the *.sh file in the $1$APTMIRRORSETUPDIR to their ultimate 
  # destination of $1$OFFLINEDIR$APTMIRRORDIR$VARDIR
  echo -e "\ncopying the *.sh files from: $1$APTMIRRORSETUPDIR/*.sh"
  echo "                                to $1$OFFLINEDIR$APTMIRRORDIR$VARDIR"
  rsync -avz --progress --update $1$APTMIRRORSETUPDIR/*.sh $1$OFFLINEDIR$APTMIRRORDIR$VARDIR

  # Copy other needed files to the external drive's root dir
  # Find all Script files at base path $1 (-maxdepth 2 includes the $1 folder 
  # and the apt-mirror-setup folder but will exclude Bill's /data/wasta-offline2/... 
  # tree) and rsync them to $2
  echo -e "\n"
  for script in `find $1 -maxdepth 2 -name '*.sh'` ; do 
    # The $script var will have the absolute path to the file in the source tree
    # We need to adjust the path to copy it to the same relative location in the 
    # destination tree. 
    # We remove the $1 part of the $script path and substitute the $2 part.
    # Handle any find failure that leaves the $script variables empty, and if no failures,
    # rsync the script to the destination mirror at same relative location. Create the
    # directory structure at the destination if necessary.
    destscript=$2${script#$1}
    echo "Found script in source tree at: $script"
    echo "The destination script should be at: $destscript"
    DIROFSCRIPT=${destscript%/*}
    echo "Making directory at: $DIROFSCRIPT"
    mkdir -p "$DIROFSCRIPT"
    echo -e "\nSynchronizing the script file $script to $destscript"
    # For these "root" level files we use --update option instead of the --delete option
    # which updates the destination only if the source file is newer
    rsync -avz --progress --update $script $destscript
  done

  # Find all the other Script files at $1$OFFLINEDIR$APTMIRRORDIR (includes only 
  # the $1/var/ folder) and rsync them to $2
  for script in `find $1$OFFLINEDIR$APTMIRRORDIR -name '*.sh'` ; do 
    # The $script var will have the absolute path to the file in the source tree
    # We need to adjust the path to copy it to the same relative location in the 
    # destination tree. 
    # We remove the $1 part of the $script path and substitute the $2 part.
    # Handle any find failure that leaves tje $script variables empty, and if no failures,
    # rsync the script to the destination mirror at same relative location.
    destscript=$2${script#$1}
    echo "Found script in source tree at: $script"
    echo "The destination script should be at: $destscript"
    DIROFSCRIPT=${destscript%/*}
    echo "Making directory at: $DIROFSCRIPT"
    mkdir -p "$DIROFSCRIPT"
    echo -e "\nSynchronizing the script file $script to $destscript"
    # For these "root" level files we use --update option instead of the --delete option
    # which updates the destination only if the source file is newer
    rsync -avz --progress --update $script $destscript
  done
  echo "Synchronizing the ReadMe file to $2..."
  # For these "root" level files we use --update option instead of the --delete option
  # which updates the destination only if the source file is newer
  rsync -avz --progress --update $1/ReadMe $2
  return 0
}

# A bash function that calls chown to set the ownership of the passed in mirror to apt-mirror:apt-mirror
# and sets the permissions to read-write-execute for *.sh scripts and read-write for the mirror tree and
# other files at the root of the mirror tree.
# This function must have one parameter $1 passed to it, which is the base directory where the chown and
# chmod operations are to initiate.
# The calling script needs to export the following variables:
#   $OFFLINEDIR
#   $APTMIRROR
#   $APTMIRRORDIR
set_mirror_ownership_and_permissions ()
{
  # Although the destination may be a tree with no content created by the mkdir -p $COPYTODIR call 
  # we can go ahead and take care of any mirror ownership and permissions issues for those
  # directories and files that exist, in case something has changed them. We don't want ownership
  # or permissions issues on any existing content there to foul up the sync operation.
  if [ $1 ]; then
    # Set ownership of the mirror tree starting at the apt-mirror directory
    echo -e "\nSetting $1$OFFLINEDIR$APTMIRRORDIR owner: $APTMIRROR:$APTMIRROR"
    chown -R $APTMIRROR:$APTMIRROR $1$OFFLINEDIR$APTMIRRORDIR
    echo "Setting content at $1 read-write for everyone"
    chmod -R ugo+rw $1
    # Find all Script files at $1 and set them read-write-executable
    for script in `find $1 -name '*.sh'` ; do 
      echo "Setting $script executable"
      chmod ugo+rwx $script
    done
  fi
  return 0
}

generate_mirror_list_file ()
{
  # A bash function that generates a custom mirror.list file with the proper settings and
  # URL protocol prefixes needed for the location of the user's mirror.
  # If this function succeeds it returns 0. If it fails it returns 1.
  # This function makes a backup of any existing mirror.list file to mirror.list.save if the 
  # following line is NOT already present at the top of the existing mirror.list file:
  # ###_This_file_was_generated_by_the_update-mirror.sh_script_###
  # The main program ensures that apt-mirror has already been installed, but there is no problem
  # if this routine were to create a custom mirror.list before apt-mirror gets installed.
  # NOTE: The inventory of software repositories that get downloaded by apt-mirror is
  # controlled by the "here-document" part of this function below, between the cat <<EOF ...
  # and EOF lines. Existing repositories can be removed by commenting out the appropriate
  # deb-amd64 and deb-i386 lines or adding additional repositories. The LM-UPDATES mirror
  # supplied by Bill Martin will always have both deb-amd64 and deb-i386 packages for the
  # "full" mirror.
  # Variables that get expanded while generating the mirror.list file:
  #   $GENERATEDSIGNATURE is "###_This_file_was_generated_by_the_update-mirror.sh_script_###"
  #   $1 is the URL Prefix passed in as the parameter of the function call (http://, ftp://..., etc).
  #   $LOCALMIRRORSPATH is base path to the mirror (usually /media/LM-UPDATES/wasta-offline/apt-mirror,
  #      or /media/$USER/LM-UPDATES/wasta-offline/apt-mirror, but can also be 
  #      /data/wasta-offline/apt-mirror for the master copy of the full mirror)
  #   $ARCHIVESECURITY is either "archive" (for Ukarumpa FTP mirror), or "security" (for the
  #      remote Internet mirror).
  # 

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

  echo "LOCALMIRRORSPATH is $LOCALMIRRORSPATH"
  # Handle the irregularity in the Ukarumpa FTP repository that has precise-security
  # and trusty-security located in the archive.ubuntu.com rather than security.ubuntu.com
  # as is the default for Linux Mint and Wasta-Linux.
  # Note: According to Cambell Prince the packages.palaso.org repo no longer exists, so 
  # that all future palaso software will be released via the packages.sil.org repository.
  if [ $1 = $FTPUkarumpaURLPrefix ]; then
    ARCHIVESECURITY="archive"
  else
    ARCHIVESECURITY="security"
  fi
  echo -e "\nGenerating $MIRRORLIST at $MIRRORLISTPATH"

  # The code below generates a custom /etc/apt/mirror.list configuration file on the fly for the user. 
  # Any changes deemed necessary to the content of mirror.list that gets generated by this script, 
  # should be made within the "here-document" content below, rather than directly to the user's 
  # /etc/apt/mirror.list file.
  #
  # The following uses "here-document" redirection which tells the shell to read from the current
  # source until the line containing EOF is seen. As long as the command is cat <<EOF and not quoted
  # as cat <<"EOF", parameter expansion happens for $LOCALMIRRORSPATH, $1, and $ARCHIVESECURITY.
  # The /etc/apt/mirror.list file is created from scratch each time this script is run.
  # Within functions, $1 is the first parameter that is provided with the function call. In this
  # case, $1 is either $FTPUkarumpaURLPrefix, $InternetURLPrefix, or $CustomURLPrefix depending on 
  # the user's selection in the main program (see below).
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

# whm modified 24Mar14 to add Linux Mint repro, remove src repos, include both 32-bit and 64-bit packages
# Note: the following are referenced in /etc/apt/sources.list
deb-amd64 $1packages.linuxmint.com/ maya main upstream import backport
deb-i386 $1packages.linuxmint.com/ maya main upstream import backport
deb-amd64 $1archive.ubuntu.com/ubuntu precise main restricted universe multiverse
deb-i386 $1archive.ubuntu.com/ubuntu precise main restricted universe multiverse
# Note: Our external mirror points to the security.ubuntu.com/ubuntu precise-security repository.
# The Ukarumpa FTP mirrors point to archive.ubuntu.com/ubuntu precise-security. Presumably, both 
# remote mirrors contain the same packages and updates.
deb-amd64 $1$ARCHIVESECURITY.ubuntu.com/ubuntu precise-security main restricted universe multiverse
deb-i386 $1$ARCHIVESECURITY.ubuntu.com/ubuntu precise-security main restricted universe multiverse
deb-amd64 $1archive.ubuntu.com/ubuntu precise-updates main restricted universe multiverse
deb-i386 $1archive.ubuntu.com/ubuntu precise-updates main restricted universe multiverse
deb-amd64 $1extras.ubuntu.com/ubuntu precise main
deb-i386 $1extras.ubuntu.com/ubuntu precise main
# Note: The following two archive.canonical.com partner repos may not be in the Ukarumpa FTP mirror
# If so, one may comment out the following two entries
deb-amd64 $1archive.canonical.com/ubuntu precise partner
deb-i386 $1archive.canonical.com/ubuntu precise partner
deb-amd64 $1packages.sil.org/ubuntu precise main
deb-i386 $1packages.sil.org/ubuntu precise main
#deb-amd64 $1download.virtualbox.org/virtualbox/debian precise contrib
#deb-i386 $1download.virtualbox.org/virtualbox/debian precise contrib
# Note: the following are referenced in separate .list files in /etc/apt/sources.list.d/
# Note: the wasta-linux repos need the source code packages also included
deb-amd64 $1ppa.launchpad.net/wasta-linux/wasta-apps/ubuntu precise main
deb-i386 $1ppa.launchpad.net/wasta-linux/wasta-apps/ubuntu precise main
deb-src $1ppa.launchpad.net/wasta-linux/wasta-apps/ubuntu precise main
deb-amd64 $1ppa.launchpad.net/wasta-linux/wasta/ubuntu precise main
deb-i386 $1ppa.launchpad.net/wasta-linux/wasta/ubuntu precise main
deb-src $1ppa.launchpad.net/wasta-linux/wasta/ubuntu precise main
deb-amd64 $1ppa.launchpad.net/libreoffice/libreoffice-4-1/ubuntu precise main
deb-i386 $1ppa.launchpad.net/libreoffice/libreoffice-4-1/ubuntu precise main
deb-amd64 $1ppa.launchpad.net/libreoffice/libreoffice-4-2/ubuntu precise main
deb-i386 $1ppa.launchpad.net/libreoffice/libreoffice-4-2/ubuntu precise main
deb-amd64 $1ppa.launchpad.net/libreoffice/libreoffice-4-3/ubuntu precise main
deb-i386 $1ppa.launchpad.net/libreoffice/libreoffice-4-3/ubuntu precise main

# whm added 21Sep2014 trusty repos below:
# Note: the following are referenced in /etc/apt/sources.list
deb-amd64 $1packages.linuxmint.com/ qiana main upstream import backport
deb-i386 $1packages.linuxmint.com/ qiana main upstream import backport
deb-amd64 $1archive.ubuntu.com/ubuntu trusty main restricted universe multiverse
deb-i386 $1archive.ubuntu.com/ubuntu trusty main restricted universe multiverse
# Note: Our external mirror points to the security.ubuntu.com/ubuntu trusty-security repository.
# The Ukarumpa FTP mirrors point to archive.ubuntu.com/ubuntu trusty-security. Presumably, both 
# remote mirrors contain the same packages and updates
deb-amd64 $1$ARCHIVESECURITY.ubuntu.com/ubuntu trusty-security main restricted universe multiverse
deb-i386 $1$ARCHIVESECURITY.ubuntu.com/ubuntu trusty-security main restricted universe multiverse
deb-amd64 $1archive.ubuntu.com/ubuntu trusty-updates main restricted universe multiverse
deb-i386 $1archive.ubuntu.com/ubuntu trusty-updates main restricted universe multiverse
deb-amd64 $1extras.ubuntu.com/ubuntu trusty main
deb-i386 $1extras.ubuntu.com/ubuntu trusty main
deb-amd64 $1archive.canonical.com/ubuntu trusty partner
deb-i386 $1archive.canonical.com/ubuntu trusty partner
deb-amd64 $1packages.sil.org/ubuntu trusty main
deb-i386 $1packages.sil.org/ubuntu trusty main
#deb-amd64 $1download.virtualbox.org/virtualbox/debian trusty contrib
#deb-i386 $1download.virtualbox.org/virtualbox/debian trusty contrib
# Note: the following are referenced in separate .list files in /etc/apt/sources.list.d/
# Note: the wasta-linux repos need the source code packages also included
deb-amd64 $1ppa.launchpad.net/wasta-linux/wasta-apps/ubuntu trusty main
deb-i386 $1ppa.launchpad.net/wasta-linux/wasta-apps/ubuntu trusty main
deb-src $1ppa.launchpad.net/wasta-linux/wasta-apps/ubuntu trusty main
deb-amd64 $1ppa.launchpad.net/wasta-linux/wasta/ubuntu trusty main
deb-i386 $1ppa.launchpad.net/wasta-linux/wasta/ubuntu trusty main
deb-src $1ppa.launchpad.net/wasta-linux/wasta/ubuntu trusty main
deb-amd64 $1ppa.launchpad.net/libreoffice/libreoffice-4-1/ubuntu trusty main
deb-i386 $1ppa.launchpad.net/libreoffice/libreoffice-4-1/ubuntu trusty main
deb-amd64 $1ppa.launchpad.net/libreoffice/libreoffice-4-2/ubuntu trusty main
deb-i386 $1ppa.launchpad.net/libreoffice/libreoffice-4-2/ubuntu trusty main
deb-amd64 $1ppa.launchpad.net/libreoffice/libreoffice-4-3/ubuntu trusty main
deb-i386 $1ppa.launchpad.net/libreoffice/libreoffice-4-3/ubuntu trusty main

# Note: the following are for wasta 14.04.2 / Linux Mint 17.1 Rebecca
deb-amd64 $1packages.linuxmint.com/ rebecca main upstream import #id:linuxmint_main
deb-i386 $1packages.linuxmint.com/ rebecca main upstream import #id:linuxmint_main
deb-amd64 $1extra.linuxmint.com/ rebecca main #id:linuxmint_extra
deb-i386 $1extra.linuxmint.com/ rebecca main #id:linuxmint_extra

# Note: the following are for wasta 14.04.3 / Linux Mint 17.2 Rafaela
deb-amd64 $1packages.linuxmint.com/ rafaela main upstream import #id:linuxmint_main
deb-i386 $1packages.linuxmint.com/ rafaela main upstream import #id:linuxmint_main
deb-amd64 $1extra.linuxmint.com/ rafaela main #id:linuxmint_extra
deb-i386 $1extra.linuxmint.com/ rafaela main #id:linuxmint_extra

clean $1packages.linuxmint.com/
clean $1extra.linuxmint.com/
clean $1archive.ubuntu.com/ubuntu
clean $1$ARCHIVESECURITY.ubuntu.com/ubuntu
clean $1extras.ubuntu.com/ubuntu
clean $1archive.canonical.com/ubuntu
clean $1packages.sil.org/ubuntu
#clean $1download.virtualbox.org/virtualbox/debian
clean $1ppa.launchpad.net/wasta-linux/wasta-apps/ubuntu
clean $1ppa.launchpad.net/wasta-linux/wasta/ubuntu
clean $1ppa.launchpad.net/libreoffice/libreoffice-4-1/ubuntu
clean $1ppa.launchpad.net/libreoffice/libreoffice-4-2/ubuntu
clean $1ppa.launchpad.net/libreoffice/libreoffice-4-3/ubuntu

EOF
  LASTERRORLEVEL=$?
  return $LASTERRORLEVEL
}

# A bash function that determines if a full wasta-offline mirror exists at the given
# path.
# Returns 0 if a full wasta-offline mirror exists at $1, otherwise returns 1.
# An single optional parameter must be used which should be the absolute path to the
# wasta-offline directory of an apt-mirror generated mirror tree. For example,
# /data/wasta-offline or /media/LM-UPDATES/wasta-offline or /media/$USER/LM-UPDATES/wasta-offline.
# A "full" wasta-offline mirror should have the following mirrors:
# List of Mirrors and Repos:
# As of October 2014 these are the mirrors and the repositories that we use in the
# full Wasta-Linux Mirror as supplied by Bill Martin:
#   Mirror                                        Repos
#   --------------------------------------------------------------------------------
#   archive.canonical.com                         partner
#   archive.ubuntu.com                            main multiverse restricted universe
#   extras.ubuntu.com                             main
#   packages.linuxmint.com                        backport import main upstream
#   packages.sil.org                              main
#   ppa.launchpad.net/libreoffice/libreoffice-4-1 main
#   ppa.launchpad.net/libreoffice/libreoffice-4-2 main
#   ppa.launchpad.net/wasta-linux/wasta           main
#   ppa.launchpad.net/wasta-linux/wasta-apps      main
#   security.ubuntu.com                           main multiverse restricted universe
# 
# For each of the above Repos we include both binary-i386 and binary-amd64 architecture packages. 
is_there_a_wasta_offline_mirror_at ()
{
  # The following are used exclusively in the is_there_a_wasta_offline_mirror_at () function:
  WASTAOFFLINEDIR="/data" # initial assignment, varies between /data and /media/LM-UPDATES or /media/$USER/LM-UPDATES
  UBUNTUMIRRORS=("archive.ubuntu.com" "extras.ubuntu.com" "packages.sil.org" "ppa.launchpad.net/libreoffice/libreoffice-4-1" "ppa.launchpad.net/libreoffice/libreoffice-4-2" "ppa.launchpad.net/wasta-linux/wasta" "ppa.launchpad.net/wasta-linux/wasta-apps")
  UBUNTUDISTS=("precise" "trusty")
  LINUXMINTDISTS=("maya" "qiana")
  UBUNTUSECUREDISTS=("precise-security" "trusty-security")
  UBUNTUREPOS=("main" "multiverse" "restricted" "universe")
  LINUXMINTREPOS=("backport" "import" "main" "upstream")
  ARCHS=("binary-amd64" "binary-i386")
  full_mirror_exists="TRUE" # assume the mirrors exist unless one or more are missing

  # Check to see if there is a valid wasta-offline path at the $1 parameter location. If not,
  # return 1 (for failure)
  if [ ! -d $1 ]; then
    return 1
  fi

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
  # Path: $WASTAOFFLINEDIR/apt-mirror/mirror/$mirror/ubuntu/dists/$dist/main/$arch
  # Number of tests to be made: 28
  for mirror in "${UBUNTUMIRRORS[@]}"
  do
    for dist in "${UBUNTUDISTS[@]}"
    do
      for arch in "${ARCHS[@]}"
      do
        if [ -d "$WASTAOFFLINEDIR/apt-mirror/mirror/$mirror/ubuntu/dists/$dist/main/$arch" ]; then
          full_mirror_exists="FALSE"
          break
        else
          echo -n "." #"Found: $WASTAOFFLINEDIR/apt-mirror/mirror/$mirror/ubuntu/dists/$dist/main/$arch"
        fi
      done
    done
  done

  # Group 2 use two embedded for loops: outer loop for dist in $UBUNTUDISTS; inner loop for arch in $ARCHS
  # Path: $WASTAOFFLINEDIR/apt-mirror/mirror/archive.canonical.com/ubuntu/dists/$dist/partner/$arch
  # Number of tests to be made: 4
  for dist in "${UBUNTUDISTS[@]}"
  do
    for arch in "${ARCHS[@]}"
    do
      if [ -d "$WASTAOFFLINEDIR/apt-mirror/mirror/archive.canonical.com/ubuntu/dists/$dist/partner/$arch" ]; then
        full_mirror_exists="FALSE"
        break
      else
        echo -n "." #"Found: $WASTAOFFLINEDIR/apt-mirror/mirror/archive.canonical.com/ubuntu/dists/$dist/partner/$arch"
      fi
    done
  done

  # Group 3 use two embedded for loops: outer loop for dist in $LINUXMINTDISTS; inner loop for arch in $ARCHS
  # Path: $WASTAOFFLINEDIR/apt-mirror/mirror/packages.linuxmint.com/dists/$dist/main/$arch
  # Number of tests to be made: 4
  for dist in "${LINUXMINTDISTS[@]}"
  do
    for arch in "${ARCHS[@]}"
    do
      if [ -d "$WASTAOFFLINEDIR/apt-mirror/mirror/packages.linuxmint.com/dists/$dist/main/$arch" ]; then
        full_mirror_exists="FALSE"
        break
      else
        echo -n "." #"Found: $WASTAOFFLINEDIR/apt-mirror/mirror/packages.linuxmint.com/dists/$dist/main/$arch"
      fi
    done
  done

  # Group 4 use two embedded for loops: outer loop for dist in $UBUNTUSECUREDISTS; inner loop for arch in $ARCHS
  # Path: $WASTAOFFLINEDIR/apt-mirror/mirror/security.ubuntu.com/ubuntu/dists/$dist/main/$arch
  # Number of tests to be made: 4
  for dist in "${UBUNTUSECUREDISTS[@]}"
  do
    for arch in "${ARCHS[@]}"
    do
      if [ -d "$WASTAOFFLINEDIR/apt-mirror/mirror/security.ubuntu.com/ubuntu/dists/$dist/main/$arch" ]; then
        full_mirror_exists="FALSE"
        break
      else
        echo -n "." #"Found: $WASTAOFFLINEDIR/apt-mirror/mirror/security.ubuntu.com/ubuntu/dists/$dist/main/$arch"
      fi
    done
  done

  if [ "$full_mirror_exists" = "TRUE" ]; then
    return 0
  else
    return 1
  fi
}

# A bash function that determines if one wasta-offline mirror is older, same or newer than 
# another one.
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
  if [[ $1 = "" ]] || [[ $2 = "" ]]; then
    # Programming Error
    return 6
  fi

  # Check that both parameters point to valid wasta-offline directories.
  # Check to see if there is a valid wasta-offline path at the $1 parameter location. If not,
  # return 1 (for failure)
  if [ ! -d $1 ]; then
    return 3
  fi
  # Check to see if there is a valid wasta-offline path at the $2 parameter location. If not,
  # return 1 (for failure)
  if [ ! -d $2 ]; then
    return 4
  fi

  # Check that the parateters given to this function point to different mirrors.
  if [ $1 = $2 ]; then
    # Programming Error
    return 5
  fi

  # Check to see if the destination mirror ($1) has a $LastAppMirrorUpdate file. If not we assume
  # that the destination tree is older
  if ! [ -f $1"/log/$LastAppMirrorUpdate" ]; then
    # No $LastAppMirrorUpdate file found at destination
    return 7
  fi

  # Check the Unix timestamps of the $1 mirror and $2 mirror. If the $1 mirror timestamp is the
  # same or newer (same or smaller number of seconds), then return 1 (False in Bash-logic). 
  # If the $1 timestamp is older (larger number of seconds) then return 0 (True in Bash-logic).

  # Get the $1 and $2 mirrors' timestamps and compare them
  echo -e "\nComparing time stamps of the destination and source mirrors..."
  timestamp1=$(head -n 1 $2"/log/$LastAppMirrorUpdate")
  echo "  Timestamp of mirror at destination is: $timestamp1"
  timestamp2=$(head -n 1 $1"/log/$LastAppMirrorUpdate")
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

# ------------------------------------------------------------------------------
# Unused functions - which might come in handy later
# ------------------------------------------------------------------------------

# A bash function that checks the user's /etc/apt/sources.list file to determine what URL protocol
# is currently being used.
# This function takes no parameters.
# This function simply echoes the string protocol as one of these possibilities:
#   http://
#   ftp://
#   file:
get_sources_list_protocol ()
{
  grep -Fq "$InternetURLPrefix" $ETCAPT$SOURCESLIST
  GREPRESULTINT=$?
  if [ $GREPRESULTINT -eq 0 ]; then
     echo "$InternetURLPrefix"
  fi
  grep -Fq "$FTPURLPrefix" $ETCAPT$SOURCESLIST
  GREPRESULTFTP=$?
  if [ $GREPRESULTFTP -eq 0 ]; then
     echo "$FTPURLPrefix"
  fi
  grep -Fq "$FileURLPrefix" $ETCAPT$SOURCESLIST
  GREPRESULTFILE=$?
  if [ $GREPRESULTFILE -eq 0 ]; then
     echo "$FileURLPrefix"
  fi
}

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


