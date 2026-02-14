# ------------------------------------------------------------------------------
# GLOBAL & MACROS
# ------------------------------------------------------------------------------
# Disable debug info generation (Fix for Fedora 43 / RHEL 9+)
# Prevents RPM from trying to strip binaries or look for C/C++ debug sources
# which causes build failures for Java/Binary-only packages.
%global debug_package %{nil}
%global _debugsource_template %{nil}
%undefine _debugsource_packages
%undefine _debuginfo_packages
# Disable automatic post-install scripts (like manpage compression) that might interfere
%global __os_install_post %{nil}

# Standard path definitions
%define install_dir /opt/hyphanet
%define data_dir    /var/lib/hyphanet
%define log_dir     /var/log/hyphanet
%define user_name   hyphanet

Name:           hyphanet
Version:        0.7.1505
Release:        1%{?dist}
Summary:        Anonymizing peer-to-peer network (Hyphanet/Freenet)

License:        GPLv2+
URL:            https://www.hyphanet.org
Source0:        hyphanet-%{version}.tar.gz

BuildArch:      x86_64

# Dependencies: Supports any Java 8+ environment (Server/Headless or Desktop)
Requires:       (java-headless >= 1.8.0 or java >= 1.8.0)
Requires:       systemd
# Required for modern user management (replaces useradd)
Requires(pre):  systemd

%description
Hyphanet (formerly Freenet) is a peer-to-peer platform for censorship-resistant
communication.

After installation:
1. The service starts automatically.
2. Go to http://127.0.0.1:8888/ to finalize the configuration.
3. Configuration files are located in %{data_dir}.

%prep
# Extract archive and enter the directory
%setup -q -n fred-build01505

%build
# Binaries are pre-compiled (JAR + Wrapper). Nothing to compile here.

%install
# --- 1. Directory Structure ---
# Create directories with correct permissions
install -d -m 755 %{buildroot}%{install_dir}
install -d -m 755 %{buildroot}%{install_dir}/lib
install -d -m 755 %{buildroot}%{_unitdir}
install -d -m 750 %{buildroot}%{data_dir}
install -d -m 750 %{buildroot}%{log_dir}
# Create sysusers.d directory for system user declaration
install -d -m 755 %{buildroot}%{_prefix}/lib/sysusers.d
# Create bin directory for the symlink
install -d -m 755 %{buildroot}%{_bindir}

# --- 2. Copy Core Files (Templates) ---
# These files serve as "templates" in /opt to be copied to /var/lib later
install -m 644 ./freenet.jar %{buildroot}%{install_dir}/
install -m 644 ./seednodes.fref %{buildroot}%{install_dir}/
install -m 644 ./wrapper.conf %{buildroot}%{install_dir}/
install -m 644 ./freenet.ini %{buildroot}%{install_dir}/

# --- 3. Copy Libraries ---
install -m 644 ./lib/*.jar %{buildroot}%{install_dir}/lib/
install -m 755 ./lib/libwrapper.so %{buildroot}%{install_dir}/lib/

# ---