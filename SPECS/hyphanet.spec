%global debug_package %{nil}
%global _debugsource_template %{nil}
%undefine _debugsource_packages
%undefine _debuginfo_packages
%global __os_install_post %{nil}

# Définitions globales
%define install_dir /opt/hyphanet
%define data_dir    /var/lib/hyphanet
%define log_dir     /var/log/hyphanet
%define user_name   hyphanet

Name:           hyphanet
Version:        0.7.1505
Release:        1%{?dist}
Summary:        Réseau peer-to-peer anonyme (Hyphanet/Freenet)

License:        GPLv2+
URL:            https://www.hyphanet.org
Source0:        hyphanet-%{version}.tar.gz

BuildArch:      x86_64
# Java 11 minimum requis pour Hyphanet moderne
Requires:       java-headless >= 11
Requires:       shadow-utils
Requires:       systemd

%description
Hyphanet (anciennement Freenet) est une plateforme peer-to-peer conçue pour
résister à la censure. Elle utilise un stockage de données distribué et
décentralisé pour diffuser l'information sans autorité centrale.

%prep
# Le dossier dans l'archive générée par prepare_sources.sh est fred-build01505
%setup -q -n fred-build01505

%build
# Les composants sont pré-compilés (JARs et binaires Wrapper)

%install
# 1. Création de l'arborescence
install -d -m 755 %{buildroot}%{install_dir}
install -d -m 755 %{buildroot}%{install_dir}/lib
install -d -m 750 %{buildroot}%{data_dir}
install -d -m 750 %{buildroot}%{log_dir}
install -d -m 755 %{buildroot}%{_unitdir}

# 2. Installation des fichiers Core (depuis fred-build01505)
install -m 644 freenet.jar %{buildroot}%{install_dir}/
install -m 644 lib/freenet-ext.jar %{buildroot}%{install_dir}/lib/
install -m 644 lib/wrapper.jar %{buildroot}%{install_dir}/lib/
install -m 755 lib/libwrapper.so %{buildroot}%{install_dir}/lib/

# 3. Installation des Binaires et Scripts
install -m 755 hyphanet-wrapper %{buildroot}%{install_dir}/
install -m 755 hyphanet-service %{buildroot}%{install_dir}/

# 4. Installation de la Configuration de base (modèles)
install -m 644 wrapper.conf %{buildroot}%{install_dir}/
install -m 644 hyphanet.conf %{buildroot}%{install_dir}/
install -m 644 seednodes.fref %{buildroot}%{install_dir}/

# 5. AJUSTEMENT DES CHEMINS DANS WRAPPER.CONF
# On s'assure que le Wrapper trouve les fichiers dans /opt même s'il tourne dans /var/lib
sed -i "s|wrapper.java.classpath.1=.*|wrapper.java.classpath.1=%{install_dir}/lib/wrapper.jar|" %{buildroot}%{install_dir}/wrapper.conf
sed -i "s|wrapper.java.classpath.2=.*|wrapper.java.classpath.2=%{install_dir}/freenet.jar|" %{buildroot}%{install_dir}/wrapper.conf
sed -i "s|wrapper.java.classpath.3=.*|wrapper.java.classpath.3=%{install_dir}/lib/freenet-ext.jar|" %{buildroot}%{install_dir}/wrapper.conf
sed -i "s|wrapper.java.library.path.1=.*|wrapper.java.library.path.1=%{install_dir}/lib|" %{buildroot}%{install_dir}/wrapper.conf
sed -i "s|wrapper.logfile=.*|wrapper.logfile=%{log_dir}/wrapper.log|" %{buildroot}%{install_dir}/wrapper.conf

# 6. Création du fichier de service Systemd
cat <<EOF > %{buildroot}%{_unitdir}/hyphanet.service
[Unit]
Description=Hyphanet (Freenet) Node
After=network.target syslog.target

[Service]
Type=forking
User=%{user_name}
Group=%{user_name}
# Dossier de travail pour les données et le PID
WorkingDirectory=%{data_dir}
ExecStart=%{install_dir}/hyphanet-service
Restart=on-failure
PIDFile=%{data_dir}/hyphanet.pid

[Install]
WantedBy=multi-user.target
EOF

%pre
# Création de l'utilisateur système hyphanet
getent group %{user_name} >/dev/null || groupadd -r %{user_name}
getent passwd %{user_name} >/dev/null || \
    useradd -r -g %{user_name} -d %{data_dir} -s /sbin/nologin \
    -c "Hyphanet Daemon User" %{user_name}
exit 0

%post
%systemd_post hyphanet.service

# Initialisation des fichiers de configuration dans /var/lib s'ils n'existent pas
for file in hyphanet.conf seednodes.fref wrapper.conf; do
    if [ ! -f %{data_dir}/$file ]; then
        cp %{install_dir}/$file %{data_dir}/
        chown %{user_name}:%{user_name} %{data_dir}/$file
        chmod 640 %{data_dir}/$file
    fi
done

%preun
%systemd_preun hyphanet.service

%postun
# Correction de la coquille .servicels -> .service
%systemd_postun_with_restart hyphanet.service

%files
%defattr(-,root,root,-)
# Dossier des binaires (lecture seule)
%{install_dir}/

# Dossiers de données et logs (propriété de l'utilisateur hyphanet)
%attr(0750,%{user_name},%{user_name}) %dir %{data_dir}
%attr(0750,%{user_name},%{user_name}) %dir %{log_dir}

# Fichier de service
%{_unitdir}/hyphanet.service

%changelog
* Thu Feb 12 2026 Hyphanet Packager <packager@hyphanet.org> - 0.7.1505-1
- Correction des chemins wrapper et des dépendances systemd
- Utilisation des seednodes depuis la branche next
