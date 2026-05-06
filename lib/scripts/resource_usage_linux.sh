set -e
echo "---CPU---"
nproc
grep '^cpu ' /proc/stat
sleep 1
grep '^cpu ' /proc/stat
echo "---MEM---"
cat /proc/meminfo
echo "---UPTIME---"
cat /proc/uptime
cat /proc/loadavg
echo "---DISK---"
df -PB1 "$TARGET_PATH"
