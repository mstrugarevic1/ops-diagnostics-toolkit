# Ops Diagnostics Toolkit

Small, read-only Bash scripts for Linux system and network diagnostics.

| Script | Purpose |
| --- | --- |
| `disk-usage-alert.sh` | Filesystem capacity checks |
| `service-health-report.sh` | systemd service diagnostics |
| `port-listener-audit.sh` | Listening socket inventory |
| `dns-debug.sh` | DNS resolution diagnostics |
| `tls-expiry-check.sh` | TLS certificate expiry checks |

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

Package names differ by distribution. On Debian/Ubuntu, `dig` is usually in `dnsutils`; on Red Hat-like systems it is usually in `bind-utils`.

## Install

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

Example output:

```text
STATUS     FILESYSTEM              MOUNT              USED     AVAILABLE
OK         /dev/root               /                  42%      58G
WARNING    /dev/data               /var               83%      9G
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

Example output:

```text
PROTOCOL   ADDRESS            PORT    PID      PROCESS        BINDING
tcp        127.0.0.1          5432    111      postgres       LOOPBACK
tcp        0.0.0.0            22      222      sshd           ALL_INTERFACES
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

## Test Locally

```bash
make validate
```

That runs formatting checks, ShellCheck, and the Bats test suite with mocked commands.
