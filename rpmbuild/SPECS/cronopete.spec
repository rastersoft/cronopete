Name: cronopete
Version: 4.4.0
Release: 1
License: Unknown/not set
Summary: A backup utility for Linux.

BuildRequires: gcc
BuildRequires: gcc-c++
BuildRequires: vala
BuildRequires: glibc-headers
BuildRequires: gtk3-devel
BuildRequires: libappindicator-gtk3-devel
BuildRequires: cairo-devel
BuildRequires: gdk-pixbuf2-devel
BuildRequires: libgee-devel
BuildRequires: glib2-devel
BuildRequires: gsl-devel
BuildRequires: pango-devel
BuildRequires: libudisks2-devel
BuildRequires: cmake
BuildRequires: gettext
BuildRequires: pkgconf-pkg-config
BuildRequires: make
BuildRequires: intltool

Requires: gtk3
Requires: pango
Requires: atk
Requires: cairo-gobject
Requires: cairo
Requires: gdk-pixbuf2
Requires: glib2
Requires: libappindicator-gtk3
Requires: libdbusmenu
Requires: libgee
Requires: gsl
Requires: glibc-devel
Requires: libudisks2
Requires: rsync

%description
A backup utility for Linux.
.
Cronopete is a backup utility for Linux, modeled after Apple's Time
Machine. It aims to simplify the creation of periodic backups.
.

%files
*

%build
mkdir -p ${RPM_BUILD_DIR}
cd ${RPM_BUILD_DIR}; cmake -DCMAKE_INSTALL_PREFIX=/usr -DGSETTINGS_COMPILE=OFF -DICON_UPDATE=OFF ../..
make -C ${RPM_BUILD_DIR}

%install
make install -C ${RPM_BUILD_DIR} DESTDIR=%{buildroot}

%post
glib-compile-schemas /usr/share/glib-2.0/schemas

%postun
glib-compile-schemas /usr/share/glib-2.0/schemas

%clean
rm -rf %{buildroot}

