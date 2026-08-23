# Zyxel NAS326 Backup Planner Fixer

Automatically adds the Backup Planner job name as a subdirectory of the
configured destination path on a Zyxel NAS326.

## Example

A Zyxel Backup Planner job may be configured as:

    Jobname:    Video_Backup
    TargetPath: Backup/

This project automatically changes it to:

    Jobname:    Video_Backup
    TargetPath: Backup/Video_Backup/

The important point is that `Backup/` is **not hard-coded**.

The script reads the destination directory directly from Backup Planner.

For example:

    Jobname:    Video_Backup
    TargetPath: MyBackups/

becomes:

    MyBackups/Video_Backup/


## Why?

When several Backup Planner jobs use the same destination directory,
the resulting backup structure can otherwise become difficult to
identify.

With this script the destination becomes:

    Backup/
    ├── Julia_Home_Backup/
    ├── Foton/
    ├── Video_Backup/
    ├── Musik/
    ├── Elin_homefolder/
    ├── Wares/
    └── Homeassistant/

Each Backup Planner job gets its own directory.


# How it works

The Zyxel NAS326 stores Backup Planner configuration in:

    /etc/zyxel/backupjob.db

The script reads the `BackupJobEntry` table:

    Jobname
    TargetPath

For each job:

1. Read `Jobname`.
2. Read the configured `TargetPath`.
3. Remove trailing `/`.
4. Check the final directory name.
5. If it already equals `Jobname`, do nothing.
6. Otherwise append `/Jobname/`.
7. Update the database.
8. Log the change.

The script is therefore safe to run repeatedly.


# Important: NAS A

The script is intended to run on the NAS where Backup Planner is
configured.

For example:

    NAS A
       |
       | Backup Planner
       |
       v
    NAS B
       |
       | Receives backup


The script runs on **NAS A**.

It does not need to be installed on the receiving NAS.


# Features

- Automatically fixes new Backup Planner jobs.
- Uses the destination configured in Backup Planner.
- Does not hard-code `Backup/`.
- Runs once per minute using BusyBox `crond`.
- Does nothing to already-correct jobs.
- Logs only actual changes.
- Safe to run repeatedly.
- Supports destination paths containing multiple directory levels.
- Includes install and uninstall scripts.
- Creates backups of existing configuration files.


# Requirements

Tested on:

    Zyxel NAS326

Environment:

    BusyBox v1.19.4

Required:

- SSH access
- root access
- Zyxel Backup Planner
- `sqlite3`
- BusyBox `crond`

The script relies on the internal Zyxel Backup Planner SQLite database
and may not work on other Zyxel models or firmware versions.


# Repository structure

    zyxel-nas326-backup-planner-fixer/
    ├── README.md
    ├── LICENSE
    ├── install.sh
    ├── uninstall.sh
    ├── fix_backup_targets.sh
    └── update_backup_paths.sh


## Files

### `fix_backup_targets.sh`

The main automatic script.

It is installed as:

    /root/fix_backup_targets.sh

It reads the Backup Planner database and fixes TargetPath values.


### `install.sh`

Installs the automatic target fixer and adds the cron entry.

It performs checks before installation and creates backups of existing
files.


### `uninstall.sh`

Removes the automatic script and its cron entry.

It does **not** modify the Backup Planner database.


### `update_backup_paths.sh`

Optional manual migration tool.

It can be used to update all existing Backup Planner jobs at once.

It creates a backup of the database before making changes.


# Installation

SSH into the Zyxel NAS326 and become root.

Clone the repository:

    git clone https://github.com/USERNAME/zyxel-nas326-backup-planner-fixer.git

Enter the directory:

    cd zyxel-nas326-backup-planner-fixer

Make the installer executable:

    chmod +x install.sh

Run:

    ./install.sh


## What the installer does

The installer:

1. Checks that it is running as root.
2. Checks for `/etc/zyxel/backupjob.db`.
3. Checks that `sqlite3` is available.
4. Checks for the `BackupJobEntry` table.
5. Installs `fix_backup_targets.sh`.
6. Makes the script executable.
7. Backs up the existing root crontab.
8. Adds the cron entry if it does not already exist.
9. Runs the fixer once immediately.
10. Displays the current Backup Planner configuration.


# Cron

The installer adds:

    * * * * * /root/fix_backup_targets.sh > /dev/null 2>&1

This executes the script once every minute.

The script is intentionally not implemented as an endless:

    while true
    do
        ...
        sleep 60
    done

loop.

