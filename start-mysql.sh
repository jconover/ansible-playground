#!/bin/bash
set -e

# Start MySQL
service mysql start

# Start SSH in the foreground
exec /usr/sbin/sshd -D
