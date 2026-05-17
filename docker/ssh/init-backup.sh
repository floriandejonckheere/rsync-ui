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

echo "Creating Home Backup repository..."
echo "Creating Projects Backup repository..."
mkdir -p /backup/home /backup/projects
chown -R backup:backup /backup

mkdir -p /run/sshd
exec /usr/sbin/sshd -D -e
