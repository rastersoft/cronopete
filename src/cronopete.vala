/*
 * Copyright 2011-2018 (C) Raster Software Vigo (Sergio Costas)
 *
 * This file is part of Cronopete
 *
 * Cronopete is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * Cronopete is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>. */

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

	public class cronopete_class : GLib.Object {
		public int first_delay = 0;

		private backup_base backend;
		private backup_base[] backend_list;
		private int current_backend;
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

		private restore_iface restore_window;
		private bool restore_window_visible;

		public signal void changed_backend(backup_base backend);

		public cronopete_class() {
			this.restore_window_visible = false;
			this.iconpos         = 0;
			this.animation_timer = 0;
			this.current_status  = BackupStatus.STOPPED;

			this.cronopete_settings = new GLib.Settings("org.rastersoft.cronopete");
			this.backend_list       = {};
			// currently there is only the RSYNC backend
			this.backend_list   += new backup_rsync();
			this.backend_list   += new backup_folder();
			this.current_backend = this.cronopete_settings.get_int("current-backend");
			if (this.current_backend >= this.backend_list.length) {
				this.current_backend = 0;
			}
			// Window that manages the configuration and the log
			this.main_menu = new c_main_menu(this, this.backend_list);

			this.backend = null;
			this.updated_backend();

			// Create the app indicator
			this.appindicator = new Indicator("Cronopete", "cronopete_arrow_1_green", IndicatorCategory.APPLICATION_STATUS);

			this.cronopete_settings.changed.connect(this.changed_config);

			// check if this is the first time we launch cronopete
			this.check_welcome();
			// update the menu
			this.menuSystem_popup();
			// set indicator visibility
			this.changed_config("visible");
			this.repaint_tray_icon();
			// wait 10 minutes before checking if a backup is needed, to allow the desktop to be fully loaded
			this.first_delay = 10;
			// Check every minute if we have to do a backup
			GLib.Timeout.add(60000, this.check_backup);
		}

		public void updated_backend() {
			if (this.backend != null) {
				// Unconnect all the signals from the old backend
				this.backend.send_warning.disconnect(this.received_warning);
				this.backend.send_error.disconnect(this.received_error);
				this.backend.is_available_changed.disconnect(this.backend_availability_changed);
				this.backend.current_status_changed.disconnect(this.backend_status_changed);
				this.backend.in_use(false);
			}
			this.backend = this.backend_list[this.current_backend];
			// Connect all the signals
			this.backend.send_warning.connect(this.received_warning);
			this.backend.send_error.connect(this.received_error);
			this.backend.is_available_changed.connect(this.backend_availability_changed);
			this.backend.current_status_changed.connect(this.backend_status_changed);
			this.backend.in_use(true);
			this.changed_backend(this.backend);
		}

		private bool can_do_backup() {
			if (this.backend.current_status != backup_current_status.IDLE) {
				return false;
			}
			if (this.backend.storage_is_available() == false) {
				return false;
			}
			if (this.cronopete_settings.get_boolean("enabled") == false) {
				return false;
			}
			return true;
		}

		/**
		 * Every 10 minutes will check if there is need to do a new backup
		 * Since deleting old backups can take a lot of time, it can delay
		 * the next backup
		 */
		private bool check_backup() {
			if (this.first_delay > 0) {
				this.first_delay--;
				return true;
			}
			if (this.can_do_backup()) {
				var last_backup = this.backend.get_last_backup();
				var now         = time_t();
				var period      = this.cronopete_settings.get_uint("backup-period");
				if ((last_backup + period) <= now) {
					// a backup is pending
					this.backup_now();
				}
			}
			return true;
		}

		public void backup_now() {
			if (this.can_do_backup()) {
				this.main_menu.erase_text_log();
				this.backend.do_backup(this.cronopete_settings.get_strv("backup-folders"),
				                       this.cronopete_settings.get_strv("exclude-folders"),
				                       this.cronopete_settings.get_boolean("skip-hiden-at-home"));
			}
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
				return;
			}
			if (key == "enabled") {
				this.repaint_tray_icon();
				this.menuSystem_popup();
				return;
			}
			if (key == "current-backend") {
				this.current_backend = this.cronopete_settings.get_int("current-backend");
				if (this.current_backend >= this.backend_list.length) {
					this.current_backend = 0;
				}
				this.updated_backend();
				this.repaint_tray_icon();
				this.menuSystem_popup();
				return;
			}
		}

		/* Paints the animated icon in the panel */
		public bool repaint_tray_icon() {
			backup_current_status backup_status = this.backend.current_status;

			if (backup_status != backup_current_status.IDLE) {
				this.iconpos++;
			}
			if (this.iconpos > 3) {
				this.iconpos = 0;
			}

			string icon_color  = "";
			string description = "";
			if (this.backend.storage_is_available() == false) {
				// There's no disk connected
				icon_color = "red";
				// TRANSLATORS Specify that the disk configured for backups is not available
				description = _("Disk not available");
			} else {
				if (this.cronopete_settings.get_boolean("enabled")) {
					switch (this.current_status) {
					case BackupStatus.STOPPED:
						// Idle
						icon_color = "white";
						// TRANSLATORS The program state, used in a tooltip, when it is waiting to do the next backup
						description = _("Idle");
						break;

					case BackupStatus.ALLFINE:
					{
						switch (backup_status) {
						case backup_current_status.RUNNING:
						case backup_current_status.SYNCING:
							// doing backup, everything is fine
							icon_color  = "green";
							description = _("Doing backup");
							break;

						case backup_current_status.CLEANING:
							icon_color  = "cyan";
							description = _("Cleaning old backups");
							break;
						}
					}
					break;

					case BackupStatus.WARNING:
						icon_color = "yellow";
						// TRANSLATORS The program state, used in a tooltip, when it is doing a backup and there is, at least, a warning message
						description = _("Doing backup, have a warning");
						break;

					case BackupStatus.ERROR:
						icon_color = "red";
						// TRANSLATORS The program state, used in a tooltip, when it is doing a backup and there is, at least, an error message
						description = _("Doing backup, have an error");
						break;
					}
				} else {
					// the backup is disabled
					icon_color = "orange";
					// TRANSLATORS The program state, used in a tooltip, when the backups are disabled and won't be done
					description = _("Backup is disabled");
				}
			}
			string icon_name = "cronopete-arrow-%d-%s".printf(this.iconpos + 1, icon_color);

			this.appindicator.set_icon_full(icon_name, description);
			if (backup_status == backup_current_status.IDLE) {
				this.animation_timer = 0;
				return false;
			} else {
				return true;
			}
		}

		private void backend_availability_changed(bool is_availabe) {
			// update the menu
			this.menuSystem_popup();
			// and the tray icon color
			this.repaint_tray_icon();
		}

		public void backend_status_changed(backup_current_status status) {
			// update the menu
			this.menuSystem_popup();
			if (status != backup_current_status.IDLE) {
				if (this.animation_timer == 0) {
					this.current_status  = BackupStatus.ALLFINE;
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
			if (this.cronopete_settings.get_boolean("show-welcome") == false) {
				return;
			}

			var w = new Builder();
			try {
				w.add_from_file(GLib.Path.build_filename(Constants.PKGDATADIR, "welcome.ui"));
			} catch (GLib.Error e) {
				print("Error trying to show the WELCOME window.\n");
				return;
			}
			var welcome_w = (Dialog) w.get_object("dialog1");
			welcome_w.show();
			var retval = welcome_w.run();
			welcome_w.hide();
			welcome_w.destroy();
			switch (retval) {
			case 1:
				// ask me later
				break;

			case 2:
				// configure now
				this.cronopete_settings.set_boolean("show-welcome", false);
				this.show_configuration();
				break;

			case 3:
				// don't ask again
				this.cronopete_settings.set_boolean("show-welcome", false);
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

			if (this.menuSystem == null) {
				// if there is no menu, create it
				this.menuSystem = new Gtk.Menu();
				this.menuDate   = new Gtk.MenuItem();

				menuDate.sensitive = false;
				menuSystem.append(menuDate);

				// TRANSLATORS Menu entry to start a new backup manually
				this.menuBUnow = new Gtk.MenuItem.with_label(_("Back Up Now"));
				menuBUnow.activate.connect(this.backup_now);
				this.menuSystem.append(menuBUnow);
				// TRANSLATORS Menu entry to abort the current backup manually
				this.menuSBUnow = new Gtk.MenuItem.with_label(_("Stop Backing Up"));
				menuSBUnow.activate.connect(this.stop_backup);
				this.menuSystem.append(menuSBUnow);

				// TRANSLATORS Menu entry to open the interface for restoring files from a backup
				this.menuEnter = new Gtk.MenuItem.with_label(_("Restore files"));
				menuEnter.activate.connect(this.restore_files);
				menuSystem.append(menuEnter);


				var menuBar = new Gtk.SeparatorMenuItem();
				menuSystem.append(menuBar);

				// TRANSLATORS Menu entry to open the configuration window
				menuMain = new Gtk.MenuItem.with_label(_("Configure the backups"));
				menuMain.activate.connect(this.show_configuration);
				menuSystem.append(menuMain);

				menuSystem.show_all();
				this.appindicator.set_menu(this.menuSystem);
			}

			// TRANSLATORS Show the date of the last backup
			this.menuDate.set_label(_("Latest backup: %s").printf(cronopete.date_to_string(this.backend.get_last_backup())));

			if (this.backend.storage_is_available()) {
				int64 a, b;
				var   list = this.backend.get_backup_list(out a, out b);
				if ((list == null) || (list.size <= 0)) {
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
			if (this.backend.storage_is_available() && this.cronopete_settings.get_boolean("enabled")) {
				menuBUnow.sensitive  = true;
				menuSBUnow.sensitive = true;
			} else {
				menuBUnow.sensitive  = false;
				menuSBUnow.sensitive = false;
			}
		}

		public void stop_backup() {
			if (this.backend.current_status != backup_current_status.IDLE) {
				this.backend.abort_backup();
			}
		}

		public void restore_files() {
			if (this.restore_window_visible) {
				this.restore_window.present();
			} else {
				this.restore_window_visible = true;
				this.restore_window         = new restore_iface(this.backend);
				this.restore_window.destroy.connect(() => {
					this.restore_window_visible = false;
				});
			}
		}
	}

	void on_bus_aquired(DBusConnection conn) {
		try {
			conn.register_object("/com/rastersoft/cronopete", new DetectServer());
		} catch (IOError e) {
			GLib.stderr.printf("Could not register DBUS service\n");
		}
	}

	int main(string[] args) {
		int fork_pid;
		int status;

		while (true) {
			// Create a child and run cronopete there
			// If the child dies, launch cronopete again, to ensure that the backup always work
			fork_pid = Posix.fork();
			if (fork_pid == 0) {
				// Minimum priority
				nice(19);
				Intl.bindtextdomain(Constants.GETTEXT_PACKAGE, GLib.Path.build_filename(Constants.DATADIR, "locale"));
				Intl.textdomain("cronopete");
				Intl.bind_textdomain_codeset("cronopete", "UTF-8");
				Gtk.init(ref args);
				callback_object = new cronopete_class();
				Bus.own_name(BusType.SESSION, "com.rastersoft.cronopete", BusNameOwnerFlags.NONE, on_bus_aquired, () => {}, () => {
					GLib.stderr.printf("Cronopete is already running.\n");
					Posix.exit(1);
				});
				Gtk.main();
				return 0;
			}
			Posix.waitpid(fork_pid, out status, 0);
			if (status == 48) {
				// This is the status for an abort
				break;
			}
			Posix.sleep(1);
		}
		return -1;
	}

	[DBus(name = "com.rastersoft.cronopete")]
	public class DetectServer : GLib.Object {
		public int do_ping(int v) throws GLib.DBusError, GLib.IOError {
			return (v + 1);
		}

		public void do_backup() throws GLib.DBusError, GLib.IOError {
			callback_object.backup_now();
		}

		public void stop_backup() throws GLib.DBusError, GLib.IOError {
			callback_object.stop_backup();
		}

		public void show_preferences() throws GLib.DBusError, GLib.IOError {
			callback_object.show_configuration();
		}

		public void restore_files() throws GLib.DBusError, GLib.IOError {
			callback_object.restore_files();
		}
	}
}
