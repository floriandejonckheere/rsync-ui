set -e

OS=$(uname -s)

echo "---CPU---"
if [ "$OS" = "Darwin" ]; then
  sysctl -n hw.logicalcpu
  top -l 2 -n 0 -s 1 | grep "CPU usage:" | tail -1
else
  nproc
  grep '^cpu ' /proc/stat
  sleep 1
  grep '^cpu ' /proc/stat
fi

echo "---MEM---"
if [ "$OS" = "Darwin" ]; then
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
else
  cat /proc/meminfo
fi

echo "---UPTIME---"
if [ "$OS" = "Darwin" ]; then
  BOOT_SEC=$(sysctl -n kern.boottime | awk '{print $4}' | tr -d ',')
  NOW=$(date +%s)
  echo "$((NOW - BOOT_SEC)) 0"
  sysctl -n vm.loadavg | tr -d '{}' | awk '{print $1, $2, $3, "0/0", "0"}'
else
  cat /proc/uptime
  cat /proc/loadavg
fi

echo "---DISK---"
if [ "$OS" = "Darwin" ]; then
  df -Pk "$TARGET_PATH" | awk 'NR>1 {print $1, $2*1024, $3*1024, $4*1024, $5, $6}'
else
  df -PB1 "$TARGET_PATH"
fi
