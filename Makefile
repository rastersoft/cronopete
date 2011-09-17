PREFIX ?= /usr/local

cronopete: backup.vala choose.vala cronopete.vala menu.vala options.vala switch_widget.vala usbhd_backend.vala
	valac -q -X -D'GETTEXT_PACKAGE="cronopete"' backup.vala choose.vala cronopete.vala menu.vala options.vala switch_widget.vala usbhd_backend.vala --pkg gio-2.0 --pkg gtk+-2.0 --pkg posix --pkg gee-1.0 --pkg gsl --pkg gmodule-2.0 -o cronopete

install:
	rm -f $PREFIX/bin/cronopete
	cp cronopete $PREFIX/bin
	install -d $PREFIX/share/cronopete
	cp interface/*.ui $PREFIX/share/cronopete
	cp interface/*.svg $PREFIX/share/cronopete
	cp cronopete.desktop /etc/xdg/autostart/
	install  -d $PREFIX/share/locale/es/LC_MESSAGES
	cp po/es.mo $PREFIX/share/locale/es/LC_MESSAGES/cronopete.mo
	install  -d $PREFIX/share/locale/gl/LC_MESSAGES
	cp po/gl.mo $PREFIX/share/locale/gl/LC_MESSAGES/cronopete.mo

clean:
	rm cronopete

launch:
	killall -q cronopete || cd
	cronopete &	

uninstall:
	rm $PREFIX/bin/cronopete
	rm -rf $PREFIX/share/cronopete
	rm  /etc/xdg/autostart/cronopete.desktop
	rm $PREFIX/share/locale/es/LC_MESSAGES/cronopete.mo
	rm $PREFIX/share/locale/gl/LC_MESSAGES/cronopete.mo

