# GLOBAL & MACROS
# ------------------------------------------------------------------------------
# Disable debug info generation (Fix for Fedora/RHEL)
%global debug_package %{nil}
%global _debugsource_template %{nil}
%undefine _debugsource_packages
%undefine _debuginfo_packages
# Disable automatic post-install scripts
%global __os_install_post %{nil}

# Standard path definitions
%define install_dir /opt/hyphanet
%define data_dir    /var/lib/hyphanet
%define log_dir     /var/log/hyphanet
%define user_name   hyphanet

# Default values if not provided by rpmbuild command line
%{!?version: %define version 0.7.5}
%{!?build_id: %define build_id 1505}

Name:           hyphanet
Version:        %{version}
Release:        %{build_id}.1
Summary:        Anonymizing peer-to-peer network (Hyphanet/Freenet)

License:        GPLv2+
URL:            https://www.hyphanet.org
# Source filename must match what prepare_sources.sh generates
Source0:        hyphanet-%{version}-%{build_id}.tar.gz

BuildArch:      x86_64

# Dependencies
Requires:       (java-headless >= 1.8.0 or java >= 1.8.0)
Requires:       systemd
Requires:       polkit
Requires(pre):  systemd

%description
Hyphanet (formerly Freenet) is a peer-to-peer platform for censorship-resistant
communication.

%prep
%setup -q

%build
# Nothing to compile (Binaries provided in tarball)

%install
# --- 1. Directory Structure ---
install -d -m 755 %{buildroot}%{install_dir}
install -d -m 755 %{buildroot}%{install_dir}/lib
install -d -m 755 %{buildroot}%{_unitdir}
install -d -m 750 %{buildroot}%{data_dir}
install -d -m 750 %{buildroot}%{log_dir}
install -d -m 755 %{buildroot}%{_prefix}/lib/sysusers.d
install -d -m 755 %{buildroot}%{_bindir}
install -d -m 755 %{buildroot}%{_datadir}/applications
install -d -m 755 %{buildroot}%{_datadir}/pixmaps
install -d -m 755 %{buildroot}%{_datadir}/polkit-1/actions
install -d -m 755 %{buildroot}%{_datadir}/metainfo

# --- 2. Copy Files from Tarball ---
install -m 644 ./freenet.jar %{buildroot}%{install_dir}/
install -m 644 ./seednodes.fref %{buildroot}%{install_dir}/
install -m 644 ./wrapper.conf %{buildroot}%{install_dir}/
install -m 644 ./freenet.ini %{buildroot}%{install_dir}/
install -m 644 ./lib/*.jar %{buildroot}%{install_dir}/lib/
# Binaries/Scripts must be executable (755)
install -m 755 ./lib/libwrapper.so %{buildroot}%{install_dir}/lib/
install -m 755 ./hyphanet-wrapper %{buildroot}%{install_dir}/
install -m 755 ./hyphanet-service %{buildroot}%{install_dir}/

# Install systemd unit and sysusers file
install -m 644 ./hyphanet.service %{buildroot}%{_unitdir}/hyphanet.service
install -m 644 ./hyphanet.sysusers %{buildroot}%{_prefix}/lib/sysusers.d/hyphanet.conf

# Install desktop file and icon file
install -m 644 ./hyphanet.desktop %{buildroot}%{_datadir}/applications/hyphanet.desktop
install -m 644 ./hyphanet-start.desktop %{buildroot}%{_datadir}/applications/hyphanet-start.desktop
install -m 644 ./hyphanet-stop.desktop %{buildroot}%{_datadir}/applications/hyphanet-stop.desktop
install -m 644 ./hyphanet.png %{buildroot}%{_datadir}/pixmaps/hyphanet.png

# Install PolicyKit policy
install -m 644 ./org.hyphanet.service.policy %{buildroot}%{_datadir}/polkit-1/actions/org.hyphanet.service.policy

# Install AppStream metadata
install -m 644 ./org.hyphanet.hyphanet.metainfo.xml %{buildroot}%{_datadir}/metainfo/org.hyphanet.hyphanet.metainfo.xml

# --- 3. Symlink (CLI) ---
# Creates a symbolic link /usr/bin/hyphanet pointing to /opt/hyphanet/hyphanet-service
ln -sf %{install_dir}/hyphanet-service %{buildroot}%{_bindir}/hyphanet

%pre
# Managed by sysusers

%post
# 1. Apply user configuration
%sysusers_create_compat %{_prefix}/lib/sysusers.d/hyphanet.conf

# 2. Permissions
chown -R %{user_name}:%{user_name} %{data_dir}
chown -R %{user_name}:%{user_name} %{log_dir}

# 3. Initialize Configuration (Copy only if missing)
# -- seednodes.fref --
if [ ! -f "%{data_dir}/seednodes.fref" ]; then
    cp "%{install_dir}/seednodes.fref" "%{data_dir}/"
    chown %{user_name}:%{user_name} "%{data_dir}/seednodes.fref"
    chmod 600 "%{data_dir}/seednodes.fref"
fi

# -- wrapper.conf --
if [ ! -f "%{data_dir}/wrapper.conf" ]; then
    cp "%{install_dir}/wrapper.conf" "%{data_dir}/"
    chown %{user_name}:%{user_name} "%{data_dir}/wrapper.conf"
    chmod 600 "%{data_dir}/wrapper.conf"
fi

# -- freenet.ini --
if [ ! -f "%{data_dir}/freenet.ini" ]; then
    cp "%{install_dir}/freenet.ini" "%{data_dir}/"
    chown %{user_name}:%{user_name} "%{data_dir}/freenet.ini"
    chmod 600 "%{data_dir}/freenet.ini"
fi

# 4. Runtime Dirs
mkdir -p %{data_dir}/temp %{data_dir}/logs
chown -R %{user_name}:%{user_name} %{data_dir}/temp %{data_dir}/logs

# 5. Service Activation & Auto-start
%systemd_post hyphanet.service

# If fresh install (1), enable and start immediately
if [ $1 -eq 1 ]; then
    /usr/bin/systemctl enable --now hyphanet.service >/dev/null 2>&1 || :
fi

%preun
%systemd_preun hyphanet.service

%postun
%systemd_postun_with_restart hyphanet.service

%files
%defattr(-,root,root,-)
# Main Dir (Recursive)
%{install_dir}

# System Files
%{_unitdir}/hyphanet.service
%{_prefix}/lib/sysusers.d/hyphanet.conf
%{_bindir}/hyphanet
%{_datadir}/applications/hyphanet.desktop
%{_datadir}/applications/hyphanet-start.desktop
%{_datadir}/applications/hyphanet-stop.desktop
%{_datadir}/pixmaps/hyphanet.png
%{_datadir}/polkit-1/actions/org.hyphanet.service.policy
%{_datadir}/metainfo/org.hyphanet.hyphanet.metainfo.xml

# Data Dirs
%dir %{data_dir}
%dir %{log_dir}

# Ghost Files
%ghost %{data_dir}/freenet.ini
%ghost %{data_dir}/wrapper.conf
%ghost %{data_dir}/seednodes.fref

%changelog
* Wed Feb 11 2026 Ton Nom <hernic@gmail.com> - 0.7.5-1505.1
- Initial build of the package