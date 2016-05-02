#!/bin/bash
# Author: Bill Martin
# Date: 4 November 2014
# Revision: 
#   - 7 November 2014 Modified for Trusty mount points having embedded $USER 
#      in $MOUNTPOINT path as: /media/$USER/LM-UPDATES whereas Precise was: 
#      /media/LM-UPDATES
# Name: postmirror2.sh
# Distribution: 
# This script is a compantion script of postmirror.sh and is included with
# all Wasta-Offline Mirrors supplied by Bill Martin.
# If you make changes to this script to improve it or correct errors, please
# send your updated script to Bill Martin bill_martin@sil.org
#
# Purpose: 
# This script may be used to clear out any "Hash Sum mismatch" errors if they
# arise when wasta-offline is being run in conjunction with a Wasta-Offline 
# Mirror, as supplied by Bill Martin. Hash Sum mismatch errors result from a 
# mismatch in hash sums between the local mirror and the hash sums located in 
# the remote mirrors. Such errors may show up when the user attempts to do a 
# "Refresh" operation within the Software Update, a "Reload" operation within 
# the Synaptic Package Manager, or 'sudo apt-get update' at a terminal 
# command line. Unfortunately it seems that a call to 'sudo apt-mirror' 
# sometimes doesn't correct such mismatches, especially for larger apt-mirror 
# generated mirrors. To correct the errors, this script simply re-copies the 
# local mirror's metadata files ('Release' 'Release.gpg' 'Packages.bz2' 
# 'Packages.gz') from their external mirror repositories and updates the 
# corresponding local metadata files of the local mirror. It also calls bzip2 
# to unpack any downloaded Packages.bz2 file creating a fresh Packages file.
#
# Cautions: This script should only be called from the postmirror.sh script that
# runs immediately after the local mirror has been updated via a running 
# apt-mirror process. The postmirror.sh script gives the user the option of
# invoking postmirror2.sh or not. The postmirror2.sh script only really needs 
# to be called if one experiences "Hash Sum mismatch" errors when calling
# sudo apt-get update or when refreshing the list of avaiable software updates
# from within Update Manager or the Synaptic Package Manager. 
# If called, this script will download around 304 metadata files amounting to a 
# total of about 75MB.
# This script only updates local metadata files that already exist on the local
# Wasta-Offline Mirror.

# Usage: (Recommended) When called automatically from a running sudo apt-mirror 
# session:
# 1. With Wasta-Offline mirrors supplied by Bill Martin, the postmirror.sh script
# and this companion postmirror2.sh script will already be included in the mirror
# tree in the folder at: /media/LM-UPDATES/wasta-offline/apt-mirror/var/. 
# Therefore, updates to the mirror (by calling sudo apt-mirror) will automatically 
# call the postmirror.sh script, which in turn calls this postmirror2.sh script as 
# necessary, depending on the user's option selected at the time postmirror.sh is
# called. No other user intervention should be necessary when this script executes 
# after the user indicates it is to be executed by selecting menu items 2) or 3) in
# response to the menu prompt at the time the apt-mirror's postmirror.sh script is
# run (at the end of the sudo apt-mirror execution).
#
# Usage: (Not Recommended) When called manually apart from an apt-mirror session:
# 1. Uncomment the appropriate local_mirrors_path variable in the script below,
# so that it uses the path to your local mirror. Uncomment the first path for 
# use with a master copy of the mirror at: "/data/wasta-offline/apt-mirror/mirror". 
# Alternately, uncomment the second path to run directly on the full Wasta-Offline 
# external USB drive mirror at: "/media/LM-UPDATES/wasta-offline/apt-mirror/mirror".
# If you are using this script for other situations, assign to local_mirrors_path
# the path that you use to keep the mirror up-to-date when you use the command: 
# sudo apt-mirror. This path should be the same as the mirror_path that is defined 
# near the top of your mirror.list configuration file found at /etc/apt/mirror.list. 
# Note that the mirror_path in mirror.list is a combination of $base_path/mirror. 
# Therefore, if $base_path is /data/wasta-offline/apt-mirror, then the 
# local_mirrors_path should be set by uncommenting the first local_mirrors_path
# assignment. If $base_path is /media/LM-UPDATES/wasta-offline/apt-mirror, then
# local_mirrors_path should be set by uncommenting the second local_mirrors_path
# assignment below.
#
# Note: It is possible to download the metadata files from the PNG FTP mirrors. 
# However, if the Wasta-Offline full mirror is being updated via the
# sudo apt-mirror command with the computer's /etc/apt/mirror.list configured to 
# get its updates from the PNG FTP mirrors (the usual anticipated case), and if the 
# PNG FTP mirrors are also internally having any problems with "Hash Sum mismatch" 
# errors, then using this script via the normal postmirror.sh action at the end of
# a apt-mirror update probably won't correct those errors - but would simply 
# duplicate any errors that the PNG FTP mirrors may be experiencing.
#
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
#  
# Note when set -e is uncommented, script stops immediately and no error codes are returned in "$?"
#set -e

