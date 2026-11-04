#!/usr/bin/env bash

# Show a quick snapshot of Linux server performance.
set -o pipefail
export LC_ALL=C

if [[ ! -r /proc/stat || ! -r /proc/meminfo ]]; then
  printf 'Error: this script requires a Linux system with readable /proc files.\n' >&2
  exit 1
fi

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Error: required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

for command_name in awk date df ps sleep; do
  require_command "$command_name"
done

read_cpu_counters() {
  awk '$1 == "cpu" {
    idle = $5 + $6
    total = 0
    # guest and guest_nice are already included in user and nice.
    for (i = 2; i <= 9 && i <= NF; i++) total += $i
    printf "%.0f %.0f\n", total, idle
    exit
  }' /proc/stat
}

format_bytes() {
  awk -v bytes="$1" 'BEGIN {
    split("B KiB MiB GiB TiB", units, " ")
    unit = 1
    while (bytes >= 1024 && unit < 5) {
      bytes /= 1024
      unit++
    }
    printf "%.1f %s", bytes, units[unit]
  }'
}

printf '%s\n' '========================================'
printf '%s\n' '        SERVER PERFORMANCE STATS'
printf '%s\n' '========================================'
printf 'Generated: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || printf 'unknown')"

# Compare two aggregate CPU counters one second apart for a meaningful usage rate.
cpu_before=$(read_cpu_counters)
sleep 1
cpu_after=$(read_cpu_counters)
cpu_usage=$(awk -v before="$cpu_before" -v after="$cpu_after" 'BEGIN {
  split(before, a, " "); split(after, b, " ")
  total = b[1] - a[1]
  idle = b[2] - a[2]
  if (total > 0) printf "%.1f%%", 100 * (total - idle) / total
  else printf "N/A"
}')
printf '%s\n' 'CPU'
printf '  Total usage (1-second sample): %s\n\n' "$cpu_usage"

memory_stats=$(awk '
  /^MemTotal:/ { total = $2 * 1024 }
  /^MemFree:/ { free = $2 * 1024 }
  /^MemAvailable:/ { available = $2 * 1024 }
  END {
    if (total <= 0) exit 1
    used = total - (available > 0 ? available : free)
    printf "%.0f %.0f %.0f %.1f", total, used, free, used * 100 / total
  }
' /proc/meminfo) || {
  printf 'Error: unable to read memory statistics.\n' >&2
  exit 1
}
read -r memory_total memory_used memory_free memory_percent <<< "$memory_stats"
printf '%s\n' 'Memory'
printf '  Total: %s\n' "$(format_bytes "$memory_total")"
printf '  Used:  %s (%s%%)\n' "$(format_bytes "$memory_used")" "$memory_percent"
printf '  Free:  %s (MemFree)\n' "$(format_bytes "$memory_free")"
printf '  Available for apps: %s (MemAvailable)\n\n' \
  "$(format_bytes "$((memory_total - memory_used))")"

disk_stats=$(df -hP / | awk 'NR == 2 { printf "%s %s %s %s", $2, $3, $4, $5 }')
if [[ -z "$disk_stats" ]]; then
  printf 'Error: unable to read disk statistics for /.\n' >&2
  exit 1
fi
read -r disk_total disk_used disk_free disk_percent <<< "$disk_stats"
printf '%s\n' 'Root disk (/)'
printf '  Total: %s\n' "$disk_total"
printf '  Used:  %s (%s)\n' "$disk_used" "$disk_percent"
printf '  Free:  %s\n\n' "$disk_free"

printf '%s\n' 'Top 5 processes by CPU usage'
ps -eo pid,user,pcpu,pmem,comm --sort=-pcpu | awk 'NR <= 6'
printf '\n%s\n' 'Top 5 processes by memory usage'
ps -eo pid,user,pcpu,pmem,comm --sort=-pmem | awk 'NR <= 6'
printf '\n'

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  printf 'OS: %s\n' "${PRETTY_NAME:-Linux}"
fi
if [[ -r /proc/uptime ]]; then
  awk '{ seconds = int($1); days = int(seconds / 86400); hours = int(seconds % 86400 / 3600); minutes = int(seconds % 3600 / 60); printf "Uptime: %d days, %d hours, %d minutes\n", days, hours, minutes }' /proc/uptime
fi
if [[ -r /proc/loadavg ]]; then
  read -r load_1 load_5 load_15 _ < /proc/loadavg
  printf 'Load average (1, 5, 15 min): %s %s %s\n' "$load_1" "$load_5" "$load_15"
fi
