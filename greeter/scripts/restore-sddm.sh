#!/bin/bash
# EMERGENCY ROLLBACK: put SDDM back as the login screen (Arch variant of
# restore-gdm.sh).
#
# If the greeter ever fails to come up, switch to a TTY with Ctrl+Alt+F3, log
# in, and run:
#
#     sudo /usr/local/sbin/restore-sddm
#
# Written to be dependency-free and to keep going even if a step fails, because
# it runs precisely when things are already broken.
set +e

echo "Stopping and disabling greetd..."
systemctl disable greetd 2>/dev/null
systemctl stop greetd 2>/dev/null

echo "Re-enabling SDDM..."
systemctl enable sddm 2>/dev/null
ln -sf /usr/lib/systemd/system/sddm.service /etc/systemd/system/display-manager.service
systemctl daemon-reload 2>/dev/null

echo
echo "display-manager.service now points at:"
readlink -f /etc/systemd/system/display-manager.service

echo
echo "Starting SDDM now (or just reboot)..."
systemctl start sddm 2>/dev/null

echo "Done. SDDM restored."
