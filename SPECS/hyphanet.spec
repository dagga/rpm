# DISABLE DEBUG (Fix for Fedora 43 / RHEL 9+)
# Prevents RPM from trying to strip binaries or look for C debug sources
#TODO : do better
%global debug_package %{nil}
%global _debugsource_template %{nil}
%undefine _debugsource_packages
%undefine _debuginfo_packages
%global __os_install_post %{nil}

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
Requires:       (java-headless >= 1.8.0 or java >= 1.8.0)
Requires:       systemd
Requires(pre):  shadow-utils

%description
Hyphanet (formerly Freenet) is a peer-to-peer platform for censorship-resistant
communication. It uses a decentralized distributed data store to keep and
deliver information.

After installing the rpm, you must visit: http://localhost:8888/
and answer some questions there before it will begin trying to connect to
the network.

%prep
# Extract archive and enter directory
%setup -q -n fred-build01505

%build
# Binaries are pre-compiled (Jar + Wrapper)

%install
# 1. Create Directories
install -d -m 755 %{buildroot}%{install_dir}
install -d -m 755 %{buildroot}%{install_dir}/lib
install -d -m 755 %{buildroot}%{_unitdir}
install -d -m 750 %{buildroot}%{data_dir}
install -d -m 750 %{buildroot}%{log_dir}

# 2. Copy Root Files
install -m 644 ./freenet.jar %{buildroot}%{install_dir}/
install -m 644 ./seednodes.fref %{buildroot}%{install_dir}/
install -m 644 ./wrapper.conf %{buildroot}%{install_dir}/
install -m 644 ./freenet.ini %{buildroot}%{install_dir}/

# 3. Copy Libraries
install -m 644 ./lib/*.jar %{buildroot}%{install_dir}/lib/
install -m 755 ./lib/libwrapper.so %{buildroot}%{install_dir}/lib/

# 4. Copy Binaries/Scripts
install -m 755 ./hyphanet-wrapper %{buildroot}%{install_dir}/
install -m 755 ./hyphanet-service %{buildroot}%{install_dir}/

# 5. Create Systemd Service File
cat <<EOF > %{buildroot}%{_unitdir}/hyphanet.service
[Unit]
Description=Hyphanet Node
After=network.target syslog.target

[Service]
Type=forking
User=%{user_name}
Group=%{user_name}
# The wrapper automatically switches working directory to /var/lib/hyphanet
ExecStart=%{install_dir}/hyphanet-service start
Restart=on-failure
PIDFile=%{data_dir}/hyphanet.pid

[Install]
WantedBy=multi-user.target
EOF

%pre
# Create system user if it doesn't exist
getent group %{user_name} >/dev/null || groupadd -r %{user_name}
getent passwd %{user_name} >/dev/null || \
    useradd -r -g %{user_name} -d %{data_dir} -s /sbin/nologin \
    -c "Hyphanet Daemon User" %{user_name}
exit 0

%post
# 1. Permission Management
# RPM installs as root for security. We transfer ownership of data dirs here.
chown -R %{user_name}:%{user_name} %{data_dir}
chown -R %{user_name}:%{user_name} %{log_dir}
chmod 750 %{data_dir}
chmod 750 %{log_dir}

# 2. Create Runtime Directories
mkdir -p %{data_dir}/temp
mkdir -p %{data_dir}/logs
chown -R %{user_name}:%{user_name} %{data_dir}/temp
chown -R %{user_name}:%{user_name} %{data_dir}/logs

# 3. Initialize Configuration (Only if missing)
# This allows users to modify config in /var/lib without RPM updates overwriting it.
for file in seednodes.fref wrapper.conf freenet.ini; do
    if [ ! -f %{data_dir}/$file ]; then
        cp %{install_dir}/$file %{data_dir}/
        chown %{user_name}:%{user_name} %{data_dir}/$file
        chmod 600 %{data_dir}/$file
    fi
done

# 4. Register Service
%systemd_post hyphanet.service

%preun
%systemd_preun hyphanet.service

%postun
%systemd_postun_with_restart hyphanet.service

%files
%defattr(-,root,root,-)
# /opt/hyphanet content (Static, read-only for security)
%dir %{install_dir}
%{install_dir}/*

# Systemd Unit
%{_unitdir}/hyphanet.service

# Data Directories (Ownership managed in %post)
%dir %{data_dir}
%dir %{log_dir}

%changelog