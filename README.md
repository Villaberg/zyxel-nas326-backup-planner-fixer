# zyxel-nas326-backup-planner-fixer
# Zyxel NAS326 Backup Planner – Automatic Target Path Fixer

Automatically organizes Zyxel NAS326 Backup Planner destinations by adding
the Backup Planner job name as a subdirectory of the destination directory.

## Overview

The Zyxel NAS326 Backup Planner can create backup jobs where the configured
destination directory is used directly as the target.

For example, a Backup Planner job might contain:

    Jobname:    Video_Backup
    TargetPath: Backup/

This project automatically changes the target path to:

    Backup/Video_Backup/

The important part is that **the destination directory is not hard-coded**.

The script reads the `TargetPath` configured by Backup Planner and appends
the job's `Jobname` to that path.

For example:

    Jobname:    Video_Backup
    TargetPath: Backup/

becomes:

    Backup/Video_Backup/

If the destination selected in Backup Planner is:

    My_Backups/

the result becomes:

    My_Backups/Video_Backup/

Likewise:

    TargetPath: Backup/2026/
    Jobname:    Video_Backup

becomes:

    Backup/2026/Video_Backup/


## Why this is useful

When several Backup Planner jobs use the same destination directory,
having each job stored in its own subdirectory makes the backup structure
much easier to understand and manage.

For example:

    Backup/
    ├── Julia_Home_Backup/
    ├── Foton/
    ├── Video_Backup/
    ├── Musik/
    ├── Elin_homefolder/
    ├── Wares/
    └── Homeassistant/

Each directory corresponds directly to a Backup Planner job.


# How it works

The solution consists of a small POSIX-compatible shell script and a
cron entry.

The script reads the Zyxel Backup Planner SQLite database:

    /etc/zyxel/backupjob.db

The relevant table is:

    BackupJobEntry

The script reads:

    Jobname
    TargetPath

For every job it checks whether the last directory component of
`TargetPath` is already equal to `Jobname`.

If it is, nothing is changed.

If it is not, the script creates:

    <TargetPath>/<Jobname>/

and updates the database.


## Example

Before:

    Jobname:    Video_Backup
    TargetPath: Backup/

After:

    Jobname:    Video_Backup
    TargetPath: Backup/Video_Backup/


Another example:

    Jobname:    Family_Photos
    TargetPath: NAS_Backups/

After:

    Jobname:    Family_Photos
    TargetPath: NAS_Backups/Family_Photos/


Another example:

    Jobname:    Video_Backup
    TargetPath: Backup/2026/

After:

    Jobname:    Video_Backup
    TargetPath: Backup/2026/Video_Backup/


# Important design principle

The script does **not** contain:

    Backup/

as a fixed destination.

Instead it uses whatever `TargetPath` is currently stored in
Backup Planner.

This makes the script independent of the name of the destination
directory selected by the user.


# Idempotent operation

The script is designed to be run repeatedly.

For example:

    Backup/Video_Backup/

with:

    Jobname = Video_Backup

will be detected as already corrected.

The script will therefore leave it unchanged.

Running the script once or 1,000 times produces the same final result.

This is important because the script is normally executed once every
minute using cron.


# Files

The project contains:

    fix_backup_targets.sh

The main automatic correction script.

Optionally, the project can also contain:

    update_backup_paths.sh

This can be used as a manual migration tool for existing jobs.

The automatic script is the important part of the project.


# Installation

## Requirements

This project is intended for a Zyxel NAS326 running firmware that provides:

- SSH access
- root access
- BusyBox
- `crond`
- `sqlite3`
- Zyxel Backup Planner
- `/etc/zyxel/backupjob.db`

The implementation was developed and tested on a Zyxel NAS326 using:

    BusyBox v1.19.4


# 1. Copy the script

Copy:

    fix_backup_targets.sh

to:

    /root/fix_backup_targets.sh


# 2. Make the script executable

Run:

    chmod +x /root/fix_backup_targets.sh

Check:

    ls -l /root/fix_backup_targets.sh

The result should show executable permissions, for example:

    -rwxr-xr-x


# 3. Check the Backup Planner database

The database should exist at:

    /etc/zyxel/backupjob.db

Check:

    ls -l /etc/zyxel/backupjob.db


Check the database tables:

    sqlite3 /etc/zyxel/backupjob.db ".tables"

The Backup Planner database should contain:

    BackupJobEntry
    BackupJobScheduler


Check existing jobs:

    sqlite3 /etc/zyxel/backupjob.db \
    "SELECT Jobname, TargetPath FROM BackupJobEntry;"


# 4. Test the script manually

