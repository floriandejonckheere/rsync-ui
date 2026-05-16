#!/bin/sh
set -e

apk add --no-cache openssh

adduser -D -s /bin/sh backup
echo "backup:nas-password" | chpasswd

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

mkdir -p /data/documents /data/photos /data/videos
dd if=/dev/zero of=/data/documents/report-2024.pdf bs=1M count=4 status=none
dd if=/dev/zero of=/data/documents/report-2023.pdf bs=1M count=4 status=none
dd if=/dev/zero of=/data/documents/spreadsheet.xlsx bs=1M count=2 status=none
dd if=/dev/zero of=/data/photos/vacation-001.jpg bs=1M count=4 status=none
dd if=/dev/zero of=/data/photos/vacation-002.jpg bs=1M count=3 status=none
dd if=/dev/zero of=/data/photos/vacation-003.jpg bs=1M count=5 status=none
dd if=/dev/zero of=/data/photos/vacation-004.jpg bs=1M count=4 status=none
dd if=/dev/zero of=/data/videos/holiday.mp4 bs=1M count=80 status=none
dd if=/dev/zero of=/data/videos/birthday.mp4 bs=1M count=60 status=none
dd if=/dev/zero of=/data/backup.tar bs=1M count=30 status=none

mkdir -p /run/sshd
exec /usr/sbin/sshd -D -e
