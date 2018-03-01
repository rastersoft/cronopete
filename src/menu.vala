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
		private Window main_w;
		private Builder builder;
		private Notebook tabs;
		private Label label_disk_id;
		private Label label_oldest;
		private Label label_newest;
		private Label label_next;
		private Label label_space;
		private Label text_status;
		private Image disk_icon;
		private Image img;
		private Gtk.ToggleButton show_in_bar_ch;
		private TextMark mark;
		private TextView log_view;
		private string last_status;
		private Switch enabled_ch;
		private StringBuilder messages;

		private backup_base backend;

		public bool is_visible;
		private GLib.Settings cronopete_settings;

		public c_main_menu(backup_base backend) {
			this.backend            = backend;
			this.cronopete_settings = new GLib.Settings("org.rastersoft.cronopete");
			this.messages           = new StringBuilder("");

			this.builder = new Builder();
			try {
				this.builder.add_from_file(Path.build_filename(Constants.PKGDATADIR, "main.ui"));
			} catch (GLib.Error e) {
				print("Can't create the configuration window. Aborting.\n");
				Posix.exit(48);
			}

			this.main_w = (Window) this.builder.get_object("window1");

			this.log                   = (TextBuffer) this.builder.get_object("textbuffer1");
			this.log_view              = (TextView) this.builder.get_object("textview1");
			this.tabs                  = (Notebook) this.builder.get_object("notebook1");
			this.label_disk_id         = (Label) this.builder.get_object("label_volume");
			this.label_oldest          = (Label) this.builder.get_object("label_oldest_backup");
			this.label_newest          = (Label) this.builder.get_object("label_newest_backup");
			this.label_next            = (Label) this.builder.get_object("label_next_backup");
			this.label_space           = (Label) this.builder.get_object("label_free_space");
			this.disk_icon             = (Image) this.builder.get_object("image_disk");
			this.img                   = (Image) this.builder.get_object("image_disk");
			this.show_in_bar_ch        = (Gtk.ToggleButton) this.builder.get_object("show_in_bar");
			this.text_status           = new fixed_label("", 300);
			this.text_status.ellipsize = Pango.EllipsizeMode.MIDDLE;
			this.text_status.lines     = 3;
			var status_alignment = (Gtk.Alignment) this.builder.get_object("status_frame");
			status_alignment.add(this.text_status);

			this.show_in_bar_ch.notify_property("active");

			(VBox) this.builder.get_object("vbox_switch");

			this.enabled_ch = (Gtk.Switch) this.builder.get_object("switch_main");
			this.enabled_ch.notify_property("active");

			this.is_visible = false;
			this.builder.connect_signals(this);
			this.cronopete_settings.bind("enabled", this.enabled_ch, "active", GLib.SettingsBindFlags.DEFAULT);
			this.cronopete_settings.bind("visible", this.show_in_bar_ch, "active", GLib.SettingsBindFlags.DEFAULT);

			this.backend.send_warning.connect((msg) => {
				this.insert_text_log("WARNING: " + msg);
			});
			this.backend.send_error.connect((msg) => {
				this.insert_text_log("ERROR: " + msg);
			});
			this.backend.send_message.connect((msg) => {
				this.insert_text_log(msg);
			});
			this.backend.send_current_action.connect((msg) => {
				var msg2 = msg.strip();
				if (msg2 != "") {
				    this.set_status(msg2);
				}
			});
		}

		public void set_status(string msg) {
			/* This string shows the current status of Cronopete. It could be
			 *  Status: idle, or Status: copying file... */
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

			this.messages.append(msg);

			if (this.is_visible) {
				TextIter iter;
				this.log.insert_at_cursor(msg, msg.length);
				this.log.get_end_iter(out iter);
				this.mark = this.log.create_mark("end", iter, false);
				this.log_view.scroll_to_mark(this.mark, 0.05, true, 0.0, 1.0);
			}
		}

		public void show_main() {
			this.refresh_backup_data();
			this.log.set_text(this.messages.str);
			this.cronopete_settings.set_boolean("show-welcome", false);
			this.main_w.show_all();
			this.main_w.present();
			this.tabs.set_current_page(0);

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
				// This text means that the user still has not selected a hard disk where to do the backups
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
			this.label_next.set_text(cronopete.date_to_string(next));
			this.disk_icon.set_from_icon_name(icon, IconSize.DIALOG);

			/* This string specifies the available and total disk space in back up drive. Example: 43 GB of 160 GB
			 * Adding 900000000 and dividing by 1000000000 allows to round up to the nearest size instead of the lowest one */
			this.label_space.set_text(_("%lld GB of %lld GB").printf((uint64) (free_space + 900000000) / 1000000000, (uint64) (total_space + 900000000) / 1000000000));
		}

		[CCode(instance_pos = -1)]
		public void options_callback(Button source) {
			var tmp = new c_options(this.main_w);
			this.refresh_backup_data();
			tmp = null;
		}

		[CCode(instance_pos = -1)]
		public bool on_destroy_event(Gtk.Widget o) {
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
		public void change_disk_callback(Button source) {
			// CALL TO THE DISK SELECT CODE IN THE BACKEND
			this.backend.configure_backup_device(this.main_w);
		}

		[CCode(instance_pos = -1)]
		public void about_clicked(Button source) {
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
