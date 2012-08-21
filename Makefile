ifdef PREFIX
	PREFIX2=$(PREFIX)/usr
else
	PREFIX2=/usr/local
endif

all: cronopete cronopete3

cronopete: backup.vala choose.vala cronopete.vala menu.vala options.vala switch_widget.vala usbhd_backend.vala restore.vala icons_widget.vala
	rm -f *.c
	rm -f cronopete
	valac -q -X -O2 -X -D'GETTEXT_PACKAGE="cronopete"' backup.vala choose.vala cronopete.vala menu.vala options.vala switch_widget.vala usbhd_backend.vala restore.vala icons_widget.vala --pkg gio-2.0 --pkg gtk+-2.0 --pkg posix --pkg gee-1.0 --pkg gsl --pkg gmodule-2.0 -o cronopete

cronopete3: backup.vala choose.vala cronopete.vala menu.vala options.vala usbhd_backend.vala restore.vala icons_widget.vala
	rm -f *.c
	rm -f cronopete3
	valac -q -X -O2 -X -D'GETTEXT_PACKAGE="cronopete"' -D USE_GTK3 backup.vala choose.vala cronopete.vala menu.vala options.vala usbhd_backend.vala restore.vala icons_widget.vala --pkg gio-2.0 --pkg gtk+-3.0 --pkg posix --pkg gee-1.0 --pkg gsl --pkg gmodule-2.0 -o cronopete3


install:
	rm -f $(PREFIX2)/bin/cronopete
	install -d $(PREFIX2)/bin/
	cp cronopete $(PREFIX2)/bin
	cp cronopete_restore $(PREFIX2)/bin
	cp cronopete_preferences $(PREFIX2)/bin
	install -d $(PREFIX2)/share/cronopete
	install -d $(PREFIX2)/share/icons
	install -d $(PREFIX2)/share/applications
	cp interface/*.ui $(PREFIX2)/share/cronopete/
	cp interface/anacronopete.svg $(PREFIX2)/share/cronopete/
	cp interface/cronopete_preferences.svg $(PREFIX2)/share/icons/
	cp interface/cronopete_restore.svg $(PREFIX2)/share/icons/
	cp interface/*.png $(PREFIX2)/share/cronopete/
	install -d $(PREFIX)/etc/xdg/autostart/
	cp cronopete.desktop $(PREFIX)/etc/xdg/autostart/
	cp cronopete_restore.desktop $(PREFIX2)/share/applications
	cp cronopete_preferences.desktop $(PREFIX2)/share/applications
	install  -d $(PREFIX2)/share/locale/es/LC_MESSAGES
	cp po/es.mo $(PREFIX2)/share/locale/es/LC_MESSAGES/cronopete.mo
	install  -d $(PREFIX2)/share/locale/gl/LC_MESSAGES
	cp po/gl.mo $(PREFIX2)/share/locale/gl/LC_MESSAGES/cronopete.mo

install3:
	rm -f $(PREFIX2)/bin/cronopete3
	install -d $(PREFIX2)/bin/
	cp cronopete3 $(PREFIX2)/bin/cronopete3
	cp cronopete_restore $(PREFIX2)/bin
	cp cronopete_preferences $(PREFIX2)/bin
	install -d $(PREFIX2)/share/cronopete3
	install -d $(PREFIX2)/share/icons
	install -d $(PREFIX2)/share/applications
	cp interface3/*.ui $(PREFIX2)/share/cronopete3/
	cp interface/anacronopete.svg $(PREFIX2)/share/cronopete3/
	cp interface/cronopete_preferences.svg $(PREFIX2)/share/icons/
	cp interface/cronopete_restore.svg $(PREFIX2)/share/icons/
	cp interface/*.png $(PREFIX2)/share/cronopete3/
	install -d $(PREFIX)/etc/xdg/autostart/
	cp cronopete3.desktop $(PREFIX)/etc/xdg/autostart/cronopete.desktop
	cp cronopete_restore.desktop $(PREFIX2)/share/applications
	cp cronopete_preferences.desktop $(PREFIX2)/share/applications
	install  -d $(PREFIX2)/share/locale/es/LC_MESSAGES
	cp po/es.mo $(PREFIX2)/share/locale/es/LC_MESSAGES/cronopete.mo
	install  -d $(PREFIX2)/share/locale/gl/LC_MESSAGES
	cp po/gl.mo $(PREFIX2)/share/locale/gl/LC_MESSAGES/cronopete.mo

clean:
	rm -f cronopete
	rm -f cronopete3
	rm -f *.c
	rm -f *~

launch:
	killall -q cronopete || cd
	killall -q cronopete3 || cd
	cronopete &	

launch3:
	killall -q cronopete || cd
	killall -q cronopete3 || cd
	cronopete3 &	

uninstall:
	rm $(PREFIX2)/bin/cronopete*
	rm -rf $(PREFIX2)/share/cronopete
	rm -rf $(PREFIX2)/share/cronopete3
	rm $(PREFIX)/etc/xdg/autostart/cronopete.desktop
	rm $(PREFIX2)/share/locale/es/LC_MESSAGES/cronopete.mo
	rm $(PREFIX2)/share/locale/gl/LC_MESSAGES/cronopete.mo

