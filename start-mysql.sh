#!/bin/bash
set -e

# Regenerate SSH host keys at runtime so each container gets unique keys
# instead of sharing the keys apt baked into the image at build time.
rm -f /etc/ssh/ssh_host_*
ssh-keygen -A

# Start MySQL
service mysql start

# Start SSH in the foreground
exec /usr/sbin/sshd -D -e
