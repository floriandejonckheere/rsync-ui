#!/bin/sh
set -e

apk add --no-cache openssh rsync

id nas >/dev/null 2>&1 || adduser -D -s /bin/sh nas
echo "nas:nas-password" | chpasswd

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
EOF

echo "Creating NAS Photos repository data..."
mkdir -p \
  /data/photos/2024/summer \
  /data/photos/2024/winter \
  /data/photos/2025/spring \
  /data/photos/2025/summer
dd if=/dev/zero of=/data/photos/2024/summer/IMG_001.jpg bs=1M count=5 status=none
dd if=/dev/zero of=/data/photos/2024/summer/IMG_002.jpg bs=1M count=4 status=none
dd if=/dev/zero of=/data/photos/2024/summer/IMG_003.jpg bs=1M count=6 status=none
dd if=/dev/zero of=/data/photos/2024/winter/IMG_001.jpg bs=1M count=4 status=none
dd if=/dev/zero of=/data/photos/2024/winter/IMG_002.jpg bs=1M count=5 status=none
dd if=/dev/zero of=/data/photos/2025/spring/IMG_001.jpg bs=1M count=3 status=none
dd if=/dev/zero of=/data/photos/2025/spring/IMG_002.jpg bs=1M count=4 status=none
dd if=/dev/zero of=/data/photos/2025/summer/IMG_001.jpg bs=1M count=5 status=none
dd if=/dev/zero of=/data/photos/2025/summer/IMG_002.jpg bs=1M count=3 status=none
dd if=/dev/zero of=/data/photos/2025/summer/IMG_003.jpg bs=1M count=6 status=none
chown -R nas:nas /data/photos

mkdir -p /run/sshd
exec /usr/sbin/sshd -D -e