POSTMIRROR2SCRIPT="postmirror2.sh"
# The SIL Ukarumpa FTP site's URL:
FTPUkarumpaURLPrefix="ftp://ftp.sil.org.pg/Software/CTS/Supported_Software/Ubuntu_Repository/mirror/"
# The above FTPUkarumpaURL may be overridden if the user invokes this script manually and uses a
# different URL in a parameter at invocation.
InternetURLPrefix="http://"
FTP="ftp"

MOUNTPOINT=`mount | grep LM-UPDATES | cut -d ' ' -f3` # normally MOUNTPOINT is /media/LM-UPDATES or /media/$USER/LM-UPDATES

# For manual invocation of this script:
# Uncomment the first local_mirrors_path assignment below for Bill's desktop mirror located at:
#    "/data/wasta-offline/apt-mirror/mirror"
# Uncomment the second local_mirrors_path assignment below for a USB hard drive mirror located at:
#    "/media/LM-UPDATES/wasta-offline/apt-mirror/mirror" or "/media/$USER/LM-UPDATES/wasta-offline/apt-mirror/mirror"
#local_mirrors_path="/data/wasta-offline/apt-mirror/mirror" 
local_mirrors_path="$MOUNTPOINT/wasta-offline/apt-mirror/mirror"
# Note: When this postmirror2.sh script is automatically invoked by the postmirror.sh script
# the local_mirrors_path will be calculated within postmirror.sh from the user's mirror.list
# configuration file and the local_mirrors_path assignment above will be overridden.

# If we get an exported value for MirrorPath we use it instead of the above local_mirror_path value
if [ -z $ExportedMirrorPath ]; then
    echo -e "\nNo MirrorPath was exported from postmirror.sh!"
    echo "The local_mirrors_path instead is: $local_mirrors_path"
else
    # Use the exported value coming from postmirror.sh
    local_mirrors_path=$ExportedMirrorPath
    echo -e "\nThe exported local_mirrors_path is: $local_mirrors_path"
fi

# This check for existence of the local_mirrors_path is still useful in case postmirror2.sh is being
# invoked manually.
# abort if the local_mirrors_path dir doesn't exist
if [ ! -d "$local_mirrors_path" ]; then
    # $local_mirrors_path doesn't exist so abort
    echo -e "\nCannot find: $local_mirrors_path so cannot update the local mirror from this computer."
    echo "Check the path in $0 and correct the path specified for local_mirrors_path if necessary."
    exit 1
fi

