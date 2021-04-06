time-machine-sparse-bundle-fix
==============================

Summary:

When Time Machine backs up to a NAS, it will often get corrupted and prompt a message saying, “Time Machine completed a verification of your backups. To improve reliability, Time Machine must create a new backup for you.”

This script fixes that issue so that Time Machine can continue using the existing backup.

Instructions:

* First mount the backup drive share so that the sparcebundle is accessible.
* Make sure the script has execute permissions: `chmod +x fix_time_machine.sh`
* Run the script: `fix_time_machine.sh /Volumes/[BackupDrive]/[hostname].sparsebundle/`



Credit:

It is based off a guide written by Garth Gillespie at http://www.garth.org/archives/2011,08,27,169,fix-time-machine-sparsebundle-nas-based-backup-errors.html
It is also a modified version of http://pastebin.com/iw5nYFb0 - credit goes to anon.
