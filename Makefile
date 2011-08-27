cronopete: backup.vala choose.vala cronopete.vala menu.vala options.vala switch_widget.vala usbhd_backend.vala
	valac -q -X -D'GETTEXT_PACKAGE="cronopete"' backup.vala choose.vala cronopete.vala menu.vala options.vala switch_widget.vala usbhd_backend.vala --pkg gio-2.0 --pkg gtk+-2.0 --pkg posix --pkg gee-1.0 --pkg gsl --pkg gmodule-2.0 -o cronopete

install:
	cp cronopete /usr/local/bin
	install -d /usr/local/share/cronopete
	cp interface/*.ui /usr/local/share/cronopete
	cp interface/*.svg /usr/local/share/cronopete
	cp cronopete.desktop /etc/xdg/autostart/
	install  -d /usr/local/share/locale/es/LC_MESSAGES
	cp po/es.mo /usr/local/share/locale/es/LC_MESSAGES/cronopete.mo
	install  -d /usr/local/share/locale/gl/LC_MESSAGES
	cp po/gl.mo /usr/local/share/locale/gl/LC_MESSAGES/cronopete.mo

clean:
	rm cronopete

uninstall:
	rm /usr/local/bin/cronopete
	rm -rf /usr/local/share/cronopete
	rm  /etc/xdg/autostart/cronopete.desktop
	rm /usr/local/share/locale/es/LC_MESSAGES/cronopete.mo
	rm /usr/local/share/locale/gl/LC_MESSAGES/cronopete.mo