# Determine the URLPrefix. It defaults to using the Internet ("http://") directly, but this
# is overridden if a calling parameter is used when this script is invoked - by postmirror.sh 
# or invoked manually using a different parameter.
URLPrefix=$InternetURLPrefix  # This is the default URLPrefix ("http://") - to use the Internet directly.
if [ $# -eq 0 ]; then
  echo -e "\nNote: $POSTMIRROR2SCRIPT was invoked without any parameters:"
  echo "  '$InternetURLPrefix' will be used"
  URLPrefix=$InternetURLPrefix
else
  if [ "$1" == "$FTP" ]; then
   echo -e "\nNote: $POSTMIRROR2SCRIPT was invoked with an 'ftp' parameter:"
   echo "  '$FTPUkarumpaURLPrefix' will be used"
   URLPrefix=$FTPUkarumpaURLPrefix
  else 
    echo -e "\nNote: $POSTMIRROR2SCRIPT was invoked with the following user defined parameter:"
    echo "  '$1' will be used"
    URLPrefix=$1
  fi
fi

# Make a temp file for temporary use of a list of metadata files processed in the loops below.
temp_file_list="$(mktemp)"
touch $temp_file_list
#echo "temp_file_list is at: $temp_file_list"

# Find the local mirrors' metadata files, determine URLs to the corresponding 
# external mirrors' metadata files, and call wget to update the local metadata.
metadata_files=("Release" "Release.gpg" "Packages.bz2" "Packages.gz")
for metadata_file_name in "${metadata_files[@]}"
do
  for local_meta_file_path_name in $(find $local_mirrors_path/* -type f -name $metadata_file_name)
  do
    echo -e "- - - - - - - - - - -\n"
    # Use output of dirname to remove the metadata file from last part of the 
    # $local_meta_file_path_name and store it in a new variable $local_path_minus_metadata_file.
    local_path_minus_metadata_file=`dirname $local_meta_file_path_name`
    #echo "local_path_minus_metadata_file: $local_path_minus_metadata_file"

    # Since our local mirror should have the same structure at the external mirror,
    # we can assume that the local mirror tree structure is identical to what will
    # be found in the external mirror, and the local_meta_file_path_name instances we 
    # find in the local mirror's directory tree will have counterparts in the external
    # mirror's directory tree - the only difference being the initial parts of the
    # path (represented locally by $local_mirrors_path) will differ from the initial
    # part of the URL that points to the corresponding external metadata file.
    # For example, if the $local_mirrors_path is /data/wasta-offline/apt-mirror/mirror/
    # so that locally we find:
    # /data/wasta-offline/apt-mirror/mirror/archive.canonical.com/ubuntu/dists/trusty/Release
    # The corresponding external file will be found at the URL:
    # http://archive.canonical.com/ubuntu/dists/trusty/Release
    # 
    # Now, determine the full path of the remote_url_meta_file_path_name from our 
    # currently found local_meta_file_path_name. We can do this by removing the
    # initial part of our found string (the part that is local_mirrors_path), and
    # then prefixing http:// to the beginning of the resulting string, using a bit
    # of bash string manipulation wizardry.
    
    # Collect a temporary file list containing the paths and filenames of the local
    # metadata file - for use by the du utility below to get a total of the file sizes
    echo "$local_meta_file_path_name" >> $temp_file_list
    
    #echo "The local_meta_file_path_name is: $local_meta_file_path_name"
    #echo "The local_mirrors_path is: $local_mirrors_path"
    #echo "The string replacement is: ${local_meta_file_path_name:`expr length $local_mirrors_path`+1}"
    
    # Remove the local_mirrors_path part from the front of the local_meta_file_path_name
    # and add the appropriate URL prefix depending on the parameter used, or http:// if no
    # parameter was used in calling this script. The $URLPrefix is determined above.
    remote_url_meta_file_path_name=$URLPrefix${local_meta_file_path_name:`expr length $local_mirrors_path`+1}
    
    # Change to the directory where the metadata file is located and remove the current
    # metadata file
    cd $local_path_minus_metadata_file
    rm "$local_meta_file_path_name"

    # Finally, we retrieve the current metadata file from the external mirror
    # and write the current metadata file to its position in the local mirror.
    # One way to fetch such files is to use the curl program as follows:
    #curl -L $remote_url_meta_file_path_name -o $local_meta_file_path_name
    # Another way (which tests show is faster) is to use the wget program as follows:
    wget $remote_url_meta_file_path_name 
    # Make the downloaded metadata file read-write for everyone
    echo -e "\nMaking $local_meta_file_path_name read-write for everyone"
    chmod ugo+rw $local_meta_file_path_name
    echo "Make $local_meta_file_path_name owner be $APTMIRROR:$APTMIRROR"
    chown -R $APTMIRROR:$APTMIRROR $local_meta_file_path_name # chown -R apt-mirror:apt-mirror <path-to-file>

    # If the metadata_file_name is 'Packages.bz2' then call bzip2 to create the Packages file
    # Note: The bzip2 option -d uncompresses it to Packages and -k keeps the original file
    # and -f forces it to overwrite any existing Packages file.
    if [ "$metadata_file_name" = "Packages.bz2" ]; then
      echo "Unpacking Packages.bz2 to create Packages"
      bzip2 -d -k -f Packages.bz2
      # Remove the "Packages.bz2" name from the local_meta_file_path_name
      file_path_minus_name=${local_meta_file_path_name%/*}
      # Make the new unzipped Packages file read-write for everyone
      echo "Making $file_path_minus_name/Packages read-write for everyone"
      chmod ugo+rw $file_path_minus_name"/Packages"
      echo "Make $file_path_minus_name/Packages owner be $APTMIRROR:$APTMIRROR"
      chown -R $APTMIRROR:$APTMIRROR $file_path_minus_name"/Packages" # chown -R apt-mirror:apt-mirror <path-to-file>
    fi
  done
done

# Get the total size of the metadata files processed (normally about 75MB)
#echo "Total size of all metadata downloaded and processed = ""$(du -ch $temp_file_list | tail -1 | cut -f 1)"
echo -e "\nTotal size of all metadata downloaded = ""$( while read filename ;  do stat -c '%s' $filename ; done < $temp_file_list | awk '{total+=$1} END {print total}' ) bytes"
# Remove the temp file
rm $temp_file_list

echo "The $POSTMIRROR2SCRIPT script has finished."

