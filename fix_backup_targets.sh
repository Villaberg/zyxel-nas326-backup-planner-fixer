#!/bin/sh

###############################################################################
# Zyxel NAS326 Backup Planner - Automatic Target Path Fixer
#
# Automatically appends the Backup Planner Jobname to the configured
# TargetPath.
#
# Example:
#
#   Jobname:    Video_Backup
#   TargetPath: Backup/
#
# becomes:
#
#   TargetPath: Backup/Video_Backup/
#
# The destination directory is NOT hard-coded.
# The script reads TargetPath directly from Backup Planner.
###############################################################################

DB="/etc/zyxel/backupjob.db"
LOG="/i-data/.system/fix_backup_targets.log"


###############################################################################
# Check database
###############################################################################

if [ ! -f "$DB" ]; then
    exit 1
fi


###############################################################################
# Read Backup Planner jobs
###############################################################################

sqlite3 "$DB" -separator '|' \
"SELECT Jobname, TargetPath
 FROM BackupJobEntry;" |
while IFS='|' read JOB TARGET
do

    # Ignore incomplete records
    [ -z "$JOB" ] && continue
    [ -z "$TARGET" ] && continue


    ###########################################################################
    # Remove trailing slash(es)
    ###########################################################################

    BASE="$TARGET"

    while [ "${BASE%/}" != "$BASE" ]
    do
        BASE="${BASE%/}"
    done


    # Ignore empty paths
    [ -z "$BASE" ] && continue


    ###########################################################################
    # Get final directory component
    ###########################################################################

    LAST="${BASE##*/}"


    ###########################################################################
    # Already correct?
    ###########################################################################

    if [ "$LAST" = "$JOB" ]; then
        continue
    fi


    ###########################################################################
    # Construct new target
    ###########################################################################

    NEWTARGET="${BASE}/${JOB}/"


    ###########################################################################
    # Escape apostrophes for SQLite
    ###########################################################################

    SQLJOB=$(printf '%s' "$JOB" | sed "s/'/''/g")
    SQLTARGET=$(printf '%s' "$NEWTARGET" | sed "s/'/''/g")


    ###########################################################################
    # Update database
    ###########################################################################

    RESULT=$(sqlite3 "$DB" \
        "UPDATE BackupJobEntry
         SET TargetPath='$SQLTARGET'
         WHERE Jobname='$SQLJOB';
         SELECT changes();")


    ###########################################################################
    # Log changes only
    ###########################################################################

    if [ "$RESULT" = "1" ]; then
        echo "$(date) Changed: $JOB -> $NEWTARGET" >> "$LOG"
    fi

done

exit 0