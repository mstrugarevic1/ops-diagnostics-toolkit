# Ops Diagnostics Toolkit

Small, read-only Bash diagnostics for Linux operations interviews and day-to-day checks.

| Script | Purpose |
| --- | --- |
| `disk-usage-alert.sh` | Filesystem capacity checks |
| `service-health-report.sh` | systemd service diagnostics |
| `port-listener-audit.sh` | Listening socket inventory |
| `dns-debug.sh` | DNS resolution diagnostics |
| `tls-expiry-check.sh` | TLS certificate validation |

## Supported Platform

Primary target: Linux with Bash 4.2 or newer, especially Ubuntu and Debian-like systems. Some scripts may work elsewhere when the required commands exist, but macOS compatibility is not claimed.

## Requirements

Runtime commands by script:

| Script | Commands |
| --- | --- |
| `disk-usage-alert.sh` | `df` |
| `service-health-report.sh` | `systemctl`, optional `journalctl` |
| `port-listener-audit.sh` | `ss` or `netstat` |
| `dns-debug.sh` | `dig` |
| `tls-expiry-check.sh` | `openssl`, `timeout`, GNU `date` |

Development commands: `shellcheck`, `shfmt`, and `bats`.

## Repository Structure

```text
ops-diagnostics-toolkit/
├── scripts/
├── config/
├── tests/
└── .github/workflows/
```

## Installation

Clone the repository and run scripts directly:

```bash
chmod +x scripts/*.sh
./scripts/disk-usage-alert.sh --help
```

`make install-dev` prints the required development tools. It does not install packages automatically.

## Examples

```bash
./scripts/disk-usage-alert.sh --warning 75 --critical 90
./scripts/disk-usage-alert.sh --filesystem /

./scripts/service-health-report.sh nginx docker ssh
./scripts/service-health-report.sh --file config/services.example.txt
./scripts/service-health-report.sh --failed-only
./scripts/service-health-report.sh nginx --logs 5

./scripts/port-listener-audit.sh
./scripts/port-listener-audit.sh --tcp --processes
./scripts/port-listener-audit.sh --port 443

./scripts/dns-debug.sh example.com
./scripts/dns-debug.sh example.com --type A
./scripts/dns-debug.sh example.com --compare-resolvers

./scripts/tls-expiry-check.sh example.com
./scripts/tls-expiry-check.sh example.com:8443
./scripts/tls-expiry-check.sh --file config/domains.example.txt --warning-days 30
```

## Exit Codes

| Code | Meaning |
| --- | --- |
| 0 | Successful check, no detected problem |
| 1 | Warning condition detected |
| 2 | Critical condition or failed check |
| 3 | Invalid arguments or missing dependency |

## Output Examples

```text
STATUS     FILESYSTEM              MOUNT              USED     AVAILABLE
OK         /dev/root               /                  42%      58G
WARNING    /dev/data               /var               83%      9G
```

```text
PROTOCOL   ADDRESS            PORT    PID      PROCESS        BINDING
tcp        127.0.0.1          5432    111      postgres       LOOPBACK
tcp        0.0.0.0            22      222      sshd           ALL_INTERFACES
```

## Testing

Tests use Bats and mocked commands from `tests/fixtures/bin`; they do not require root, internet access, real services, DNS, or TLS endpoints.

```bash
make format
make lint
make test
make validate
```

## CI

GitHub Actions runs on pushes to `main` and pull requests. The workflow installs ShellCheck, shfmt, and Bats, then runs `make validate`. It does not require secrets or live network diagnostics.

## Limitations

These scripts are diagnostic and read-only. Results must be interpreted in operational context.

An all-interface listener is not proof of public internet exposure. Different DNS answers are not automatically evidence of failure because CDN, geo-aware, round-robin, and cached responses can differ. These scripts do not replace monitoring, incident response tooling, or security scanners.

## Security And Safety

The toolkit does not modify firewall rules, restart services, delete files, clean disks, score vulnerabilities, or call external APIs. It avoids automatic remediation by design.
