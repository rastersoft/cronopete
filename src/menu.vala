/*
 * Copyright 2011-2018 (C) Raster Software Vigo (Sergio Costas)
 *
 * This file is part of Cronopete
 *
 * Nanockup is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * Nanockup is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>. */

using GLib;
using Gtk;

namespace  cronopete {
	public class c_main_menu : GLib.Object {
		private weak TextBuffer log;
		private Gtk.Window main_w;
		private Gtk.Builder builder;
		private Gtk.Notebook tabs;
		private Gtk.Label label_disk_id;
		private Gtk.Label label_oldest;
		private Gtk.Label label_newest;
		private Gtk.Label label_next;
		private Gtk.Label label_space;
		private Gtk.Label text_status;
		private Gtk.Button change_destination;
		private Gtk.Button set_options;
		private Gtk.Image disk_icon;
		private Gtk.ToggleButton show_in_bar_ch;
		private Gtk.TextMark mark;
		private Gtk.TextView log_view;
		private string last_status;
		private Gtk.Switch enabled_ch;
		private StringBuilder messages;
		private Gtk.ComboBox backend_list;
		private Gtk.ListStore backend_list_store;

		private backup_base backend;

		public bool is_visible;
		private GLib.Settings cronopete_settings;

		ulong[] handlers;

		public c_main_menu(cronopete_class cronopete, backup_base[] backends) {
			this.handlers           = {};
			this.backend            = null;
			this.cronopete_settings = new GLib.Settings("org.rastersoft.cronopete");
			this.messages           = new StringBuilder("");
			cronopete.changed_backend.connect(this.backend_changed);

			this.builder = new Builder();
			try {
				this.builder.add_from_file(Path.build_filename(Constants.PKGDATADIR, "main.ui"));
			} catch (GLib.Error e) {
				print("Can't create the configuration window. Aborting.\n");
				Posix.exit(48);
			}

			this.main_w = (Window) this.builder.get_object("window1");

			this.log                   = (Gtk.TextBuffer) this.builder.get_object("textbuffer1");
			this.log_view              = (Gtk.TextView) this.builder.get_object("textview1");
			this.tabs                  = (Gtk.Notebook) this.builder.get_object("notebook1");
			this.label_disk_id         = (Gtk.Label) this.builder.get_object("label_volume");
			this.label_oldest          = (Gtk.Label) this.builder.get_object("label_oldest_backup");
			this.label_newest          = (Gtk.Label) this.builder.get_object("label_newest_backup");
			this.label_next            = (Gtk.Label) this.builder.get_object("label_next_backup");
			this.label_space           = (Gtk.Label) this.builder.get_object("label_free_space");
			this.disk_icon             = (Gtk.Image) this.builder.get_object("image_disk");
			this.change_destination    = (Gtk.Button) this.builder.get_object("change_destination");
			this.set_options           = (Gtk.Button) this.builder.get_object("set_options");
			this.backend_list          = (Gtk.ComboBox) this.builder.get_object("backend_list");
			this.backend_list_store    = new Gtk.ListStore(2, typeof(string), typeof(int));
			this.show_in_bar_ch        = (Gtk.ToggleButton) this.builder.get_object("show_in_bar");
			this.text_status           = new fixed_label("", 300);
			this.text_status.ellipsize = Pango.EllipsizeMode.MIDDLE;
			this.text_status.lines     = 3;
			this.backend_list.set_model(this.backend_list_store);
			Gtk.CellRendererText cell = new Gtk.CellRendererText();
			this.backend_list.pack_start(cell, false);
			this.backend_list.set_attributes(cell, "text", 0);
			var status_alignment = (Gtk.Box) this.builder.get_object("status_frame");
			status_alignment.pack_start(this.text_status, true, true, 2);

			this.show_in_bar_ch.notify_property("active");

			(VBox) this.builder.get_object("vbox_switch");

			this.enabled_ch = (Gtk.Switch) this.builder.get_object("switch_main");
			this.enabled_ch.notify_property("active");

			this.is_visible = false;
			this.builder.connect_signals(this);
			this.cronopete_settings.bind("enabled", this.enabled_ch, "active", GLib.SettingsBindFlags.DEFAULT);
			this.cronopete_settings.bind("visible", this.show_in_bar_ch, "active", GLib.SettingsBindFlags.DEFAULT);
			TreeIter iter;
			uint     counter = 0;
			foreach (var backend in backends) {
				this.backend_list_store.append(out iter);
				this.backend_list_store.set(iter, 0, backend.get_descriptor());
				this.backend_list_store.set(iter, 1, counter);
				counter++;
			}
			this.backend_list.set_active(this.cronopete_settings.get_int("current-backend"));
			this.backend_list.changed.connect(this.changed_selected_backend);
		}

