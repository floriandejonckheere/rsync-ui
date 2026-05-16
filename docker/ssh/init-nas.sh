#!/bin/sh
set -e

apk add --no-cache openssh

adduser -D -s /bin/sh backup
echo "backup:nas-password" | chpasswd

cat > /etc/ssh/ssh_host_ed25519_key << 'EOF'
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACAqrJ+8Yt0ElBYY1zvcLRoEVNfgnJIMA40LcH783pnflAAAAIgQPIUNEDyF
DQAAAAtzc2gtZWQyNTUxOQAAACAqrJ+8Yt0ElBYY1zvcLRoEVNfgnJIMA40LcH783pnflA
AAAECXPz4JXY0akJzI9sQQfeVv/Qh//LEPCiFtxwsdnY3foyqsn7xi3QSUFhjXO9wtGgRU
1+CckgwDjQtwfvzemd+UAAAAAAECAwQF
-----END OPENSSH PRIVATE KEY-----
EOF
chmod 600 /etc/ssh/ssh_host_ed25519_key

cat > /etc/ssh/ssh_host_ed25519_key.pub << 'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICqsn7xi3QSUFhjXO9wtGgRU1+CckgwDjQtwfvzemd+U
EOF

cat > /etc/ssh/sshd_config << 'EOF'
Port 22
HostKey /etc/ssh/ssh_host_ed25519_key
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
