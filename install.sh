#!/bin/sh

###############################################################################
# Zyxel NAS326 Backup Planner - Installer
###############################################################################

set -e


###############################################################################
# Configuration
###############################################################################

INSTALL_DIR="/root"

SCRIPT_NAME="fix_backup_targets.sh"

SOURCE_SCRIPT="./fix_backup_targets.sh"

INSTALL_SCRIPT="${INSTALL_DIR}/${SCRIPT_NAME}"

CRON_DIR="/var/spool/cron/crontabs"

CRON_FILE="${CRON_DIR}/root"

CRON_LINE="* * * * * ${INSTALL_SCRIPT} > /dev/null 2>&1"

DB="/etc/zyxel/backupjob.db"

LOG="/i-data/.system/fix_backup_targets.log"


###############################################################################
# Error function
###############################################################################

error()
{
    echo
    echo "ERROR: $1"
    echo
    exit 1
}


###############################################################################
# Header
###############################################################################

echo
echo "=============================================================="
echo " Zyxel NAS326 Backup Planner"
echo " Automatic Target Path Fixer"
echo " Installation"
echo "=============================================================="
echo


###############################################################################
# Root check
###############################################################################

if [ "$(id -u)" != "0" ]; then
    error "This installer must be run as root."
fi

echo "[OK] Running as root."


###############################################################################
# Database check
###############################################################################

if [ ! -f "$DB" ]; then
    error "Backup Planner database not found:
$DB"
fi

echo "[OK] Backup Planner database found."


###############################################################################
# SQLite check
###############################################################################

if ! command -v sqlite3 >/dev/null 2>&1; then
    error "sqlite3 was not found."
fi

echo "[OK] sqlite3 found."


###############################################################################
# Source script check
###############################################################################

if [ ! -f "$SOURCE_SCRIPT" ]; then
    error "Cannot find:
$SOURCE_SCRIPT

Make sure install.sh and fix_backup_targets.sh are in the same directory."
fi

echo "[OK] fix_backup_targets.sh found."


###############################################################################
# Check database structure
###############################################################################

TABLES=$(sqlite3 "$DB" ".tables" 2>/dev/null)

case "$TABLES" in
    *BackupJobEntry*)
        echo "[OK] BackupJobEntry table found."
        ;;
    *)
        error "BackupJobEntry table not found."
        ;;
esac


###############################################################################
# Backup existing installed script
###############################################################################

if [ -f "$INSTALL_SCRIPT" ]; then

    BACKUP_FILE="${INSTALL_SCRIPT}.bak"

    cp -p "$INSTALL_SCRIPT" "$BACKUP_FILE"

    echo "[OK] Existing script backed up:"
    echo "     $BACKUP_FILE"

fi


###############################################################################
# Install main script
###############################################################################

cp "$SOURCE_SCRIPT" "$INSTALL_SCRIPT"

chmod 700 "$INSTALL_SCRIPT"

echo "[OK] Installed:"
echo "     $INSTALL_SCRIPT"


###############################################################################
# Create log directory
###############################################################################

LOG_DIR=$(dirname "$LOG")

if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
fi


###############################################################################
# Create cron directory
###############################################################################

if [ ! -d "$CRON_DIR" ]; then
    mkdir -p "$CRON_DIR"
fi


###############################################################################
# Backup existing crontab
###############################################################################

if [ -f "$CRON_FILE" ]; then

    CRON_BACKUP="${CRON_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

    cp -p "$CRON_FILE" "$CRON_BACKUP"

    echo "[OK] Existing root crontab backed up:"
    echo "     $CRON_BACKUP"

else

    touch "$CRON_FILE"

    echo "[INFO] Created new root crontab."

fi


###############################################################################
# Add cron entry if necessary
###############################################################################

if grep -F "$CRON_LINE" "$CRON_FILE" >/dev/null 2>&1; then

    echo "[OK] Cron entry already exists."

else

    echo "$CRON_LINE" >> "$CRON_FILE"

    echo "[OK] Cron entry installed:"
    echo "     $CRON_LINE"

fi


###############################################################################
# Verify cron entry
###############################################################################

if ! grep -F "$CRON_LINE" "$CRON_FILE" >/dev/null 2>&1; then
    error "Failed to install cron entry."
fi


###############################################################################
# Initial test
###############################################################################

echo
echo "Running initial test..."
echo

if "$INSTALL_SCRIPT"; then

    echo
    echo "[OK] fix_backup_targets.sh executed successfully."

else

    echo
    echo "[WARNING] fix_backup_targets.sh returned an error."
    echo "Check:"
    echo "$LOG"

fi


###############################################################################
# Show current jobs
###############################################################################

echo
echo "Current Backup Planner targets:"
echo

sqlite3 "$DB" \
"SELECT Jobname, TargetPath FROM BackupJobEntry;"


###############################################################################
# Complete
###############################################################################

echo
echo "=============================================================="
echo " Installation complete"
echo "=============================================================="
echo
echo "Installed script:"
echo "  $INSTALL_SCRIPT"
echo
echo "Cron:"
echo "  $CRON_LINE"
echo
echo "Log:"
echo "  $LOG"
echo
echo "The script will run automatically once every minute."
echo