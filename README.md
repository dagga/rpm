# Hyphanet RPM Packaging

This repository contains the source files and scripts required to build an **RPM** (Red Hat Package Manager) package for **Hyphanet** (formerly Freenet).

## Prerequisites
```bash
sudo dnf install rpm-build rpmdevtools wget
rpmdev-setuptree
chmod +x prepare_sources.sh
```

## Build
```bash
prepare_sources.sh
rpmbuild -ba SPECS/hyphanet.spec
```

## Install / Uninstall 
```bash
sudo dnf install RPMS/x86_64/hyphanet-0.7.1505-1.x86_64.rpm
sudo dnf remove hyphanet
```

## Usage:
```bash
sudo systemctl start hyphanet
sudo systemctl stop hyphanet
sudo systemctl status hyphanet
sudo systemctl enable hyphanet
```
/!\ enable=enable at boot /!\
