# DuckDNS Updater Makefile
CXX      := g++
CXXFLAGS := -O2 -Wall -Wextra -std=c++17
LDFLAGS  := -lcurl

TARGET   := duckdns-updater
SRC      := main.cpp

# Base version (can be overridden: make BASE_VERSION=2.0)
BASE_VERSION ?= 1.0

# Version from git
GIT_TAG     := $(shell git describe --tags 2>/dev/null)
GIT_COUNT   := $(shell git rev-list --count HEAD 2>/dev/null || echo "0")

# If we have a git tag, use it (with 'v' prefix removed)
# Otherwise, use base version + commit count as patch
ifeq ($(GIT_TAG),)
    # No tags - use base version with commit count as patch
    VERSION := $(BASE_VERSION).$(GIT_COUNT)
else
    # Has tags - use the tag (remove 'v' prefix if present)
    VERSION := $(subst v,,$(GIT_TAG))
endif

# Get Fedora version if available
FEDORA_VERSION := $(shell rpm --eval %fedora 2>/dev/null || echo "")

# Release number - just the distro tag
RELEASE := fc$(FEDORA_VERSION)

PREFIX   := /usr/local
BINDIR   := $(PREFIX)/bin
SYSTEMD  := /etc/systemd/system

SERVICE  := duckdns.service
SPEC     := duckdns-updater.spec

# RPM build directories
RPMDIR   := $(HOME)/rpmbuild
SOURCES  := $(RPMDIR)/SOURCES
SPECS    := $(RPMDIR)/SPECS

all: $(TARGET)

$(TARGET): $(SRC)
	$(CXX) $(CXXFLAGS) $(SRC) -o $(TARGET) $(LDFLAGS)

install: $(TARGET)
	install -Dm755 $(TARGET) $(BINDIR)/$(TARGET)
	install -Dm644 $(SERVICE) $(SYSTEMD)/$(SERVICE)
	install -Dm644 duckdns.conf /etc/duckdns.conf
	systemctl daemon-reload
	systemctl enable --now $(SERVICE)

uninstall:
	systemctl disable --now $(SERVICE) || true
	rm -f $(BINDIR)/$(TARGET)
	rm -f $(SYSTEMD)/$(SERVICE)
	rm -f /etc/duckdns.conf
	systemctl daemon-reload

clean:
	rm -f $(TARGET)

# RPM build targets
rpm-setup:
	@echo "Setting up RPM build environment..."
	@mkdir -p $(SOURCES) $(SPECS)
	@rpmdev-setuptree 2>/dev/null || true
	@echo "RPM build environment ready in $(RPMDIR)"

rpm-deps:
	@echo "Installing build dependencies..."
	@command -v dnf >/dev/null && sudo dnf install -y gcc-c++ libcurl-devel make rpm-build rpmdevtools || \
	command -v yum >/dev/null && sudo yum install -y gcc-c++ libcurl-devel make rpm-build rpmdevtools || \
	(echo "Neither dnf nor yum found. Please install build dependencies manually."; exit 1)

rpm-source: clean
	@echo "Creating source tarball..."
	@tar czf $(SOURCES)/$(TARGET)-$(VERSION).tar.gz \
	    --exclude=.git \
	    --exclude=*.o \
	    --exclude=$(RPMDIR) \
	    --transform='s,^,$(TARGET)-$(VERSION)/,' \
	    $(SRC) Makefile duckdns.conf $(SERVICE) $(SPEC)
	@echo "Source tarball created: $(SOURCES)/$(TARGET)-$(VERSION).tar.gz"

rpm-copy-spec:
	@mkdir -p $(SPECS)
	@cp $(SPEC) $(SPECS)/
	@echo "Spec file copied to $(SPECS)/"

rpm-build: rpm-setup rpm-source rpm-copy-spec
	@echo "Building RPM (Version: $(VERSION), Release: $(RELEASE))..."
	@cd $(SPECS) && rpmbuild -bb $(SPEC) \
		--define "_topdir $(RPMDIR)" \
		--define "version $(VERSION)" \
		--define "release $(RELEASE)"
	@echo "RPM build complete!"
	@echo "Binary RPM: $(RPMDIR)/RPMS/$$(uname -m)/$(TARGET)-$(VERSION)-$(RELEASE).x86_64.rpm"

