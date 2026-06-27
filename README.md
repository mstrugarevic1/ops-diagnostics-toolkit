# Ops Diagnostics Toolkit

Small, read-only Bash scripts for Linux system and network diagnostics.

| Script | Purpose |
| --- | --- |
| `disk-usage-alert.sh` | Filesystem capacity checks |
| `service-health-report.sh` | systemd service diagnostics |
| `port-listener-audit.sh` | Listening socket inventory |
| `dns-debug.sh` | DNS resolution diagnostics |
| `tls-expiry-check.sh` | TLS certificate expiry checks |
| `system-pressure-report.sh` | Host resource pressure summary |

## Platform

Supported target:

- Linux
- Bash 4.2 or newer
- Ubuntu, Debian, and similar distributions

The scripts are expected to work on many systemd-based Linux distributions, including Red Hat-like systems, when the required commands are installed. macOS is not a supported target.

## Requirements

Install only the tools needed for the scripts you plan to run.

| Script | Required commands |
| --- | --- |
| `disk-usage-alert.sh` | `df` |
| `service-health-report.sh` | `systemctl` |
| `service-health-report.sh --logs` | `journalctl` |
| `port-listener-audit.sh` | `ss` or `netstat` |
| `dns-debug.sh` | `dig` |
| `tls-expiry-check.sh` | `openssl`, `timeout`, GNU `date` |
| `system-pressure-report.sh` | `/proc`, optional `dmesg` or `journalctl` for OOM checks |

Package names differ by distribution. On Debian/Ubuntu, `dig` is usually in `dnsutils`; on Red Hat-like systems it is usually in `bind-utils`.

## Install

Download the `.deb` package from the GitHub Releases page, then install it:

```bash
sudo dpkg -i ops-diagnostics-toolkit_0.3.0_all.deb
```

The Debian package checks for Bash 4.2 or newer during installation. If the installed Bash version is too old, installation stops with an error.

The Debian package is unofficial and provided only for convenience. It is not provided by or affiliated with Debian, Ubuntu, or any Linux distribution vendor.

No warranty is provided. Use these scripts at your own risk. They are read-only diagnostics, but output can be incomplete, wrong, or misleading if system commands are missing, permissions are limited, or the host is in an unusual state.

Installed commands are available without the `.sh` suffix:

```bash
disk-usage-alert --help
service-health-report --help
port-listener-audit --help
dns-debug --help
tls-expiry-check --help
system-pressure-report --help
```

Backward-compatible `.sh` command names are also installed:

```bash
disk-usage-alert.sh --help
service-health-report.sh --help
port-listener-audit.sh --help
dns-debug.sh --help
tls-expiry-check.sh --help
system-pressure-report.sh --help
```

You can also run the scripts directly from a clone:

```bash
git clone git@github.com:mstrugarevic1/ops-diagnostics-toolkit.git
cd ops-diagnostics-toolkit
chmod +x scripts/*.sh
```

Run any script with `--help`:

```bash
./scripts/disk-usage-alert.sh --help
```

All scripts support:

```text
--help
--version
--no-color
```

## Usage

### Disk Usage

Check mounted filesystems:

```bash
./scripts/disk-usage-alert.sh
```

Use custom thresholds:

```bash
./scripts/disk-usage-alert.sh --warning 75 --critical 90
```

Check one mount path:

```bash
./scripts/disk-usage-alert.sh --filesystem /
```

Include inode usage:

```bash
./scripts/disk-usage-alert.sh --inodes
```

Example output:

```text
STATUS     FILESYSTEM              MOUNT              USED     AVAILABLE
OK         /dev/root               /                  42%      57G
WARNING    /dev/data               /var               83%      17G

STATUS     FILESYSTEM              MOUNT              IUSED    IFREE
OK         /dev/root               /                  42%      58000
WARNING    /dev/data               /var               83%      17000
```

### Service Health

Check selected systemd services:

```bash
./scripts/service-health-report.sh nginx docker ssh
```

Read service names from a file:

```bash
./scripts/service-health-report.sh --file config/services.example.txt
```

List failed units:

```bash
./scripts/service-health-report.sh --failed-only
```

Include recent logs:

```bash
./scripts/service-health-report.sh nginx --logs 5
```

Example output:

```text
STATUS     SERVICE                  LOAD         ACTIVE       SUB          PID      RESTARTS
OK         nginx                    loaded       active       running      1234     0
FAILED     worker.service           loaded       failed       failed       0        3
NOT_FOUND  missing.service          not-found    unknown      -            -        -
```

If `systemctl` exists but the machine was not booted with systemd, the script exits `3` with a clear error.

### Port Listener Audit

List listening TCP and UDP sockets:

```bash
./scripts/port-listener-audit.sh
```

Show process details when available:

```bash
./scripts/port-listener-audit.sh --processes
```

