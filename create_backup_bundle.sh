#!/bin/bash

# Thanks to https://gist.github.com/bitboxer/961550
#
# A bash script to create a time machine disk image
# This script probably only works for me, so try it at your own peril!
# Use, distribute, and modify as you see fit but leave this header intact.
# (R) sunkid - September 5, 2009
# 
# This will create a time machine ready disk image named with your 
# computer's name with a maximum size of 600GB and copy it to 
# /Volumes/backup. The image "file" (it's a directory, really) will 
# contain the property list file that TM needs.
# 
# sh  ./makeImage.sh 600 /Volumes/backup
# cp -pfr <computer name>.sparsebundle /Volumes/backup/<computer name>.sparsebundle

usage ()
{
     printf "%s\n" "$errmsg"
     echo "Create a sparsebundle to use with TimeMachine"
     echo
     echo "usage: $0 <size> <encrypt> [directory]"
     echo
     echo "  size: GB"
     echo "  encrypt: true / false"
     echo "  directory: Where to copy your backup volume (optional)"
}

# test if we have at least two arguments on the command line
if [ $# -lt 2 ]
then
    usage
    exit 0
fi

SIZE=$1
DIR=$3

# do we want to have encryption?
ENCRYPT=0
if [ "$2" = "true" ]
then
    ENCRYPT=1
fi

# if a directory was passed, check if it's writable
if [ -n "${DIR}" ]
then
  if [ ! -d "${DIR}" ]
  then
    errmsg="${DIR}: No such directory"
    usage
    exit 1
  fi
  if [ ! -w "${DIR}" ]
  then
    errmsg="Cannot write to ${DIR}"
    usage
    exit 1
  fi
fi

COMPUTER_NAME=$(scutil --get ComputerName);
UUID=$(ioreg -d2 -c IOPlatformExpertDevice | awk -F\" '/IOPlatformUUID/{print $(NF-1)}')

# well then, let's go
PASSWORD=""
ENCRYPT_OPTIONS=()
if [ $ENCRYPT -eq 1 ]
then
    echo -n "Enter password for ${COMPUTER_NAME}.sparsebundle: "
    read -r -s PASSWORD
    echo
    echo -n "Re-enter password for ${COMPUTER_NAME}.sparsebundle: "
    read -r -s PASSWORD_VERIFY
    echo
    if [ "$PASSWORD" != "$PASSWORD_VERIFY" ]
    then
        echo "Passwords don't match. Exiting."
        exit 0
    fi
    ENCRYPT_OPTIONS=(-encryption AES-256 -stdinpass)
fi

echo -n "Generating disk image ${COMPUTER_NAME}.sparsebundle with size ${SIZE}GB ... "
printf "%s" "$PASSWORD"| \
    hdiutil create \
    -size "${SIZE}G" \
    -fs HFS+J \
    -type SPARSEBUNDLE \
    -imagekey sparse-band-size=262144 \
    "${ENCRYPT_OPTIONS[@]}" \
    -volname 'Time Machine Backups' \
    "${COMPUTER_NAME}.sparsebundle" >/dev/null

echo "done!"

echo -n "Generating property list file with uuid $UUID ... "

/usr/libexec/PlistBuddy -c "Add :com.apple.backupd.HostUUID string $UUID" "${COMPUTER_NAME}.sparsebundle/com.apple.TimeMachine.MachineID.plist" > /dev/null

echo "done!"

if [ -n "${DIR}" ]
then
  echo -n "Copying ${COMPUTER_NAME}.sparsebundle to ${DIR} ... "
  cp -pfr "${COMPUTER_NAME}.sparsebundle" "${DIR}/${COMPUTER_NAME}.sparsebundle"
  echo "done"
fi

echo "Finished! Happy backups!"
echo
echo "If you copied the sparsebundle to a non-AFP target you might want to run"
echo "  defaults write com.apple.systempreferences  TMShowUnsupportedNetworkVolumes 1"
echo