		public void changed_selected_backend() {
			var      old = this.cronopete_settings.get_int("current-backend");
			TreeIter iter;
			this.backend_list.get_active_iter(out iter);
			Value v;
			this.backend_list_store.get_value(iter, 1, out v);
			var val = v.get_int();
			if (val != old) {
				this.cronopete_settings.set_int("current-backend", val);
			}
		}

		public void backend_changed(backup_base new_backend) {
			if (this.backend != null) {
				foreach (var i in this.handlers) {
					this.backend.disconnect(i);
				}
			}
			this.backend   = new_backend;
			this.handlers  = {};
			this.handlers += this.backend.send_warning.connect((msg) => {
				// TRANSLATORS Shows a warning message with "warning" in Orange color
				this.insert_text_log(_("<span foreground=\"#FF7F00\">WARNING:</span> %s").printf(msg));
			});
			this.handlers += this.backend.send_error.connect((msg) => {
				// TRANSLATORS Shows an error message with "error" in Orange color
				this.insert_text_log(_("<span foreground=\"#FF3F3F\">ERROR:</span> %s").printf(msg));
			});
			this.handlers += this.backend.send_message.connect((msg) => {
				this.insert_text_log(msg);
			});
			this.handlers += this.backend.send_current_action.connect((msg) => {
				var msg2 = msg.strip();
				if (msg2 != "") {
				    this.set_status(msg2);
				}
			});
			this.handlers += this.backend.current_status_changed.connect(this.backend_status_changed);
			this.handlers += this.backend.is_available_changed.connect(this.backend_available_changed);
			this.refresh_backup_data();
			this.backend_list.set_active(this.cronopete_settings.get_int("current-backend"));
		}

		public void backend_available_changed(bool is_available) {
			if (this.main_w.visible) {
				this.refresh_backup_data();
			}
		}

		public void backend_status_changed(backup_current_status status) {
			if (this.main_w.visible) {
				this.refresh_backup_data();
			}
		}

		public void set_status(string msg) {
			// TRANSLATORS This string shows the current status of Cronopete. It can be "Status: idle", or "Status: copying file"...
			this.last_status = _("Status: %s").printf(msg);
			if (this.is_visible) {
				this.text_status.set_label(this.last_status);
			}
		}

		public void erase_text_log() {
			this.messages = new StringBuilder("");
			this.log.set_text("");
		}

		public void insert_text_log(string msg_original) {
			string msg;
			if ((msg_original != "") && (!msg_original.has_suffix("\n"))) {
				msg = msg_original + "\n";
			} else {
				msg = msg_original;
			}

			if (false) {
				// a simple log for debugging purposes
				var file = File.new_for_path(Path.build_filename("/home", Environment.get_user_name(), ".cronopete_log"));
				DataOutputStream dos;
				FileIOStream     os;
				if (file.query_exists()) {
					os = file.open_readwrite();
					os.seek(0, SeekType.END);
					dos = new DataOutputStream(os.output_stream);
				} else {
					dos = new DataOutputStream(file.create(FileCreateFlags.REPLACE_DESTINATION));
				}
				var now = Time.local(time_t());
				dos.put_string("%s: %s".printf(now.to_string(), msg));
			}

			this.messages.append(msg);

			if (this.is_visible) {
				TextIter iter;
				this.log.get_end_iter(out iter);
				this.log.insert_markup(ref iter, msg, msg.length);
				this.mark = this.log.create_mark("end", iter, false);
				this.log_view.scroll_to_mark(this.mark, 0.05, true, 0.0, 1.0);
			}
		}

