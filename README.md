# Server Performance Stats

A Bash script that prints a quick performance snapshot for a Linux server: total CPU usage, memory and root disk usage, the top five processes by CPU and memory, plus a few system details.

## Requirements

- Linux with `/proc` mounted
- Bash 4 or newer
- `awk`, `date`, `df`, `ps`, and `sleep` (commonly available on Linux systems)

## Run

Clone the repository on a Linux server, then run:

```bash
chmod +x server-stats.sh
./server-stats.sh
```

Or run it without changing the file permissions:

```bash
bash server-stats.sh
```

The CPU percentage is sampled over one second. Memory usage is calculated as total memory minus `MemAvailable` (the amount the kernel estimates can be used by applications); the free line also shows `MemFree`. Disk usage reports the root filesystem (`/`).

## Included stats

- Total CPU usage, sampled over one second
- Total, used, and free memory, with used percentage
- Total, used, and free disk space for `/`, with used percentage
- Top five processes by CPU usage
- Top five processes by memory usage
- Linux distribution, uptime, and load averages

## Project page

[roadmap.sh — Server Stats](https://roadmap.sh/projects/server-stats)
