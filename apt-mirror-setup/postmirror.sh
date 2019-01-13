#!/bin/bash
# Author: Bill Martin
# Date: 4 November 2014
# Revisions: 
#   - 7 November 2014 Modified for Trusty mount points having embedded $USER 
#      in $MOUNTPOINT path as: /media/$USER/<DISK_LABEL>
#   - 15 December 2018 Changed the Ukarumpa linuxrepo URL from ftp to 
#      http://linuxrepo.sil.org.pg/mirror
#      Revised to make the script more generic and not hard wire "LM-UPDATES"
#      as the expected USB disk label.
#   - 28 December 2018 revised to simplify echo outputs.
# Name: postmirror.sh
# Distribution:
# This script is designed to be a replacement for the empty default postmirror.sh 
# script that comes with a new installation of apt-mirror.
# postmirror.sh has a compantion script postmirror2.sh which is included with
# all Wasta-Offline Mirrors supplied by Bill Martin.
# If you make changes to this script to improve it or correct errors, please
# send your updated script to Bill Martin bill_martin@sil.org

# Purpose: 
# Normally, you should not need to call this script directly. Instead, you
# should use the update-mirror.sh script (in the USB drive's root directory)
# to update the full software mirror as supplied by Bill Martin. Calling the 
# update-mirror.sh script fully automates the update process. It will ensure
# that the apt-mirror program is installed, and automatically invoke it from
# your choice of the most appropriate download sources. When apt-mirror
# finishes its downloads, it will in turn invoke this postmirror.sh script.
# The information below is for those who might want to invoke the postmirror.sh
# script manually, apart from calling update-mirror.sh.
#
# This script is designed to be used as a replacement postmirror.sh script 
# that (when made executable) is called automatically at the end of a
# sudo apt-mirror run. By default the postmirror.sh file that is provided by 
# apt-mirror exists when apt-mirror is installed, but is empty and is not 
# installed with executable permissions. 
# This postmirror.sh script has a companion script called postmirror2.sh. 
# This postmirror.sh script does the following:
#   1. Automatically runs at the end of the mirror update command: sudo apt-mirror 
#   2. Reads the user's mirror.list at: /etc/apt/mirror.list
#   3. Checks the mirror.list's base_path setting to locate the mirror
#   4. Calls the clean.sh script to remove obsolete items from the mirror
#   5. Makes all files in the mirror read-write for everyone
#   6. Queries the user to see if the postmirror2.sh script should be run to 
#      clean up any "Hash Sum mismatch" errors that have been detected in the 
#      mirror created by apt-mirror. It queries the user with the following 
#      question and prompts for the user's choice from the following options:
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  - - - -
# Run the postmirror2.sh script to correct Hash Sum mismatches errors?
#  1) No, don't run the script. There are no Hash Sum mismatches"
#  2) Yes, run the script and get (120MB) of metadata from the Internet, or"
#  3) Yes, run the script and get (120MB) of metadata from the Ukarumpa site"
# Please press the 1, 2, or 3 key, or hit any key to abort - countdown 60  
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  - - - -
# If no response is given within 60 seconds, 1) No, don't run the script... is 
#    automatically selected and the script will end without attempting to correct
#    any Hash Sum mismatches.
# If 1 is entered, the script finishes with, "The postmirror2.sh will not be 
#    called. Script completed."
# If 2 is entered, postmirror2.sh is called without any parameter (Internet use 
#    assumed)
# If 3 is entered, postmirror2.sh is called with a "ukarumpa" parameter
#    "ukarumpa" will be interpreted to be "http://linuxrepo.sil.org.pg/mirror"
#    within the postmirror2.sh script, unless postmirror2.sh is called manually and a 
#    different parameter is used for the URL.

# Preparation (not needed if this script is called from update-mirror.sh): 
# 1. This script should be copied to the base_path/var location, replacing apt-mirror's 
#    default empty postmirror.sh file located there. The base_path location is defined
#    within the computer's /etc/apt/mirror.list file.
# 2. The companion script named postmirror2.sh should also be copied to the base_path/var
#    location to reside along side this postmirror.sh file.
# 3. Both postmirror.sh and postmirror2.sh should be set with executable permissions:
#    chmod u+x postmirror.sh postmirror2.sh

