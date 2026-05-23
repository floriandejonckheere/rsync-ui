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

# Create directory structure spanning multiple years and seasons
mkdir -p \
  /data/photos/2020/spring \
  /data/photos/2020/summer \
  /data/photos/2020/autumn \
  /data/photos/2020/winter \
  /data/photos/2021/spring \
  /data/photos/2021/summer \
  /data/photos/2021/autumn \
  /data/photos/2021/winter \
  /data/photos/2022/spring \
  /data/photos/2022/summer \
  /data/photos/2022/autumn \
  /data/photos/2022/winter \
  /data/photos/2023/spring \
  /data/photos/2023/summer \
  /data/photos/2023/autumn \
  /data/photos/2023/winter \
  /data/photos/2024/spring \
  /data/photos/2024/summer \
  /data/photos/2024/autumn \
  /data/photos/2024/winter \
  /data/photos/2025/spring \
  /data/photos/2025/summer

# Generate images: ~10 per season folder (22 folders × ~10 = ~220 images)
# Sizes vary between 300KB and 2MB to simulate real photos
create_images() {
  dir="$1"
  count="$2"
  i=1
  while [ "$i" -le "$count" ]; do
    # Alternate between small (300KB), medium (800KB), and large (1.5MB)
    case $(( (i + count) % 3 )) in
      0) size=300 ;;
      1) size=800 ;;
      2) size=1500 ;;
    esac
    dd if=/dev/urandom of="${dir}/IMG_$(printf '%03d' "$i").jpg" bs=1024 count="$size" status=none 2>/dev/null || \
      dd if=/dev/zero  of="${dir}/IMG_$(printf '%03d' "$i").jpg" bs=1024 count="$size" status=none
    i=$(( i + 1 ))
  done
}

create_images /data/photos/2020/spring  10
create_images /data/photos/2020/summer  12
create_images /data/photos/2020/autumn   9
create_images /data/photos/2020/winter   8
create_images /data/photos/2021/spring  11
create_images /data/photos/2021/summer  14
create_images /data/photos/2021/autumn  10
create_images /data/photos/2021/winter   7
create_images /data/photos/2022/spring  10
create_images /data/photos/2022/summer  13
create_images /data/photos/2022/autumn   9
create_images /data/photos/2022/winter   8
create_images /data/photos/2023/spring  11
create_images /data/photos/2023/summer  15
create_images /data/photos/2023/autumn  10
create_images /data/photos/2023/winter   9
create_images /data/photos/2024/spring  10
create_images /data/photos/2024/summer  12
create_images /data/photos/2024/autumn   8
create_images /data/photos/2024/winter   7
create_images /data/photos/2025/spring  11
create_images /data/photos/2025/summer  13

chown -R nas:nas /data/photos

mkdir -p /run/sshd
exec /usr/sbin/sshd -D -e
