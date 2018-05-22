pkgname=cronopete
pkgver=4.2.0
pkgrel=1
pkgdesc="A backup utility for Linux.

Cronopete is a backup utility for Linux, modeled after Apple's Time
Machine. It aims to simplify the creation of periodic backups.
"
arch=('i686' 'x86_64')
depends=( 'gtk3' 'pango' 'atk' 'cairo' 'gdk-pixbuf2' 'glib2' 'libappindicator-gtk3' 'libdbusmenu-glib' 'libgee' 'gsl' 'glibc' 'udisks2' 'rsync' )
makedepends=( 'vala' 'glibc' 'gtk3' 'libappindicator-gtk3' 'cairo' 'gdk-pixbuf2' 'libgee' 'glib2' 'gsl' 'pango' 'udisks2' 'cmake' 'gettext' 'pkg-config' 'gcc' 'make' 'intltool' )
build() {
	rm -rf ${startdir}/install
	mkdir ${startdir}/install
	cd ${startdir}/install
	cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=/usr/lib
	make -j1
}

package() {
	cd ${startdir}/install
	make DESTDIR="$pkgdir/" install
}
