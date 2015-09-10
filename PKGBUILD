pkgname=cronopete
pkgver=3.19.0
pkgrel=1
pkgdesc="A backup utility for Linux.

Cronopete is a backup utility for Linux, modeled after Apple's Time
Machine. It aims to simplify the creation of periodic backups."
arch=('i686' 'x86_64')
depends=( 'atk' 'glib2' 'cairo' 'gtk3' 'pango' 'gdk-pixbuf2' 'libgee' 'gsl' 'glibc' 'udisks2' 'libx11' )
makedepends=( 'vala' 'glibc' 'atk' 'cairo' 'gtk3' 'gdk-pixbuf2' 'libgee' 'glib2' 'gsl' 'pango' 'udisks2' 'libx11' 'cmake' 'gettext' 'pkg-config' 'gcc' 'make' 'intltool' )
source=()
noextract=()
md5sums=()
validpgpkeys=()

build() {
	rm -rf ${startdir}/install
	mkdir ${startdir}/install
	cd ${startdir}/install
	cmake .. -DCMAKE_INSTALL_PREFIX=/usr
	make
}

package() {
	cd ${startdir}/install
	make DESTDIR="$pkgdir/" install
}