# Usage: 
#   Automatic: Runs automatically at the end the apt-mirror updaing command: sudo apt-mirror
#   Manual: Can be run manually with the following invocation, and optional parameters: 
#      sudo <path>/postmirror.sh [ukarumpa | <path-prefix>]
#      where <path> is the base_path/var directory (as specified in mirror.list)
#      ukarumpa option: Using ukarumpa as a parameter will direct all downloads from the Ukarumpa mirror
#         at http://linuxrepo.sil.org.pg/mirror
#      <path-prefix> option: an ftp:// or http:// URL address may be given
#   Note: When this script is invoked manually, is should be as soon as possible after the mirror
#         was updated with a prior call to: sudo apt-mirror. Otherwise the hash sums could get
#         out of date.
#  
# Note when set -e is uncommented, script stops immediately and no error codes are returned in "$?"
#set -e

# When this script is called automatically from apt-mirror it runs as the user: "apt-mirror".
# However, if a user calls this script manually and is not root, we inform the user that it 
# needs to be called as root.
#echo -n "The whoami during run of postmirror.sh is: "
#whoami
if [ "$(whoami)" != "root" ] && [ "$(whoami)" != "apt-mirror" ]; then
  echo -e "\nThis script needs to run with superuser permissions."
  echo "Normally you should not call this script directly."
  echo "Instead you should run the update-mirror.sh script which will make an"
  echo "appropriate call to apt-mirror for your setup, and apt-mirror itself "
  echo "will call this postmirror.sh script with superuser permissions."
  echo "Aborting..."
  exit 1
fi

# The abs paths for the following two scripts are determined below after reading the mirror.list file
PostMirrorScript="postmirror.sh"
PostMirrorScript2="postmirror2.sh"
CURRDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

APTMIRROR="apt-mirror"
PathToMirrorListFile="/etc/apt/mirror.list"
FILE=$PathToMirrorListFile
SetBasePath="set base_path"
WAIT=60
BasePath=""

# Go through mirror.list and extract the path on the uncommented set base_path line
#echo -e "\nReading the mirror.list file at: $PathToMirrorListFile"
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
#echo "The paths derived from the /etc/apt/mirror.list file are:"
#echo " The base_path is: $BasePath"

# If we couldn't find a base_path value notify user and abort
# since no other paths from mirror.list will be valid
if [ -z $BasePath ]; then
  echo -e "\nThe base_path setting in mirror.list is empty!"
  echo "Please ensure the base_path line in mirror.list file is set to a valid path"
  echo "and try again..."
  echo "Aborting $PostMirrorScript processing!"
  exit 1
fi

# Get some absolute paths
PathToCleanScript=$BasePath"/var/clean.sh"
PathToPostMirrorScript=$BasePath"/var/"$PostMirrorScript
PathToPostMirrorScript2=$BasePath"/var/"$PostMirrorScript2
LastAppMirrorUpdate="last-apt-mirror-update"

# Use output of dirname to remove the apt-mirror dir from last part of the 
# $BasePath, append "/log" and store the result in $PathToLogDir.
PathToLogDir=$(dirname $BasePath)"/log"

# Export the ExportedMirrorPath to make it available to the postmirror2.sh script
export ExportedMirrorPath=$BasePath"/mirror"

#echo " mirror_path: $ExportedMirrorPath"
#echo " cleanscript path: $PathToCleanScript"
#echo " postmirror.sh path:"
#echo "   $PathToPostMirrorScript"
#echo " postmirror2.sh path:"
#echo "   $PathToPostMirrorScript2"

# Update the /data/wasta-offline/log/$LastAppMirrorUpdate file to contain a time-stamp of 
# the current time in UTC Unix format (seconds since 1970-01-01 00:00:00 UTC)
UnixDateStamp=$(date --utc +%s)
mkdir -p $PathToLogDir
echo $UnixDateStamp > $PathToLogDir/$LastAppMirrorUpdate
echo -e "\nThe Timestamp (Unix format) of this apt-mirror update is: $UnixDateStamp"
echo "Saving time-stamp to:"
echo "  $PathToLogDir/$LastAppMirrorUpdate"

# Always call the clean.sh script from postmirror.sh
echo -e "\nCalling the clean.sh script..."
sh $PathToCleanScript

# After postmirror.sh (and postmirror2.sh) finish, the update-mirror.sh calling
# script takes care of making all mirror files read-write for everyone, 
# and making the owner be apt-mirror:apt-mirror, so we need not do those here.
# Make all mirror files read-write for everyone
#echo "Making all mirror files read-write for everyone"
#chmod -R ugo+rw $ExportedMirrorPath  # $BasePath"/mirror"
# Make apt-mirror owner of all content in the mirror tree
#echo "Make $BasePath dir owner be $APTMIRROR:$APTMIRROR"
#chown -R $APTMIRROR:$APTMIRROR $BasePath # chown -R apt-mirror:apt-mirror /data/wasta-offline/apt-mirror

