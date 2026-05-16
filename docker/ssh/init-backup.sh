#!/bin/sh
set -e

apk add --no-cache openssh

adduser -D -s /bin/sh backup
echo "backup:backup-password" | chpasswd

ssh-keygen -A

cat > /etc/ssh/sshd_config << 'EOF'
Port 22
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication no
ChallengeResponseAuthentication no
UsePAM no
PrintLastLog no
EOF

mkdir -p /data/daily /data/weekly /data/monthly
dd if=/dev/zero of=/data/daily/backup-2024-05-16.tar bs=1M count=20 status=none
dd if=/dev/zero of=/data/daily/backup-2024-05-15.tar bs=1M count=18 status=none
dd if=/dev/zero of=/data/daily/backup-2024-05-14.tar bs=1M count=17 status=none
dd if=/dev/zero of=/data/weekly/backup-2024-w19.tar bs=1M count=35 status=none
dd if=/dev/zero of=/data/weekly/backup-2024-w18.tar bs=1M count=32 status=none
dd if=/dev/zero of=/data/monthly/backup-2024-04.tar bs=1M count=60 status=none
dd if=/dev/zero of=/data/monthly/backup-2024-03.tar bs=1M count=55 status=none
dd if=/dev/zero of=/data/checksums.md5 bs=4K count=1 status=none

mkdir -p /run/sshd
exec /usr/sbin/sshd -D -e