The NAS326 already provides `crond`, so using the existing scheduler is
simpler and avoids keeping an additional shell process running.


# Checking the installation

Check the installed script:

    ls -l /root/fix_backup_targets.sh


Check the cron configuration:

    cat /var/spool/cron/crontabs/root


Check Backup Planner jobs:

    sqlite3 /etc/zyxel/backupjob.db \
    "SELECT Jobname, TargetPath FROM BackupJobEntry;"


Check the log:

    cat /i-data/.system/fix_backup_targets.log


# Example

Before creating a new job:

    Jobname:    Test_Backup
    TargetPath: Backup/


After the next cron execution:

    Jobname:    Test_Backup
    TargetPath: Backup/Test_Backup/


If Backup Planner uses another destination:

    Jobname:    Test_Backup
    TargetPath: MyBackups/


the result becomes:

    Jobname:    Test_Backup
    TargetPath: MyBackups/Test_Backup/


# Existing jobs

The automatic script can also correct existing jobs.

For example:

    Video_Backup | Backup/

becomes:

    Video_Backup | Backup/Video_Backup/


A job that is already:

    Video_Backup | Backup/Video_Backup/

is left untouched.


# Logging

Changes are written to:

    /i-data/.system/fix_backup_targets.log

Example:

    Sun Aug 23 21:01:03 CEST 2026 Changed: Video_Backup -> Backup/Video_Backup/

Only actual changes are logged.

Correctly configured jobs do not generate log entries every minute.


# Manual migration

If you want to explicitly migrate all existing jobs, run:

    ./update_backup_paths.sh

This script asks for confirmation before modifying the database.

It creates:

    /etc/zyxel/backupjob.db.bak

before making changes.


# Database

The project modifies:

    /etc/zyxel/backupjob.db

Relevant table:

    BackupJobEntry


The script uses:

    Jobname

and:

    TargetPath


## Database backup

Before manually modifying the database, a backup should always be kept.

For example:

    cp -p /etc/zyxel/backupjob.db \
          /etc/zyxel/backupjob.db.manual.bak


# Uninstallation

To remove the automatic functionality:

    chmod +x uninstall.sh

Then:

    ./uninstall.sh


The uninstaller:

- Removes the cron entry.
- Removes `/root/fix_backup_targets.sh`.
- Creates a backup of the root crontab.
- Does not modify the Backup Planner database.
- Does not remove the log.


Existing TargetPath modifications remain unchanged after uninstalling.


# Safety

This project modifies an internal Zyxel SQLite database.

The database is not an officially documented public API.

Zyxel may change the database structure in future firmware versions.

Always keep a backup of the database.

Do not manually modify the database while Backup Planner is actively
creating, editing, deleting or executing jobs.


# Idempotency

The automatic script is designed to be idempotent.

For example:

    Video_Backup
    Backup/Video_Backup/

is already correct.

Running the script again will not produce:

    Backup/Video_Backup/Video_Backup/

Instead, it detects that the final directory already equals the
Backup Planner job name and leaves the entry untouched.


# Limitations

The project relies on the internal Backup Planner database structure.

Expected database:

    /etc/zyxel/backupjob.db

Expected table:

    BackupJobEntry

Expected fields:

    Jobname
    TargetPath

Changes to Zyxel firmware or Backup Planner may therefore require
modifications to the script.


# Troubleshooting

## Database not found

Check:

    ls -l /etc/zyxel/backupjob.db


## Check database tables

Run:

    sqlite3 /etc/zyxel/backupjob.db ".tables"


Expected:

    BackupJobEntry
    BackupJobScheduler


## Check jobs

Run:

    sqlite3 /etc/zyxel/backupjob.db \
    "SELECT Jobname, TargetPath FROM BackupJobEntry;"


## Check cron

Run:

    cat /var/spool/cron/crontabs/root


Look for:

    * * * * * /root/fix_backup_targets.sh > /dev/null 2>&1


## Check whether crond is running

Run:

    ps | grep crond


## Run the fixer manually

Run:

    /root/fix_backup_targets.sh


Then:

    sqlite3 /etc/zyxel/backupjob.db \
    "SELECT Jobname, TargetPath FROM BackupJobEntry;"


# Disclaimer

This is an unofficial third-party project.

It is not affiliated with, endorsed by, or supported by Zyxel.

Use it at your own risk.

Always maintain a backup of the Backup Planner database.


# License

MIT License

Copyright (c) 2026

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files, to deal in
the Software without restriction, including without limitation the
rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.