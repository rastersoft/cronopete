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

		private backup_base backend;
		private GLib.Settings cronopete_settings;
		private c_main_menu main_menu;
		private BackupStatus current_status;

		private Indicator appindicator;
		private Gtk.Menu menuSystem;
		private Gtk.MenuItem menuDate;
		private Gtk.MenuItem menuBUnow;
		private Gtk.MenuItem menuSBUnow;
		private Gtk.MenuItem menuEnter;

		private int iconpos;
		private uint animation_timer;

		public cronopete_class() {

			this.iconpos = 0;
			this.animation_timer = 0;
			this.current_status = BackupStatus.STOPPED;

			// currently there is only the RSYNC backend
			this.backend = new backup_rsync();

			this.cronopete_settings = new GLib.Settings("org.rastersoft.cronopete");

			// Window that manages the configuration and the log
			this.main_menu = new c_main_menu(this.backend);

			// Create the app indicator
			this.appindicator = new Indicator("Cronopete", "cronopete_arrow_1_green", IndicatorCategory.APPLICATION_STATUS);

			// Connect all the signals
			this.backend.send_warning.connect(this.received_warning);
			this.backend.send_error.connect(this.received_error);
			this.backend.is_available_changed.connect(this.backend_availability_changed);
			this.backend.current_status_changed.connect(this.backend_status_changed);
			this.cronopete_settings.changed.connect(this.changed_config);

			// check if this is the first time we launch cronopete
			this.check_welcome();
			this.menuSystem_popup(); // update the menu
			// set indicator visibility
			this.changed_config("visible");
			this.repaint_tray_icon();
		}

		/**
		 * Manages every change in the configuration
		 */
		private void changed_config(string key) {
			if (key == "visible") {
				if (this.cronopete_settings.get_boolean("visible")) {
					this.appindicator.set_status(IndicatorStatus.ACTIVE);
				} else {
					this.appindicator.set_status(IndicatorStatus.PASSIVE);
				}
			}
		}

		/* Paints the animated icon in the panel */
		public bool repaint_tray_icon() {

			string icon_name = "cronopete-arrow-";

			switch(this.iconpos) {
			default:
				icon_name += "1";
				this.iconpos = 0;
			break;
			case 1:
				icon_name += "2";
			break;
			case 2:
				icon_name += "3";
			break;
			case 3:
				icon_name += "4";
			break;
			}
			icon_name += "-";
			backup_current_status backup_status = this.backend.current_status;
			if (backup_status != backup_current_status.IDLE) {
				this.iconpos++;
			}
			if (this.backend.storage_is_available() == false) {
				icon_name += "red"; // There's no disk connected
			} else {
				if (this.cronopete_settings.get_boolean("enabled")) {
					switch (this.current_status) {
					case BackupStatus.STOPPED:
						icon_name += "white"; // Idle
					break;
					case BackupStatus.ALLFINE:
						if ((backup_status == backup_current_status.RUNNING) && (backup_status == backup_current_status.SYNCING)) {
							icon_name += "green"; // Doing backup; everything fine
						} else if (backup_status == backup_current_status.CLEANING) {
							icon_name += "white"; // Clening old backups; everything fine
						}
					break;
					case BackupStatus.WARNING:
						icon_name += "yellow";
					break;
					case BackupStatus.ERROR:
						icon_name += "red";
					break;
					}
				} else {
					icon_name += "orange";
				}
			}

			this.appindicator.set_icon(icon_name);
			if (backup_status == backup_current_status.IDLE) {
				this.animation_timer = 0;
				return false;
			} else {
				return true;
			}
		}

		private void backend_availability_changed(bool is_availabe) {
			this.menuSystem_popup(); // update the menu
		}

		public void backend_status_changed(backup_current_status status) {
			this.menuSystem_popup(); // update the menu
			if (status != backup_current_status.IDLE) {
				if (this.animation_timer == 0) {
					this.current_status = BackupStatus.ALLFINE;
					this.animation_timer = GLib.Timeout.add(500, this.repaint_tray_icon);
				}
			} else {
				if (this.current_status == BackupStatus.ALLFINE) {
					this.current_status = BackupStatus.STOPPED;
				}
			}
		}

		private void received_warning(string msg) {
			if (this.current_status != BackupStatus.STOPPED) {
				this.current_status = BackupStatus.WARNING;
			}
		}

		private void received_error(string msg) {
			if (this.current_status != BackupStatus.STOPPED) {
				this.current_status = BackupStatus.ERROR;
			}
		}

		public void check_welcome() {
			if(this.cronopete_settings.get_boolean("show-welcome") == false) {
				return;
			}

			var w = new Builder();
			try {
				w.add_from_file(GLib.Path.build_filename(Constants.PKGDATADIR,"welcome.ui"));
			} catch(GLib.Error e) {
				print("Error trying to show the WELCOME window.\n");
				return;
			}
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

		/**
		 * Updates the menu in the AppIndicator
		 */
		private void menuSystem_popup() {

			Gtk.MenuItem menuMain;

			if(this.menuSystem == null) {
				// if there is no menu, create it
				this.menuSystem = new Gtk.Menu();
				this.menuDate = new Gtk.MenuItem();

				menuDate.sensitive = false;
				menuSystem.append(menuDate);

				this.menuBUnow = new Gtk.MenuItem.with_label(_("Back Up Now"));
				menuBUnow.activate.connect(this.backup_now);
				this.menuSystem.append(menuBUnow);
				this.menuSBUnow = new Gtk.MenuItem.with_label(_("Stop Backing Up"));
				menuSBUnow.activate.connect(this.stop_backup);
				this.menuSystem.append(menuSBUnow);

				this.menuEnter = new Gtk.MenuItem.with_label(_("Restore files"));
				menuEnter.activate.connect(this.restore_files);
				menuSystem.append(menuEnter);


				var menuBar = new Gtk.SeparatorMenuItem();
				menuSystem.append(menuBar);

				menuMain = new Gtk.MenuItem.with_label(_("Configure backup policies"));
				menuMain.activate.connect(this.show_configuration);
				menuSystem.append(menuMain);

				menuSystem.show_all();
				this.appindicator.set_menu(this.menuSystem);
			}

			string last_backup_str;
			var last_backup_time = this.backend.get_last_backup();
			if (last_backup_time == 0) {
				last_backup_str = _("None");
			} else {
				var last_backup = GLib.Time.local(last_backup_time);
				var now = GLib.Time.local(time_t());
				if ((last_backup.day == now.day) && (last_backup.month == now.month) && (last_backup.year == now.year)) {
					last_backup_str = last_backup.format("%X");
				} else {
					last_backup_str = last_backup.format("%x");
				}
			}
			this.menuDate.set_label(_("Latest backup: %s").printf(last_backup_str));
			if (this.backend.storage_is_available()) {
				int64 a, b;
				var list = this.backend.get_backup_list(out a, out b);
				if ((list == null)||(list.size <= 0)) {
					menuEnter.sensitive = false;
				} else {
					menuEnter.sensitive = true;
				}
			} else {
				menuEnter.sensitive = false;
			}
			if (this.backend.current_status == backup_current_status.IDLE) {
				menuBUnow.show();
				menuSBUnow.hide();
			} else {
				menuSBUnow.show();
				menuBUnow.hide();
			}
			menuBUnow.sensitive = this.backend.storage_is_available();
			menuSBUnow.sensitive = this.backend.storage_is_available();
		}

		private void backup_now() {
			if (this.backend.current_status == backup_current_status.IDLE) {
				this.backend.do_backup();
			}
		}

		private void stop_backup() {
			if (this.backend.current_status != backup_current_status.IDLE) {
				this.backend.abort_backup();
			}
		}

		private void restore_files() {}
	}

	void on_bus_aquired (DBusConnection conn) {
		try {
			conn.register_object ("/com/rastersoft/cronopete", new DetectServer ());
		} catch (IOError e) {
			GLib.stderr.printf ("Could not register DBUS service\n");
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
					GLib.stderr.printf ("Cronopete is already running.\n");
					Posix.exit(1);
				});
				Gtk.main();
				return 0;
			}
			Posix.waitpid (fork_pid, out status, 0);
			if (status == 48) {
				// This is the status for an abort
				break;
			}
			Posix.sleep(1);
		}
		return -1;
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