Before configuring cron, run:

    /root/fix_backup_targets.sh


Then check:

    sqlite3 /etc/zyxel/backupjob.db \
    "SELECT Jobname, TargetPath FROM BackupJobEntry;"


Existing correctly configured jobs should remain unchanged.


# 5. Configure cron

The Zyxel NAS326 uses BusyBox `crond`.

The root crontab is located at:

    /var/spool/cron/crontabs/root


Add:

    * * * * * /root/fix_backup_targets.sh > /dev/null 2>&1


This means:

    Run fix_backup_targets.sh every minute.


The script therefore detects new Backup Planner jobs automatically.


# Verify cron

Check the crontab:

    cat /var/spool/cron/crontabs/root


The following line should be present:

    * * * * * /root/fix_backup_targets.sh > /dev/null 2>&1


Check that `crond` is running:

    ps | grep crond


# Automatic operation

Once installed, no further manual action is required.

Suppose a new Backup Planner job is created:

    Jobname:    New_Backup
    TargetPath: Backup/

The next cron execution will detect the job and change it to:

    Backup/New_Backup/


If another destination was selected:

    Jobname:    New_Backup
    TargetPath: MyBackups/

the result will instead be:

    MyBackups/New_Backup/


The script always uses the destination configured in Backup Planner.


# Logging

Changes are logged to:

    /i-data/.system/fix_backup_targets.log


View the log with:

    cat /i-data/.system/fix_backup_targets.log


Example:

    Sun Aug 23 21:01:03 CEST 2026 Changed: New_Backup -> Backup/New_Backup/


Only actual changes are logged.

A job that is already correctly configured does not generate a new
log entry every minute.


# Script

The current version of `fix_backup_targets.sh` is:

```sh
#!/bin/sh

###############################################################################
# Zyxel NAS326 - Backup Planner Target Path Fixer
#
# Purpose:
#   Automatically append the Backup Planner Jobname to the destination
#   directory defined by TargetPath.
#
# Example:
#   Jobname:    Video_Backup
#   TargetPath: Backup/
#
#   becomes:
#   TargetPath: Backup/Video_Backup/
#
# The script is intended to run periodically from cron.
###############################################################################

DB="/etc/zyxel/backupjob.db"
LOG="/i-data/.system/fix_backup_targets.log"


###############################################################################
# Check that the database exists
###############################################################################

if [ ! -f "$DB" ]; then
    exit 1
fi


###############################################################################
# Read all Backup Planner jobs
#
# Output format:
#   Jobname|TargetPath
###############################################################################

sqlite3 "$DB" -separator '|' \
"SELECT Jobname, TargetPath
 FROM BackupJobEntry;" |
while IFS='|' read JOB TARGET
do

    # Skip incomplete records
    [ -z "$JOB" ] && continue
    [ -z "$TARGET" ] && continue


    ###########################################################################
    # Remove trailing slash(es) from TargetPath
    #
    # Backup/
    # Backup////
    #
    # become:
    #
    # Backup
    ###########################################################################

    BASE="$TARGET"

    while [ "${BASE%/}" != "$BASE" ]
    do
        BASE="${BASE%/}"
    done


    # Do not process an empty path
    [ -z "$BASE" ] && continue


    ###########################################################################
    # Get the last directory component
    ###########################################################################

    LAST="${BASE##*/}"


    ###########################################################################
    # Check whether the Jobname is already the final directory
    #
    # Example:
    #
    # TargetPath = Backup/Video_Backup/
    # Jobname    = Video_Backup
    #
    # In this case LAST == JOB and nothing should be changed.
    ###########################################################################

    if [ "$LAST" = "$JOB" ]; then
        continue
    fi


    ###########################################################################
    # Create the new destination path
    ###########################################################################

    NEWTARGET="${BASE}/${JOB}/"


    ###########################################################################
    # Escape single quotes for SQLite
    ###########################################################################

    SQLJOB=$(printf '%s' "$JOB" | sed "s/'/''/g")
    SQLTARGET=$(printf '%s' "$NEWTARGET" | sed "s/'/''/g")


    ###########################################################################
    # Update only the current job
    ###########################################################################

    RESULT=$(sqlite3 "$DB" \
        "UPDATE BackupJobEntry
         SET TargetPath='$SQLTARGET'
         WHERE Jobname='$SQLJOB';
         SELECT changes();")


    ###########################################################################
    # Log only when an actual database record was changed
    ###########################################################################

    if [ "$RESULT" = "1" ]; then

        echo "$(date) Changed: $JOB -> $NEWTARGET" >> "$LOG"

    fi

done

exit 0

