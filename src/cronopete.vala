/*
 Copyright 2011-2015 (C) Raster Software Vigo (Sergio Costas)

 This file is part of Cronopete

 Cronopete is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 3 of the License, or
 (at your option) any later version.

 Cronopete is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>. */

using GLib;
using Posix;
using Gee;
using Gtk;
using Gdk;
using Cairo;
using Gsl;
using Posix;
using AppIndicator;

// project version=4.0.0

namespace cronopete {

	cronopete_class callback_object;

	enum BackupStatus { STOPPED, ALLFINE, WARNING, ERROR }

	class cronopete_class : GLib.Object {

		private backup_base backup_backend;
		private Indicator appindicator;
		private GLib.Settings cronopete_settings;
		private c_main_menu main_menu;

		public cronopete_class() {
			// currently there is only the RSYNC backend
			this.backup_backend = new backup_rsync();
			this.cronopete_settings = new GLib.Settings("org.rastersoft.cronopete");
			this.main_menu = new c_main_menu(this.backup_backend);
		}

		public void check_welcome() {
			if(this.cronopete_settings.get_boolean("show-welcome") == false) {
				return;
			}

			var w = new Builder();
			w.add_from_file(GLib.Path.build_filename(Constants.PKGDATADIR,"welcome.ui"));
			var welcome_w = (Dialog)w.get_object("dialog1");
			welcome_w.show();
			var retval = welcome_w.run();
			welcome_w.hide();
			welcome_w.destroy();
			switch(retval) {
			case 1: // ask me later
			break;
			case 2: // configure now
				this.cronopete_settings.set_boolean("show-welcome",false);
				this.show_configuration();
			break;
			case 3: // don't ask again
				this.cronopete_settings.set_boolean("show-welcome",false);
			break;
			}
		}

		public void show_configuration() {
			this.main_menu.show_main();
		}
	}

	void on_bus_aquired (DBusConnection conn) {
		try {
			conn.register_object ("/com/rastersoft/cronopete", new DetectServer ());
		} catch (IOError e) {
			GLib.stderr.printf ("Could not register service\n");
		}
	}

	int main(string[] args) {

		int fork_pid;
		int status;

		while(true) {
			// Create a child and run cronopete there
			// If the child dies, launch cronopete again, to ensure that the backup always work
			fork_pid = Posix.fork();
			if (fork_pid == 0) {
				nice(19); // Minimum priority
				Intl.bindtextdomain(Constants.GETTEXT_PACKAGE, GLib.Path.build_filename(Constants.DATADIR,"locale"));
				Intl.textdomain("cronopete");
				Intl.bind_textdomain_codeset("cronopete", "UTF-8" );	
				Gtk.init(ref args);
				callback_object = new cronopete_class();
				Bus.own_name (BusType.SESSION, "com.rastersoft.cronopete", BusNameOwnerFlags.NONE, on_bus_aquired, () => {}, () => {
					GLib.stderr.printf ("Cronopete is already running\n");
					Posix.exit(1);
				});
	
				callback_object.check_welcome();
				Gtk.main();
				return 0;
			}
		Posix.waitpid (fork_pid, out status, 0);
		}
	}

	[DBus (name = "com.rastersoft.cronopete")]
	public class DetectServer : GLib.Object {

		public int do_ping(int v) {
			return (v+1);
		}

		public void do_backup() {
			//callback_object.backup_now();
		}

		public void stop_backup() {
			//callback_object.stop_backup();
		}

		public void show_preferences() {
			callback_object.show_configuration();
		}

		public void restore_files() {
			//callback_object.enter_clicked ();
		}
	}
}