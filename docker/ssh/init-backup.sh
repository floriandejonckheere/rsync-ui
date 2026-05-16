#!/bin/sh
set -e

apk add --no-cache openssh rsync

id backup >/dev/null 2>&1 || adduser -D -s /bin/sh backup
echo "backup:backup-password" | chpasswd

cat > /etc/ssh/ssh_host_ed25519_key << 'EOF'
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACDE9ZnTL2TJsPQk/IfxBeCPt3iUqbPjStpfQ41RtQAwUAAAAIimCRaNpgkW
jQAAAAtzc2gtZWQyNTUxOQAAACDE9ZnTL2TJsPQk/IfxBeCPt3iUqbPjStpfQ41RtQAwUA
AAAEBhn2bqQ7BLaE5aNFm6j0FTWvlMPcoUplvZ1zSjwZ7ZKcT1mdMvZMmw9CT8h/EF4I+3
eJSps+NK2l9DjVG1ADBQAAAAAAECAwQF
-----END OPENSSH PRIVATE KEY-----
EOF
chmod 600 /etc/ssh/ssh_host_ed25519_key

cat > /etc/ssh/ssh_host_ed25519_key.pub << 'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMT1mdMvZMmw9CT8h/EF4I+3eJSps+NK2l9DjVG1ADBQ
EOF

cat > /etc/ssh/sshd_config << 'EOF'
Port 22
HostKey /etc/ssh/ssh_host_ed25519_key
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication no
ChallengeResponseAuthentication no
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
chown -R backup:backup /data

mkdir -p /run/sshd
exec /usr/sbin/sshd -D -e
