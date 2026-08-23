#!/bin/sh

###############################################################################
# Zyxel NAS326 Backup Planner - Uninstaller
###############################################################################

INSTALL_SCRIPT="/root/fix_backup_targets.sh"

CRON_FILE="/var/spool/cron/crontabs/root"

CRON_LINE="* * * * * /root/fix_backup_targets.sh > /dev/null 2>&1"


###############################################################################
# Root check
###############################################################################

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: This script must be run as root."
    exit 1
fi


###############################################################################
# Header
###############################################################################

echo
echo "=============================================================="
echo " Zyxel NAS326 Backup Planner"
echo " Automatic Target Path Fixer"
echo " Uninstallation"
echo "=============================================================="
echo


###############################################################################
# Remove cron entry
###############################################################################

if [ -f "$CRON_FILE" ]; then

    CRON_BACKUP="${CRON_FILE}.backup.uninstall.$(date +%Y%m%d_%H%M%S)"

    cp -p "$CRON_FILE" "$CRON_BACKUP"

    echo "[OK] Existing crontab backed up:"
    echo "     $CRON_BACKUP"


    ###########################################################################
    # Remove only our cron entry
    ###########################################################################

    TMP="/tmp/root_crontab.$$"

    grep -Fv "$CRON_LINE" "$CRON_FILE" > "$TMP" || true

    cp "$TMP" "$CRON_FILE"

    rm -f "$TMP"

    echo "[OK] Cron entry removed."

else

    echo "[INFO] Root crontab does not exist."

fi


###############################################################################
# Remove installed script
###############################################################################

if [ -f "$INSTALL_SCRIPT" ]; then

    rm -f "$INSTALL_SCRIPT"

    echo "[OK] Removed:"
    echo "     $INSTALL_SCRIPT"

else

    echo "[INFO] Installed script was not found."

fi


###############################################################################
# Complete
###############################################################################

echo
echo "=============================================================="
echo " Uninstallation complete"
echo "=============================================================="
echo
echo "Backup Planner database was NOT modified."
echo
echo "Existing TargetPath values remain unchanged."
echo
echo "The log file, if present, has also been left untouched."
echo