#!/bin/bash
set -e

# Regenerate SSH host keys at runtime so every container gets unique keys.
# Both apt's openssh-server postinst and any build-time `ssh-keygen -A` bake
# host keys into the image, which means all containers from the same image
# would share identical keys (a security smell even for a disposable lab).
# ssh-keygen -A only creates *missing* keys, so we remove the baked ones first.
rm -f /etc/ssh/ssh_host_*
ssh-keygen -A

# Run sshd in the foreground.
exec /usr/sbin/sshd -D -e
