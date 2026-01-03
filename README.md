# 🦆 DuckDNS Updater

A lightweight, high-performance C++ daemon that automatically updates your [DuckDNS](https://www.duckdns.org/) records with your current IPv4 and/or IPv6 addresses. Perfect for keeping your dynamic DNS entries current without any manual intervention.

## ✨ Features

- **Dual-stack Support**: Seamlessly handle both IPv4 and IPv6 addresses
- **Smart Updates**: Only updates DNS records when IP addresses actually change (efficient!)
- **Configurable Intervals**: Set custom update intervals (minimum 60 seconds)
- **Systemd Integration**: Runs as a daemon with automatic restart on failure
- **Minimal Dependencies**: Only requires libcurl and standard C++ libraries
- **Syslog Integration**: All events logged to system logger for monitoring
- **CGNAT Friendly**: Especially useful for IPv6-only or CGNAT environments
- **Low Resource Usage**: Lightweight C++ implementation perfect for embedded systems
- **RPM Packaging**: Ready-to-install Fedora/RHEL packages with automated versioning

## 🚀 Quick Start

### Installation from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/duckdns-updater.git
cd duckdns-updater

# Install build dependencies
make rpm-deps  # For Fedora/RHEL systems

# Build the binary
make

# Install (requires root)
sudo make install

# Start the service
sudo systemctl start duckdns.service
```

### Installation from RPM

```bash
# Install build dependencies
make rpm-deps

# Build RPM package
make rpm-build

# Install the generated RPM
sudo dnf install ~/rpmbuild/RPMS/x86_64/duckdns-updater-*.rpm

# Start the service
sudo systemctl start duckdns.service
```

## ⚙️ Configuration

Edit `/etc/duckdns.conf` to configure the updater:

```ini
# Your DuckDNS domain (without .duckdns.org suffix)
domain=yourdomain

# Your DuckDNS authentication token
token=your-secret-token-here

# Update interval in seconds (minimum: 60)
interval=600

# Endpoint for IPv6 detection (required)
ipv6_endpoint=https://api6.ipify.org

# Endpoint for IPv4 detection (optional, comment out to disable)
# ipv4_endpoint=https://api.ipify.org
```

### Configuration Options

| Option | Required | Description |
|--------|----------|-------------|
| `domain` | Yes | Your DuckDNS domain name (without `.duckdns.org`) |
| `token` | Yes | Your DuckDNS authentication token from account settings |
| `ipv6_endpoint` | Yes | URL endpoint that returns your current IPv6 address |
| `ipv4_endpoint` | No | URL endpoint that returns your current IPv4 address. Omit if IPv4 updates aren't needed |
| `interval` | No | Seconds between update checks (default: 600, minimum: 60) |

### Getting Your DuckDNS Token

1. Visit [duckdns.org](https://www.duckdns.org/)
2. Sign in with your account
3. Your token is displayed at the top of the dashboard
4. Copy it to the configuration file

## 📋 Requirements

### Runtime
- **OS**: Linux (tested on Fedora, RHEL, CentOS, Debian, Ubuntu)
- **Libraries**: libcurl
- **Systemd**: For daemon management

### Build
- **Compiler**: GCC 7.0+ or Clang 5.0+ (C++17 support required)
- **Build Tools**: make, g++
- **Development Libraries**: libcurl-devel

### Install Dependencies

**Fedora/RHEL:**
```bash
sudo dnf install libcurl libcurl-devel gcc-c++ make
```

**Debian/Ubuntu:**
```bash
sudo apt-get install libcurl4 libcurl4-openssl-dev build-essential
```

## 🎯 Usage

### Check Service Status

```bash
# View current status
sudo systemctl status duckdns.service

# View logs
sudo journalctl -u duckdns.service -f

# View with detailed timestamps
sudo journalctl -u duckdns.service --since "1 hour ago" -n 50
```

### Manual Control

```bash
# Start the service
sudo systemctl start duckdns.service

# Stop the service
sudo systemctl stop duckdns.service

# Restart the service
sudo systemctl restart duckdns.service

# Enable auto-start on boot
sudo systemctl enable duckdns.service

# Disable auto-start on boot
sudo systemctl disable duckdns.service
```

### Check Logs

The updater logs all activity to syslog. View logs with:

```bash
# Recent logs
sudo journalctl -u duckdns.service -n 20

# Continuous log stream
sudo journalctl -u duckdns.service -f

# Log entries from specific time
sudo journalctl -u duckdns.service --since "2 hours ago"

# Filter by priority (errors only)
sudo journalctl -u duckdns.service -p err
```

## 🔧 Building

### Standard Build

```bash
# Build the binary
make

# Clean build artifacts
make clean

# Show help
make help
```

### Version Management

The Makefile automatically manages versioning from git tags:

```bash
# View current version info
make version-info

# Tag a release
make git-tag TAG=v1.0.0

# Build with custom base version
make BASE_VERSION=2.0 rpm-build
```

### RPM Building

```bash
# Install build dependencies (first time only)
make rpm-deps

# Display version information
make version-info

# Build binary RPM only
make rpm-build

# Build source and binary RPMs
make rpm-full

# Clean RPM build artifacts
make rpm-clean
```

## 🧪 Use Cases

### CGNAT Environments
If you're behind Carrier-Grade NAT and only have IPv6 connectivity, simply configure IPv6 updates and leave IPv4 disabled:

```ini
domain=myhost
token=abc123
ipv6_endpoint=https://api6.ipify.org
# ipv4_endpoint disabled
interval=600
```

### Dual-Stack Networks
For full IPv4 and IPv6 support:

```ini
domain=myhost
token=abc123
ipv6_endpoint=https://api6.ipify.org
ipv4_endpoint=https://api.ipify.org
interval=600
```

### Frequent Updates
For networks with frequent IP changes:

```ini
domain=myhost
token=abc123
ipv6_endpoint=https://api6.ipify.org
interval=120  # Check every 2 minutes
```

## 📝 Log Examples

### Successful Update
```
Jan 03 12:34:56 hostname duckdns-updater[1234]: DuckDNS update: ipv6_changed=1 ipv4_changed=0 result=OK
```

### No Update Needed
```
Jan 03 12:34:56 hostname duckdns-updater[1234]: No update needed (IPv6=2001:db8::1 IPv4=disabled)
```

### Configuration Error
```
Jan 03 12:34:56 hostname duckdns-updater[1234]: Could not open /etc/duckdns.conf
```

## 🏗️ Project Structure

```
.
├── main.cpp                 # Main application source
├── Makefile                 # Build configuration
├── duckdns.conf            # Configuration template
├── duckdns.service         # Systemd service file
├── duckdns-updater.spec    # RPM spec file
└── README.md               # This file
```

## 📦 Installation Paths

When installed, the following files are placed:

- **Binary**: `/usr/local/bin/duckdns-updater`
- **Config**: `/etc/duckdns.conf`
- **Service**: `/etc/systemd/system/duckdns.service`

## 🗑️ Uninstallation

To completely remove the updater:

```bash
sudo make uninstall
```

This will:
- Disable and stop the systemd service
- Remove the binary
- Remove the service file
- Remove the configuration file
- Reload systemd daemon

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests to improve the project.

## 📜 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- [DuckDNS](https://www.duckdns.org/) - Free DDNS service
- [ipify](https://www.ipify.org/) - IP detection service
- libcurl community for the excellent HTTP library

## ⚠️ Security Notes

- Keep your DuckDNS token confidential - it's stored in `/etc/duckdns.conf`
- Ensure proper file permissions: `sudo chmod 600 /etc/duckdns.conf`
- Review logs regularly for failed authentication attempts
- Use HTTPS endpoints for IP detection when possible

## 📞 Support

For issues, questions, or suggestions:

1. Review logs with `sudo journalctl -u duckdns.service` if running as a daemon
2. Check that DuckDNS API is accessible: `curl https://www.duckdns.org/update?domains=test&token=test`
3. Run from the command line and view interactive logs

---

Made with ❤️ for the open-source community
