# ------------------------------------------------------------------------------
# GLOBAL & MACROS
# ------------------------------------------------------------------------------
# Disable debug info generation (Fix for Fedora 43 / RHEL 9+) TOD: not sure
%global debug_package %{nil}
%global _debugsource_template %{nil}
%undefine _debugsource_packages
%undefine _debuginfo_packages
# Disable automatic post-install scripts (like manpage compression)
%global __os_install_post %{nil}

# Standard path definitions
%define install_dir /opt/hyphanet
%define data_dir    /var/lib/hyphanet
%define log_dir     /var/log/hyphanet
%define user_name   hyphanet

Name:           hyphanet
Version:        0.7.1505
Release:        0.1_rhel9
Summary:        Anonymizing peer-to-peer network (Hyphanet/Freenet)

License:        GPLv2+
URL:            https://www.hyphanet.org
Source0:        hyphanet-%{version}.tar.gz

BuildArch:      x86_64

# Dependencies: Supports any Java 8+ environment (Server/Headless or Desktop)
Requires:       (java-headless >= 1.8.0 or java >= 1.8.0)
Requires:       systemd
Requires(pre):  systemd

%description
Hyphanet (formerly Freenet) is a peer-to-peer platform for censorship-resistant
communication.

After installation:
1. The service starts automatically.
2. Go to http://127.0.0.1:8888/ to finalize the configuration.
3. Configuration files are located in %{data_dir}.

%prep
%setup -q -n fred-build01505

%build
# Binaries are pre-compiled. Nothing to compile.

%install
# --- 1. Directory Structure ---
install -d -m 755 %{buildroot}%{install_dir}
install -d -m 755 %{buildroot}%{install_dir}/lib
install -d -m 755 %{buildroot}%{_unitdir}
install -d -m 750 %{buildroot}%{data_dir}
install -d -m 750 %{buildroot}%{log_dir}
install -d -m 755 %{buildroot}%{_prefix}/lib/sysusers.d
install -d -m 755 %{buildroot}%{_bindir}

# --- 2. Copy Core Files (Templates) ---
install -m 644 ./freenet.jar %{buildroot}%{install_dir}/
install -m 644 ./seednodes.fref %{buildroot}%{install_dir}/
install -m 644 ./wrapper.conf %{buildroot}%{install_dir}/
install -m 644 ./freenet.ini %{buildroot}%{install_dir}/

# --- 3. Copy Libraries ---
install -m 644 ./lib/*.jar %{buildroot}%{install_dir}/lib/
install -m 755 ./lib/libwrapper.so %{buildroot}%{install_dir}/lib/

# --- 4. Binaries & Scripts ---
install -m 755 ./hyphanet-wrapper %{buildroot}%{install_dir}/
install -m 755 ./hyphanet-service %{buildroot}%{install_dir}/

# Symlink for CLI usage
ln -s %{install_dir}/hyphanet-service %{buildroot}%{_bindir}/hyphanet

# FIX: Point service script to the editable config in /var/lib
sed -i "s|CONF_FILE=\"%{install_dir}/wrapper.conf\"|CONF_FILE=\"%{data_dir}/wrapper.conf\"|" \
    %{buildroot}%{install_dir}/hyphanet-service

# --- 5. Systemd Unit (Hardened) ---
cat <<EOF > %{buildroot}%{_unitdir}/hyphanet.service
[Unit]
Description=Hyphanet Node
After=network.target syslog.target

[Service]
Type=forking
User=%{user_name}
Group=%{user_name}
ExecStart=%{install_dir}/hyphanet-service start
Restart=on-failure
PIDFile=%{data_dir}/hyphanet.pid
ProtectHome=true
ProtectSystem=full
PrivateTmp=true
NoNewPrivileges=true
PrivateDevices=true

[Install]
WantedBy=multi-user.target
EOF

# --- 6. User Declaration (sysusers.d) ---
cat <<EOF > %{buildroot}%{_prefix}/lib/sysusers.d/hyphanet.conf
u %{user_name} - "Hyphanet Daemon User" %{data_dir} /sbin/nologin
EOF

%pre
# Managed by sysusers

%post
# 1. Apply user configuration
%sysusers_create_compat %{_prefix}/lib/sysusers.d/hyphanet.conf

# 2. Set ownership for data directories
chown -R %{user_name}:%{user_name} %{data_dir}
chown -R %{user_name}:%{user_name} %{log_dir}

# 3. Initialize Configuration (Explicit Logic - No Loops)
# Copy templates from /opt to /var/lib only if missing.

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

# 4. Create Runtime Directories
mkdir -p %{data_dir}/temp %{data_dir}/logs
chown -R %{user_name}:%{user_name} %{data_dir}/temp %{data_dir}/logs

%systemd_post hyphanet.service

%preun
%systemd_preun hyphanet.service

%postun
%systemd_postun_with_restart hyphanet.service

# ------------------------------------------------------------------------------
# FILES SECTION (Recursive Inclusion)
# ------------------------------------------------------------------------------
%files
%defattr(-,root,root,-)

# 1. Main Directory (Recursive)
# TODO : list the files and remove the "Leaving off %dir tells RPM to include the directory AND all contents. effect"
# This fixes "Installed but unpackaged files" errors.
%{install_dir}

# 2. System Configuration
%{_unitdir}/hyphanet.service
%{_prefix}/lib/sysusers.d/hyphanet.conf
%{_bindir}/hyphanet

# 3. Data Directories (Empty or owned by user)
%dir %{data_dir}
%dir %{log_dir}

# 4. Ghost Files (Managed by %post script)
%ghost %{data_dir}/freenet.ini
%ghost %{data_dir}/wrapper.conf
%ghost %{data_dir}/seednodes.fref

%changelog
* Sat Feb 14 2026 - 0.7.1505-1
- Initial release
- Explicit configuration handling (Linear logic)
- Recursive file inclusion in %files