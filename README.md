# time-machine-sparse-bundle-fix

## Summary

When Time Machine backs up to a NAS, it will often get corrupted and prompt
a message saying, “Time Machine completed a verification of your backups. To
improve reliability, Time Machine must create a new backup for you.”

This script fixes that issue so that Time Machine can continue using the
existing backup.

## Usage

Make sure the script has execute permissions:
`chmod +x fix_time_machine.sh`. Then proceed with one of the alternatives
that fit your use case.

### Alternative 1

This you can use if you only have one machine using the NAS as backup target.

1. Mount the backup drive share so that the sparsebundle is accessible.
2. Run the script:
   `./fix_time_machine.sh /Volumes/<BackupDrive>/<hostname>.sparsebundle/`

### Alternative 2

If you have several machines with different logins on the NAS using it as
backup target, you have to mount the backup using the right user bafore the
script can do its job.

`$ ./fix_time_machine.sh  <user> <password> <[hostname].sparsebundle>`

### Create new backup sparsebundle

In case you want or have to start with a new sparsebundle yo can use the
other script which provides a more optimized sparsebundle layout.

`./create_backup_bundle.sh size <encrypt> [directory]`

- _size_ in GB
- _encrypt_ `true` / `false`
- _directory_ where to copy it after creation (optional)

## Credit

It is based off a guide written by Garth Gillespie at
http://www.garth.org/archives/2011,08,27,169,fix-time-machine-sparsebundle-nas-based-backup-errors.html
It is also a modified version of http://pastebin.com/iw5nYFb0 - credit goes
to anon.
