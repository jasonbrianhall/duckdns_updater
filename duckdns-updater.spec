Name:           duckdns-updater
Version:        1.0.0
Release:        1%{?dist}
Summary:        DuckDNS IPv4/IPv6 Dynamic DNS Updater

License:        MIT
URL:            https://github.com/yourusername/duckdns-updater
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  gcc-c++
BuildRequires:  libcurl-devel
BuildRequires:  make

Requires:       libcurl
Requires:       systemd

# Disable debug package generation (not needed for this daemon)
%define debug_package %{nil}

%description
A lightweight C++ daemon that automatically updates your DuckDNS records
with your current IPv4 and/or IPv6 addresses. It monitors your connection
and updates DNS records when your IP changes.

%prep
%setup -q

%build
make %{?_smp_mflags}

%install
# Create necessary directories
install -d %{buildroot}/usr/local/bin
install -d %{buildroot}/etc
install -d %{buildroot}%{_unitdir}

# Install binary
install -Dm755 duckdns-updater %{buildroot}/usr/local/bin/duckdns-updater

# Install config file (marked as config so it won't be overwritten on upgrade)
install -Dm644 duckdns.conf %{buildroot}/etc/duckdns.conf

# Install systemd service file
install -Dm644 duckdns.service %{buildroot}%{_unitdir}/duckdns.service

%post
# Reload systemd daemon after installation
%systemd_post duckdns.service

%preun
# Stop and disable service before uninstall
%systemd_preun duckdns.service

%postun
# Reload systemd daemon after uninstall
%systemd_postun_with_restart duckdns.service

%clean
rm -rf %{buildroot}

%files
/usr/local/bin/duckdns-updater
%config(noreplace) /etc/duckdns.conf
%{_unitdir}/duckdns.service

%changelog
* Fri Jan 03 2025 Your Name <your.email@example.com> - 1.0.0-1
- Initial release

