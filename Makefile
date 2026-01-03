# DuckDNS Updater Makefile
CXX      := g++
CXXFLAGS := -O2 -Wall -Wextra -std=c++17
LDFLAGS  := -lcurl

TARGET   := duckdns-updater
SRC      := main.cpp

PREFIX   := /usr/local
BINDIR   := $(PREFIX)/bin
SYSTEMD  := /etc/systemd/system

SERVICE  := duckdns.service

all: $(TARGET)

$(TARGET): $(SRC)
	$(CXX) $(CXXFLAGS) $(SRC) -o $(TARGET) $(LDFLAGS)

install: $(TARGET)
	install -Dm755 $(TARGET) $(BINDIR)/$(TARGET)
	install -Dm644 $(SERVICE) $(SYSTEMD)/$(SERVICE)
	systemctl daemon-reload
	systemctl enable --now $(SERVICE)

uninstall:
	systemctl disable --now $(SERVICE) || true
	rm -f $(BINDIR)/$(TARGET)
	rm -f $(SYSTEMD)/$(SERVICE)
	systemctl daemon-reload

clean:
	rm -f $(TARGET)

.PHONY: all install uninstall clean

