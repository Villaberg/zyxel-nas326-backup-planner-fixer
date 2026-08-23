#!/bin/sh

###############################################################################
# Zyxel NAS326 Backup Planner
#
# Manual Target Path Migration
#
# Converts every Backup Planner TargetPath to:
#
#     <existing destination>/<Jobname>/
#
# Example:
#
#     Video_Backup | Backup/
#
# becomes:
#
#     Video_Backup | Backup/Video_Backup/
#
# A database backup is created before any modification.
###############################################################################

DB="/etc/zyxel/backupjob.db"


###############################################################################
# Root check
###############################################################################

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: This script must be run as root."
    exit 1
fi


###############################################################################
# Database check
###############################################################################

if [ ! -f "$DB" ]; then
    echo "ERROR: Database not found:"
    echo "$DB"
    exit 1
fi


###############################################################################
# Header
###############################################################################

echo
echo "=============================================================="
echo " Zyxel NAS326 Backup Planner"
echo " Manual Target Path Migration"
echo "=============================================================="
echo


###############################################################################
# Database backup
###############################################################################

BACKUP="${DB}.bak"

cp -p "$DB" "$BACKUP"

echo "Database backup created:"
echo "  $BACKUP"
echo


###############################################################################
# Show current configuration
###############################################################################

echo "Current configuration:"
echo

sqlite3 -header -column "$DB" \
"SELECT Jobname, TargetPath FROM BackupJobEntry;"

echo


###############################################################################
# Confirmation
###############################################################################

echo "WARNING:"
echo
echo "This operation will modify all Backup Planner TargetPath values."
echo
echo "The destination directory will be preserved and the Jobname"
echo "will be appended as a subdirectory."
echo
echo "Example:"
echo
echo "  Backup/ -> Backup/JobName/"
echo

printf "Continue? [y/N]: "

read ANSWER

case "$ANSWER" in
    y|Y|yes|YES)
        ;;
    *)
        echo
        echo "Cancelled."
        exit 0
        ;;
esac


###############################################################################
# Read jobs and update individually
###############################################################################

sqlite3 "$DB" -separator '|' \
"SELECT Jobname, TargetPath
 FROM BackupJobEntry;" |
while IFS='|' read JOB TARGET
do

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


    [ -z "$BASE" ] && continue


    ###########################################################################
    # Check whether already correct
    ###########################################################################

    LAST="${BASE##*/}"

    if [ "$LAST" = "$JOB" ]; then

        echo "Already correct:"
        echo "  $JOB -> $TARGET"

        continue

    fi


    ###########################################################################
    # Create new path
    ###########################################################################

    NEWTARGET="${BASE}/${JOB}/"


    ###########################################################################
    # Escape SQLite strings
    ###########################################################################

    SQLJOB=$(printf '%s' "$JOB" | sed "s/'/''/g")
    SQLTARGET=$(printf '%s' "$NEWTARGET" | sed "s/'/''/g")


    ###########################################################################
    # Update
    ###########################################################################

    sqlite3 "$DB" \
        "UPDATE BackupJobEntry
         SET TargetPath='$SQLTARGET'
         WHERE Jobname='$SQLJOB';"


    echo "Changed:"
    echo "  $JOB"
    echo "  $TARGET"
    echo "  -> $NEWTARGET"
    echo

done


###############################################################################
# Show result
###############################################################################

echo
echo "=============================================================="
echo " Result"
echo "=============================================================="
echo

sqlite3 -header -column "$DB" \
"SELECT Jobname, SourcePath, TargetPath
 FROM BackupJobEntry;"

echo
echo "Migration complete."
echo
echo "Database backup:"
echo "  $BACKUP"
echo