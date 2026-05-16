#!/bin/sh
set -e

apk add --no-cache openssh

adduser -D -s /bin/sh user

mkdir -p /home/user/.ssh
cat > /home/user/.ssh/authorized_keys << 'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP0P6Z37tJ+iyQ7kRz8z/5rtCAApH66xzQZBFqhiUlfT test
EOF
chmod 700 /home/user/.ssh
chmod 600 /home/user/.ssh/authorized_keys
chown -R user:user /home/user/.ssh

ssh-keygen -A

cat > /etc/ssh/sshd_config << 'EOF'
Port 23
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
ChallengeResponseAuthentication no
UsePAM no
PrintLastLog no
EOF

mkdir -p /data/snapshots /data/logs
dd if=/dev/zero of=/data/snapshots/snap-2024-05-16.img bs=1M count=50 status=none
dd if=/dev/zero of=/data/snapshots/snap-2024-05-09.img bs=1M count=48 status=none
dd if=/dev/zero of=/data/snapshots/snap-2024-05-02.img bs=1M count=45 status=none
dd if=/dev/zero of=/data/snapshots/snap-2024-04-25.img bs=1M count=42 status=none
dd if=/dev/zero of=/data/snapshots/snap-2024-04-18.img bs=1M count=40 status=none
dd if=/dev/zero of=/data/logs/transfer-2024-05.log bs=1M count=1 status=none
dd if=/dev/zero of=/data/logs/transfer-2024-04.log bs=1M count=1 status=none
dd if=/dev/zero of=/data/checksums.md5 bs=4K count=1 status=none

mkdir -p /run/sshd
exec /usr/sbin/sshd -D -e
