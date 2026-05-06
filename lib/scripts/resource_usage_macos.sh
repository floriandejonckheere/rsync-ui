set -e
echo "---CPU---"
sysctl -n hw.logicalcpu
top -l 2 -n 0 -s 1 | grep "CPU usage:" | tail -1
echo "---MEM---"
PAGE_SIZE=$(sysctl -n hw.pagesize)
MEM_TOTAL_BYTES=$(sysctl -n hw.memsize)
MEM_TOTAL_KB=$((MEM_TOTAL_BYTES / 1024))
VM=$(vm_stat)
FREE=$(echo "$VM" | awk '/^Pages free:/ {gsub(/[^0-9]/, ""); print}')
INACTIVE=$(echo "$VM" | awk '/^Pages inactive:/ {gsub(/[^0-9]/, ""); print}')
SPECULATIVE=$(echo "$VM" | awk '/^Pages speculative:/ {gsub(/[^0-9]/, ""); print}')
PURGEABLE=$(echo "$VM" | awk '/^Pages purgeable:/ {gsub(/[^0-9]/, ""); print}')
AVAIL_KB=$(( (${FREE:-0} + ${INACTIVE:-0} + ${SPECULATIVE:-0} + ${PURGEABLE:-0}) * PAGE_SIZE / 1024 ))
echo "MemTotal: $MEM_TOTAL_KB kB"
echo "MemAvailable: $AVAIL_KB kB"
echo "---UPTIME---"
BOOT_SEC=$(sysctl -n kern.boottime | awk '{print $4}' | tr -d ',')
NOW=$(date +%s)
echo "$((NOW - BOOT_SEC)) 0"
sysctl -n vm.loadavg | tr -d '{}' | awk '{print $1, $2, $3, "0/0", "0"}'
echo "---DISK---"
df -Pk "$TARGET_PATH" | awk 'NR>1 {print $1, $2*1024, $3*1024, $4*1024, $5, $6}'