		public void show_main() {
			this.main_w.show_all();
			this.main_w.present();
			this.tabs.set_current_page(0);
			this.refresh_backup_data();
			this.log.set_text(this.messages.str);
			this.cronopete_settings.set_boolean("show-welcome", false);

			TextIter iter;
			this.log.get_end_iter(out iter);
			this.mark = this.log.create_mark("end", iter, false);
			this.log_view.scroll_to_mark(this.mark, 0.05, true, 0.0, 1.0);
			this.text_status.set_label(this.last_status);
			this.is_visible = true;
		}

		public void refresh_backup_data() {
			string ? volume_id;
			time_t oldest;
			time_t newest;
			uint64 total_space;
			uint64 free_space;
			string ? icon;

			this.backend.get_backup_data(out volume_id, out oldest, out newest, out total_space, out free_space, out icon);
			if (volume_id == null) {
				// TRANSLATORS This text means that the user still has not selected a hard disk where to do the backups
				this.label_disk_id.set_text(_("Not defined"));
			} else {
				this.label_disk_id.set_text(volume_id);
			}
			this.label_oldest.set_text(cronopete.date_to_string(oldest));
			this.label_newest.set_text(cronopete.date_to_string(newest));
			time_t next = newest + this.cronopete_settings.get_uint("backup-period");
			time_t now  = time_t();
			if (next < now) {
				next = now + 600;
			}
			if (this.backend.storage_is_available()) {
				this.label_next.set_text(cronopete.date_to_string(next));
			} else {
				this.label_next.set_text("---");
			}
			if (this.backend.current_status == backup_current_status.IDLE) {
				this.backend_list.sensitive       = true;
				this.change_destination.sensitive = true;
				this.set_options.sensitive        = true;
			} else {
				this.backend_list.sensitive       = false;
				this.change_destination.sensitive = false;
				this.set_options.sensitive        = false;
			}
			this.disk_icon.set_from_icon_name(icon, IconSize.DIALOG);

			// TRANSLATORS This string specifies the available and total disk space in back up drive. Example: 43 GB of 160 GB
			this.label_space.set_text(_("%lld GB of %lld GB").printf((uint64) (free_space + 900000000) / 1000000000, (uint64) (total_space + 900000000) / 1000000000));
			// Adding 900000000 and dividing by 1000000000 allows to round up to the nearest size instead of the lowest one
		}

		[CCode(instance_pos = -1)]
		public void options_callback(Gtk.Button source) {
			var tmp = new c_options(this.main_w);
			this.refresh_backup_data();
			tmp = null;
		}

		[CCode(instance_pos = -1)]
		public bool on_destroy_event(Gtk.Widget o, Gdk.Event e) {
			this.main_w.hide();
			this.is_visible = false;
			return true;
		}

		[CCode(instance_pos = -1)]
		public bool on_delete_event(Gtk.Widget source, Gdk.Event e) {
			this.is_visible = false;
			this.main_w.hide();
			return true;
		}

		[CCode(instance_pos = -1)]
		public void change_disk_callback(Gtk.Button source) {
			// CALL TO THE DISK SELECT CODE IN THE BACKEND
			this.backend.configure_backup_device(this.main_w);
		}

		[CCode(instance_pos = -1)]
		public void about_clicked(Gtk.Button source) {
			var w = new Builder();
			try {
				w.add_from_file(GLib.Path.build_filename(Constants.PKGDATADIR, "about.ui"));
			} catch (GLib.Error e) {
				print("Can't create the about window.\n");
				return;
			}

			var about_w = (AboutDialog) w.get_object("aboutdialog1");
			about_w.set_transient_for(this.main_w);

			about_w.set_version(Constants.VERSION);
			about_w.show();
			about_w.run();
			about_w.hide();
			about_w.destroy();
		}
	}
}