Filter by protocol or port:

```bash
./scripts/port-listener-audit.sh --tcp
./scripts/port-listener-audit.sh --udp
./scripts/port-listener-audit.sh --port 443
```

Show only listeners bound to all interfaces:

```bash
./scripts/port-listener-audit.sh --all-interfaces-only
```

Example output:

```text
PROTOCOL   ADDRESS            PORT    PID      PROCESS        BINDING
tcp        127.0.0.1          5432    111      postgres       LOOPBACK
tcp        0.0.0.0            22      222      sshd           ALL_INTERFACES
udp        0.0.0.0            53      -        -              ALL_INTERFACES

SUMMARY   LOOPBACK=1 ALL_INTERFACES=2 SPECIFIC_INTERFACE=0 IPV6_ALL_INTERFACES=0
```

Binding to all interfaces does not prove the port is reachable from the internet. Firewalls, routing, NAT, and cloud security rules still matter.

### DNS Debug

Run concise DNS checks:

```bash
./scripts/dns-debug.sh example.com
```

Query one record type:

```bash
./scripts/dns-debug.sh example.com --type A
```

Use a specific resolver:

```bash
./scripts/dns-debug.sh example.com --resolver 1.1.1.1
```

Compare system resolver, Cloudflare, and Google:

```bash
./scripts/dns-debug.sh example.com --compare-resolvers
```

Example output:

```text
STATUS     TYPE     RESOLVER         QUERY_TIME
NOERROR    A        system           20 msec
example.com.        60      IN      A       93.184.216.34
AUTHORITY
example.com.        60      IN      NS      ns1.example.com.
```

Different DNS answers are not automatically a failure. CDN, geo-aware, round-robin, and cached DNS responses can legitimately differ.

### TLS Expiry

Check a certificate on port 443:

```bash
./scripts/tls-expiry-check.sh example.com
```

Check a custom port:

```bash
./scripts/tls-expiry-check.sh example.com:8443
```

Read targets from a file:

```bash
./scripts/tls-expiry-check.sh --file config/domains.example.txt
```

Set expiry thresholds:

```bash
./scripts/tls-expiry-check.sh example.com --warning-days 30 --critical-days 7
```

Example output:

```text
STATUS     HOST                   PORT   DAYS LEFT  EXPIRES
OK         example.com            443    86         Sep 21 00:00:00 2026 GMT
WARNING    internal.example       443    18         Jul 15 00:00:00 2026 GMT
CRITICAL   api.example            8443   4          Jul 01 00:00:00 2026 GMT
```

### System Pressure

Summarize host load, memory, swap, and Linux PSI pressure:

```bash
./scripts/system-pressure-report.sh
```

Use custom load thresholds. Load is evaluated as load average divided by CPU count:

```bash
./scripts/system-pressure-report.sh --warning-load 1.5 --critical-load 3.0
```

Optionally check recent kernel logs for OOM-kill patterns:

```bash
./scripts/system-pressure-report.sh --check-oom
```

Example output:

```text
STATUS     RESOURCE           VALUE        DETAILS
OK         load               0.25         0.50 load1 across 2 CPU(s)
WARNING    memory             90%          97 MiB available
OK         swap               0%           no swap configured
OK         cpu_pressure       0.00%        avg10 some pressure
OK         memory_pressure    0.00%        avg10 some pressure
OK         io_pressure        0.00%        avg10 some pressure
CRITICAL   oom_kills          seen         OOM pattern found in kernel logs
```

## Exit Codes

| Code | Meaning |
| --- | --- |
| `0` | Successful check, no detected problem |
| `1` | Warning condition detected |
| `2` | Critical condition or failed check |
| `3` | Invalid arguments or missing dependency |

When multiple resources are checked, the script returns the highest applicable exit code.

## Config Files

Example input files are included:

- `config/services.example.txt`
- `config/domains.example.txt`

Blank lines and comments are ignored.

## Safety

These scripts are diagnostic and read-only. They do not:

- delete files
- clean disks
- restart, stop, enable, or disable services
- change firewall rules
- kill processes
- score vulnerabilities
- call external APIs

Results should be interpreted in operational context. This toolkit does not replace monitoring, alerting, incident response tooling, or security scanners.

This software is provided without warranty. The authors and maintainers are not responsible for operational decisions, outages, data loss, security incidents, or other damage resulting from use or misuse of the toolkit.

## Test Locally

```bash
make validate
```

That runs formatting checks, ShellCheck, and the Bats test suite with mocked commands.

## Release

Update `VERSION`, commit the change, and tag the same version:

```bash
git tag v0.3.0
git push origin main v0.3.0
```

The release workflow validates the scripts, builds `dist/ops-diagnostics-toolkit_0.3.0_all.deb`, and uploads it to the GitHub Release for that tag.