# check whether the companion script exists. If not, abort with error message.
if [ ! -f $PathToPostMirrorScript2 ]; then
  echo -e "\nSorry, the $PostMirrorScript2 was not found. It should be at:"
  echo "  $PathToPostMirrorScript2 directory"
  echo "  along with $PostMirrorScript."
  echo "Aborting $PostMirrorScript processing! Please try again..."
  exit 1
fi
# check whether the companion script is executable. If not, offer to make it executable.
if [ ! -x $PathToPostMirrorScript2 ]; then
  response='y'
  echo -e "\n"
  read -r -p "Sorry, the $PostMirrorScript is not executable. Make it executable? [y/n] " response
  case $response in
    [yY][eE][sS]|[yY]) 
        chmod ugo+x $PathToPostMirrorScript2
        ;;
    *)
        echo "Use chmod u+x $PathToPostMirrorScript2, then try again"
        exit 1
        ;;
  esac
fi

# Only prompt to run postmirror2.sh if the whoami is NOT apt-mirror, i.e., when the whoami
# is root as is the case when run manually by a user. This way the prompt below is bypassed 
# during the cron job running of postmirror.sh. The countdown prompt is pointless during a 
# cron job run, since no terminal is displayed and therefore no user-interaction is possible 
# (apparently the terminal output is redirected to the apt-mirror's cron.log at: 
# /var/spool/apt-mirror/var/cron.log). 
# Bypassing the countdown prompt also avoids the 60 lines produced during the countdown that
# would otherwise appear in the cron.log while it waits 60 seconds for a response that would
# never happen during the countdown.
if [ "$(whoami)" != "apt-mirror" ]; then
  echo "**************************************************************************"
  echo "Run the $PostMirrorScript2 script to correct Hash Sum mismatches errors?"
  echo "  1) No, don't run the script. There are no Hash Sum mismatches (default)"
  echo "  2) Yes, run the script and get (75MB) of metadata from the Internet, or"
  echo "  3) Yes, run the script and get (75MB) of metadata from the Ukarumpa site"
  echo "**************************************************************************"
  for (( i=$WAIT; i>0; i--)); do
    printf "\rPlease press the 1, 2, or 3 key, or hit any key to abort - countdown $i "
    #read -p "\rPlease press the 1, 2, or 3 key (countdown $i) " -n 1 -t 1 key
    read -s -n 1 -t 1 SELECTION
    if [ $? -eq 0 ]
    then
        break
    fi
  done
  #read -r -p "Please respond with 1, 2, or 3 and then press Enter " -t $WAIT SELECTION

  if [ ! $SELECTION ]; then
    echo -e "\n"
    echo "No selection made, or no response within $WAIT seconds. Assuming response of 1"
    echo "The $PostMirrorScript2 script was not called. Script completed."
    exit 0
  fi

  echo -e "\n"
  echo "Your choice was $SELECTION"
else
  echo "This postmirror.sh script is running from the apt-mirror user"
  SELECTION="1"
fi

case $SELECTION in
  "1")
    echo "The $PostMirrorScript2 will not be called."
    echo "The $PostMirrorScript script has finished."
    exit 0
  ;;
  "2")
    # Check to see if the Internet is accessible using the www.archive.ubuntu.com site
    # wget --spider www.archive.ubuntu.com
    ping -c1 -q www.archive.ubuntu.com
    if [ "$?" != 0 ]; then
      echo -e "\nInternet access to www.archive.ubuntu.com not available!"
      echo "This script cannot run without access to the Internet!"
      echo "Aborting..."
      exit 1
    else
      echo -e "\nInternet access to www.archive.ubuntu.com appears to be available!"
      echo "Calling $PostMirrorScript2 - getting data from Internet (http://)..."
      bash $PathToPostMirrorScript2
    fi
  ;;
  "3")
    # Check to see if the Ukarumpa linuxrepo site is accessible
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
      echo -e "\nCalling $PostMirrorScript2 - getting data from local Ukarumpa site..."
      bash $PathToPostMirrorScript2 "ukarumpa"
      # "ukarumpa" will be interpreted to be "http://linuxrepo.sil.org.pg/mirror"
      # within the postmirror2.sh script.
    fi
   ;;
  *)
    echo "Unrecognized response. Aborting..."
    exit 1
  ;;
esac

echo -e "\nThe $PostMirrorScript script has finished."

