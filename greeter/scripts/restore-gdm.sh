#!/bin/bash
# EMERGENCY ROLLBACK: put GDM back as the login screen.
#
# If the greeter ever fails to come up, switch to a TTY with Ctrl+Alt+F3, log
# in, and run:
#
#     sudo /usr/local/sbin/restore-gdm
#
# Written to be dependency-free and to keep going even if a step fails, because
# it runs precisely when things are already broken.

echo "Stopping and disabling greetd..."
systemctl disable greetd 2>/dev/null
systemctl stop greetd 2>/dev/null

echo "Re-enabling GDM..."
systemctl enable gdm 2>/dev/null
ln -sf /usr/lib/systemd/system/gdm.service /etc/systemd/system/display-manager.service
systemctl daemon-reload 2>/dev/null

echo
echo "display-manager.service now points at:"
readlink -f /etc/systemd/system/display-manager.service

echo
echo "Starting GDM now (or just reboot)..."
systemctl start gdm 2>/dev/null

echo "Done. GDM restored."
