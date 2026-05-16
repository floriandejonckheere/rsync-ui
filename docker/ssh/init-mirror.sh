#!/bin/sh
set -e

apk add --no-cache openssh

id user >/dev/null 2>&1 || adduser -D -s /bin/sh user
passwd -u user

mkdir -p /home/user/.ssh
cat > /home/user/.ssh/authorized_keys << 'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP0P6Z37tJ+iyQ7kRz8z/5rtCAApH66xzQZBFqhiUlfT test
EOF
chmod 700 /home/user/.ssh
chmod 600 /home/user/.ssh/authorized_keys
chown -R user:user /home/user/.ssh

cat > /etc/ssh/ssh_host_ed25519_key << 'EOF'
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACC0VgyyMv6ezZ583RCWroYs4jq1+Os9i4UpedlbjdnC6wAAAIiyPphSsj6Y
UgAAAAtzc2gtZWQyNTUxOQAAACC0VgyyMv6ezZ583RCWroYs4jq1+Os9i4UpedlbjdnC6w
AAAECKNuqmLjDAMy1OS1EYFqtClmkYxOUdZaDBkvBBDeq/T7RWDLIy/p7NnnzdEJauhizi
OrX46z2LhSl52VuN2cLrAAAAAAECAwQF
-----END OPENSSH PRIVATE KEY-----
EOF
chmod 600 /etc/ssh/ssh_host_ed25519_key

cat > /etc/ssh/ssh_host_ed25519_key.pub << 'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILRWDLIy/p7NnnzdEJauhiziOrX46z2LhSl52VuN2cLr
EOF

cat > /etc/ssh/sshd_config << 'EOF'
Port 23
HostKey /etc/ssh/ssh_host_ed25519_key
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
ChallengeResponseAuthentication no
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
