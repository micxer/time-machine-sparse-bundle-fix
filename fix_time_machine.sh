#!/bin/bash

# Disclaimer: While this works and is functional, I'm pretty terrible at shell scripting as I come from a Java/C# background. 
# Feel free to make any recommendations for this to be more consistent and shell-scripty-like.

# This is a modified version of http://pastebin.com/iw5nYFb0 - credit goes to anon.
# Based off a guide written by Garth Gillespie at http://www.garth.org/archives/2011,08,27,169,fix-time-machine-sparsebundle-nas-based-backup-errors.html

usage ()
{
  echo "usage: $0 <path_to_bundle>  or"
  echo "usage: $0 <remote_host> <user> <password> <bundle>"
  exit
}

VOLUME_DIR=""
RUN_MODE_MOUNT_SCAN=1
RUN_MODE_SCAN_ONLY=2
RUN_MODE=$RUN_MODE_SCAN_ONLY

REMOTE_HOST="$1"
REMOTE_USER="$2"
REMOTE_PASSWORD="$3"
REMOTE_BUNDLE="$4"

function create_tm_mount ()
{
  if [ -z "${REMOTE_HOST}" ] || [ -z "${REMOTE_USER}" ] || [ -z "${REMOTE_PASSWORD}" ] || [ -z "${REMOTE_BUNDLE}" ]
  then
    usage
    exit 1
  fi

  VOLUME_DIR=$(mktemp -d) && \
  mount -t afp "afp://${REMOTE_USER}:${REMOTE_PASSWORD}@${REMOTE_HOST}/Time Machine" $VOLUME_DIR
  echo "$VOLUME_DIR/$REMOTE_BUNDLE"
}

# a function to extract the dev disk from the hdiutil output
function extract_dev_disk ()
{
  HDIUTIL_OUTPUT="$1"

  # split the hdiutil output by spaces (" ") into an array.
  DISKS_ARRAY=(${HDIUTIL_OUTPUT//" "/ })
  for ((i = 0 ; i < ${#DISKS_ARRAY[@]}; i++));
  do
    # The dev disk we're looking for should have an Apple_HFS label
    if [ "${DISKS_ARRAY[$i]}" = "Apple_HFS" ]
      then
        # The actual dev disk string should be just before the Apple_HFS element in the array
        DEV_DISK=${DISKS_ARRAY[$((i-1))]}
    fi
  done

  echo "$DEV_DISK"
}

function check_connectivity ()
{
  INTERFACES="$(scutil --nwi | grep 'Network interfaces' | cut -d' ' -f3- | tr " " "|")"
  if ! networksetup -listnetworkserviceorder | grep -E "$INTERFACES" | grep Ethernet
  then
    echo "No Ethernet connection found! You don't want to run this script"
    echo "over a WiFi connection! Exiting!"
    exit 1
  fi
}

# check for correct usage
[ $# -eq 1 ] || [ $# -eq 4 ] || usage

check_connectivity

if [ $# -eq 4 ]
then
  RUN_MODE=$RUN_MODE_MOUNT_SCAN
fi

BUNDLE="$1"

if [ $RUN_MODE -eq $RUN_MODE_MOUNT_SCAN ]
then
  BUNDLE=$(create_tm_mount)
fi

if [ ! -e "$BUNDLE" ]
then
  echo "File $BUNDLE doesn't exist! Exiting."
  exit 1
fi

function cleanup_tm_mount ()
{
  umount "$VOLUME_DIR" && \
  rmdir "$VOLUME_DIR"
}

if [ $RUN_MODE -eq $RUN_MODE_MOUNT_SCAN ]
then
  trap cleanup_tm_mount EXIT
fi

echo
date
echo 'chflags...'
chflags nouchg "$BUNDLE/"
chflags nouchg "$BUNDLE/token"

echo
date
echo 'hdutil...'
DISKS_STRING=$(hdiutil attach -nomount -noverify -noautofsck "$BUNDLE/")
echo hdiutil output is "$DISKS_STRING"

echo
date
HFS_DISK=$(extract_dev_disk "$DISKS_STRING")
echo "identified HFS(X) volume as $HFS_DISK"

echo
date
echo 'fsck...'
fsck_hfs -drfy -c 2048 "$HFS_DISK" || fsck_hfs -p "$HFS_DISK" && fsck_hfs -drfy -c 2048 "$HFS_DISK"
# this was to wait for the log to finish before we ran fsck explicitly, as above
# grep -q 'was repaired successfully|could not be repaired' <(tail -f -n 0 /var/log/fsck_hfs.log)

echo
date
echo 'hdiutil detach...'
hdiutil detach "$HFS_DISK"

# make a backup of the original plist
echo
date
echo 'backing up original plist...'
cp "$BUNDLE/com.apple.TimeMachine.MachineID.plist" "$BUNDLE/com.apple.TimeMachine.MachineID.plist.bak"

echo
date
echo 'fixing plist...'
# change VerificationState to zero
plutil -replace VerificationState -integer 0 "$BUNDLE/com.apple.TimeMachine.MachineID.plist"
# remove RecoveryBackupDeclinedDate and write to a temp file
plutil -remove RecoveryBackupDeclinedDate "$BUNDLE/com.apple.TimeMachine.MachineID.plist"

echo
date
echo 'done!'
echo 'eject the disk from your desktop if necessary, then rerun Time Machine'

# this command will tell you who's using the disk, if ejecting is a problem:
echo "If the disk can't be ejected, run:"
echo "sudo lsof -xf +d $HFS_DISK"

if [ $RUN_MODE -eq $RUN_MODE_MOUNT_SCAN ]
then
  cleanup_tm_mount
fi

if [ -n "${MAIL_SERVER}" ] && [ -n "${MAIL_FROM}" ] && [ -n "${MAIL_TO}" ] && [ -n "${MAIL_USERPASS}" ] 
then
  curl --silent  --ssl-reqd \
    --url "smtp://$MAIL_SERVER" \
    --mail-from "$MAIL_FROM" \
    --mail-rcpt "$MAIL_TO" \
    --user "$MAIL_USERPASS" \
    --upload-file <(echo -e "From: $MAIL_FROM\nTo: $MAIL_TO\nSubject: time-machine-sparsebundle-fix finished\nDate: $(gdate --rfc-email)\n\nFixing the sparsebundle $BUNDLE was successful!")
fi
