ifdef PREFIX
	PREFIX2=$(PREFIX)/usr
else
	PREFIX2=/usr/local
endif

cronopete: backup.vala choose.vala cronopete.vala menu.vala options.vala switch_widget.vala usbhd_backend.vala restore.vala icons_widget.vala
	valac -q -X -D'GETTEXT_PACKAGE="cronopete"' backup.vala choose.vala cronopete.vala menu.vala options.vala switch_widget.vala usbhd_backend.vala restore.vala icons_widget.vala --pkg gio-2.0 --pkg gtk+-2.0 --pkg posix --pkg gee-1.0 --pkg gsl --pkg gmodule-2.0 -o cronopete

install:
	rm -f $(PREFIX2)/bin/cronopete
	install -d $(PREFIX2)/bin/
	cp cronopete $(PREFIX2)/bin
	install -d $(PREFIX2)/share/cronopete
	cp interface/*.ui $(PREFIX2)/share/cronopete
	cp interface/*.svg $(PREFIX2)/share/cronopete
	install -d $(PREFIX)/etc/xdg/autostart/
	cp cronopete.desktop $(PREFIX)/etc/xdg/autostart/
	install  -d $(PREFIX2)/share/locale/es/LC_MESSAGES
	cp po/es.mo $(PREFIX2)/share/locale/es/LC_MESSAGES/cronopete.mo
	install  -d $(PREFIX2)/share/locale/gl/LC_MESSAGES
	cp po/gl.mo $(PREFIX2)/share/locale/gl/LC_MESSAGES/cronopete.mo

clean:
	rm cronopete

launch:
	killall -q cronopete || cd
	cronopete &	

uninstall:
	rm $(PREFIX2)/bin/cronopete
	rm -rf $(PREFIX2)/share/cronopete
	rm $(PREFIX)/etc/xdg/autostart/cronopete.desktop
	rm $(PREFIX2)/share/locale/es/LC_MESSAGES/cronopete.mo
	rm $(PREFIX2)/share/locale/gl/LC_MESSAGES/cronopete.mo