rpm-full: rpm-setup rpm-source rpm-copy-spec
	@echo "Building source and binary RPMs (Version: $(VERSION), Release: $(RELEASE))..."
	@cd $(SPECS) && rpmbuild -ba $(SPEC) \
		--define "_topdir $(RPMDIR)" \
		--define "version $(VERSION)" \
		--define "release $(RELEASE)"
	@echo "RPM build complete!"

rpm-clean:
	@echo "Cleaning RPM build artifacts..."
	@rm -rf $(RPMDIR)
	@echo "RPM build directory cleaned"

version-info:
	@echo "Version Information:"
	@echo "===================="
	@echo "Base Version:   $(BASE_VERSION)"
	@echo "Git Tag:        $(if $(GIT_TAG),$(GIT_TAG),none)"
	@echo "Commit Count:   $(GIT_COUNT)"
	@echo ""
	@echo "RPM Version:    $(VERSION)"
	@echo "RPM Release:    $(RELEASE)"
	@echo "Full RPM:       $(TARGET)-$(VERSION)-$(RELEASE).x86_64.rpm"
	@echo ""
	@echo "Usage:"
	@echo "  Build RPM:             make rpm-build"
	@echo "  Custom base version:   make BASE_VERSION=2.0 rpm-build"
	@echo "  Tag release:           make git-tag TAG=v1.0"

git-tag:
	@if [ -z "$(TAG)" ]; then \
		echo "Usage: make git-tag TAG=v1.0.0"; \
		echo ""; \
		echo "Tag the current commit as a release version."; \
		echo "Version format should be v1.0.0 (v prefix is optional)"; \
		exit 1; \
	fi
	@echo "Creating git tag: $(TAG)"
	git tag -a $(TAG) -m "Release $(TAG)"
	@echo "Tag created. Next build will use: $(TAG)"
	@echo "Push to repository with: git push origin $(TAG)"

help:
	@echo "DuckDNS Updater - Build Targets"
	@echo "================================"
	@echo "all              - Build the binary"
	@echo "install          - Install binary, config, and systemd service"
	@echo "uninstall        - Remove installed files"
	@echo "clean            - Remove built binary"
	@echo ""
	@echo "Version Management:"
	@echo "==================="
	@echo "version-info     - Show current version info from git"
	@echo "git-tag TAG=v... - Tag current commit (e.g. make git-tag TAG=v1.0)"
	@echo ""
	@echo "RPM Build Targets (requires rpmbuild):"
	@echo "======================================="
	@echo "rpm-deps         - Install RPM build dependencies"
	@echo "rpm-setup        - Setup RPM build environment"
	@echo "rpm-source       - Create source tarball"
	@echo "rpm-build        - Build binary RPM only"
	@echo "rpm-full         - Build source and binary RPM"
	@echo "rpm-clean        - Clean RPM build artifacts"
	@echo ""
	@echo "Versioning Strategy:"
	@echo "==================="
	@echo "Without git tags:"
	@echo "  Version: Base + Commit Count (1.0.4)"
	@echo "  Release: Distro (fc43)"
	@echo "  Example: duckdns-updater-1.0.4.fc43.x86_64.rpm"
	@echo ""
	@echo "With git tags:"
	@echo "  Version: Git Tag (v1.0 becomes 1.0)"
	@echo "  Release: Distro (fc43)"
	@echo "  Example: duckdns-updater-1.0.fc43.x86_64.rpm"
	@echo ""
	@echo "Custom base version:"
	@echo "  make BASE_VERSION=2.0 rpm-build"
	@echo ""
	@echo "Quick start for RPM:"
	@echo "  make version-info      # Show current version"
	@echo "  make rpm-deps          # Install dependencies"
	@echo "  make rpm-build         # Build RPM (auto-version from git)"
	@echo "  make git-tag TAG=v1.0  # Tag a release"

.PHONY: all install uninstall clean help version-info git-tag rpm-setup rpm-deps rpm-source rpm-copy-spec rpm-build rpm-full rpm-clean
