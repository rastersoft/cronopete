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
using Gee;
using Gtk;
using Gdk;
using Cairo;

namespace cronopete {
	public class restore_iface : Gtk.Window {
		private backup_base backend;
		Gee.List<backup_element> ? backup_list;

		private RestoreCanvas restore_canvas;
		private Gtk.Label current_date;
		private Gtk.SizeGroup sizegroup;

		private Gtk.Button restore_button;
		private Gtk.Button quit_button;

		private GLib.Settings cronopete_settings;

		private backup_element ? to_restore_backup;
		private string ? to_restore_path;
		private Gee.ArrayList<string> ? to_restore_files;
		private Gee.ArrayList<string> ? to_restore_folders;
		private Gtk.Button to_restore_cancel_button;
		private bool to_restore_cancel;
		private int to_restore_total;
		private int to_restore_restored;

		private Gtk.Window ? to_restore_window;
		private Gtk.ProgressBar ? to_restore_bar_total;
		private Gtk.ProgressBar ? to_restore_bar_working;
		private Gtk.Label ? to_restore_label;
		private string ? to_restore_filename;

		private bool cancel_to_ok;

		public static int mysort_64(backup_element ? a, backup_element ? b) {
			if (a.utc_time < b.utc_time) {
				return 1;
			}
			if (a.utc_time > b.utc_time) {
				return -1;
			}
			return 0;
		}

		public restore_iface(backup_base current_backend) {
			Object(type: Gtk.WindowType.TOPLEVEL);

			this.cronopete_settings = new GLib.Settings("org.rastersoft.cronopete");

			this.to_restore_backup      = null;
			this.to_restore_files       = null;
			this.to_restore_folders     = null;
			this.to_restore_path        = null;
			this.to_restore_window      = null;
			this.to_restore_bar_total   = null;
			this.to_restore_bar_working = null;
			this.to_restore_label       = null;
			this.to_restore_cancel      = false;

			this.backend = current_backend;
			this.backend.ended_restore.connect(this.restore_callback);
			time_t oldest, newest;
			this.backup_list = this.backend.get_backup_list(out oldest, out newest);
			this.backup_list.sort(mysort_64);

			// Create the RESTORE button
			var pic1   = new Gtk.Image.from_icon_name("document-revert", Gtk.IconSize.DND);
			// TRANSLATORS Text for the button that restores the selected files
			var label1 = new Label("<span size=\"xx-large\">" + _("Restore files") + "</span>");
			label1.use_markup = true;
			var container1 = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
			container1.halign = Gtk.Align.CENTER;
			container1.pack_start(pic1, false, false, 0);
			container1.pack_start(label1, false, false, 0);
			this.restore_button = new Gtk.Button();
			this.restore_button.add(container1);
			this.restore_button.clicked.connect(this.do_restore);

			// Create the EXIT button
			var pic2   = new Gtk.Image.from_icon_name("application-exit", Gtk.IconSize.DND);
			// TRANSLATORS Text for the button that allows to exit the restore window
			var label2 = new Label("<span size=\"xx-large\">" + _("Exit") + "</span>");
			label2.use_markup = true;
			var container2 = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
			container2.halign = Gtk.Align.CENTER;
			container2.pack_start(pic2, false, false, 0);
			container2.pack_start(label2, false, false, 0);
			this.quit_button = new Gtk.Button();
			this.quit_button.add(container2);
			this.quit_button.clicked.connect(this.exit_restore);

			// Make a sizegroup to make both buttons have the same width
			this.sizegroup = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
			sizegroup.add_widget(restore_button);
			sizegroup.add_widget(quit_button);

			// current_date is a label that will contain the current date and time
			// of the backup being displayed
			this.current_date = new Label("");

			// button_box will contain the buttons and the current date
			var button_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
			button_box.pack_start(restore_button, false, false, 0);
			button_box.pack_start(this.current_date, true, true, 0);
			button_box.pack_start(quit_button, false, false, 0);

			this.restore_canvas = new RestoreCanvas(this.backend, this.cronopete_settings);
			this.restore_canvas.changed_backup_time.connect(this.changed_backup_time);
			this.restore_canvas.exit_restore.connect(this.exit_restore2);

			// main_box will contain all the widgets
			var main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
			main_box.pack_start(button_box, false, true, 0);
			main_box.pack_start(restore_canvas, true, true, 0);

			this.add(main_box);
			this.fullscreen();
			this.changed_backup_time(0);
			this.show_all();
		}

		private void do_restore() {
			this.cancel_to_ok      = false;
			this.to_restore_cancel = false;
			this.restore_canvas.get_restore_data(out this.to_restore_backup, out this.to_restore_path, out this.to_restore_files, out this.to_restore_folders);
			if ((this.to_restore_files.size == 0) && (this.to_restore_folders.size == 0)) {
				return;
			}
			var builder = new Gtk.Builder();
			try {
				builder.add_from_file(GLib.Path.build_filename(Constants.PKGDATADIR, "restoring.ui"));
			} catch (GLib.Error e) {
				print("Can't create the restore window.\n");
				return;
			}
			this.hide();
			this.to_restore_bar_total           = (Gtk.ProgressBar)builder.get_object("restore_file_progressbar");
			this.to_restore_bar_total.show_text = true;
			this.to_restore_bar_working         = (Gtk.ProgressBar)builder.get_object("restore_progressbar");
			this.to_restore_label         = (Gtk.Label)builder.get_object("restoring_file");
			this.to_restore_window        = (Gtk.Window)builder.get_object("restoring_window");
			this.to_restore_cancel_button = (Gtk.Button)builder.get_object("cancel");
			builder.connect_signals(this);

			this.to_restore_window.show_all();
			this.to_restore_total = 0;
			if (this.to_restore_files != null) {
				this.to_restore_total += this.to_restore_files.size;
			}
			if (this.to_restore_folders != null) {
				this.to_restore_total += this.to_restore_folders.size;
			}
			this.to_restore_restored = -1;
			this.restore_callback(true);
			GLib.Timeout.add(250, this.restore_in_progress);
		}

		public bool restore_in_progress() {
			if (this.to_restore_bar_working != null) {
				this.to_restore_bar_working.pulse();
				return true;
			}
			return false;
		}

		private void restore_callback(bool done_fine) {
			if (this.to_restore_cancel) {
				this.show_end_message(_("Aborted"));
				return;
			}
			if (done_fine == false) {
				this.show_end_message(_("Error while restoring %s").printf(this.to_restore_filename));
				return;
			}
			this.to_restore_restored++;
			this.to_restore_bar_total.fraction = ((double) this.to_restore_restored) / ((double) this.to_restore_total);
			this.to_restore_bar_total.text     = "%d/%d".printf(this.to_restore_restored, this.to_restore_total);
			bool is_file = false;
			this.to_restore_filename = null;
			if ((this.to_restore_files != null) && (this.to_restore_files.size > 0)) {
				this.to_restore_filename = this.to_restore_files.remove_at(0);
				this.to_restore_label.set_label(_("Restoring file %s").printf(this.to_restore_filename));
				is_file = true;
			}
			if (this.to_restore_filename == null) {
				if ((this.to_restore_folders != null) && (this.to_restore_folders.size > 0)) {
					this.to_restore_filename = this.to_restore_folders.remove_at(0);
					this.to_restore_label.set_label(_("Restoring folder %s").printf(this.to_restore_filename));
					is_file = false;
				}
			}
			if (this.to_restore_filename == null) {
				// TRANSLATORS Specifies that a rstoring operation has ended
				this.show_end_message(_("Done"));
				return;
			}

			var final_name = this.to_restore_filename;
			var full_path  = File.new_for_path(GLib.Path.build_filename(this.to_restore_path, final_name));
			if (full_path.query_exists()) {
				int    counter = 0;
				int    pos     = this.to_restore_filename.last_index_of_char('.');
				string fname;
				string extension;
				if (pos == -1) {
					// no extension
					fname     = this.to_restore_filename;
					extension = "";
				} else {
					fname     = this.to_restore_filename.substring(0, pos);
					extension = this.to_restore_filename.substring(pos);
				}
				while (true) {
					if (counter == 0) {
						final_name = "%s.restored%s".printf(fname, extension);
					} else {
						final_name = "%s.restored.%d%s".printf(fname, counter, extension);
					}
					counter++;
					full_path = File.new_for_path(GLib.Path.build_filename(this.to_restore_path, final_name));
					if (full_path.query_exists() == false) {
						break;
					}
				}
			}
			this.backend.restore_file_folder(this.to_restore_backup, this.to_restore_path, this.to_restore_filename, final_name, is_file);
		}

		private void show_end_message(string message) {
			this.to_restore_label.set_label(message);
			this.to_restore_bar_total.hide();
			this.to_restore_bar_working.hide();
			// TRANSLATORS Text for the button in the window that shows a message with the result of a restoring operation, for closing the window
			this.to_restore_cancel_button.set_label(_("OK"));
			this.cancel_to_ok           = true;
			this.to_restore_bar_working = null;
		}

		private void exit_restore(Gtk.Widget emiter) {
			this.exit_restore2();
		}

		private void exit_restore2() {
			this.hide();
			this.destroy();
		}

		private void changed_backup_time(int new_index) {
			var time_now = this.backup_list[new_index].utc_time;
			this.current_date.set_markup("<span size=\"xx-large\">%s</span>".printf(date_to_string(time_now)));
		}

		[CCode(instance_pos = -1)]
		public void on_cancel_restore_clicked(Gtk.Button emitter) {
			if (this.cancel_to_ok) {
				this.to_restore_window.hide();
				this.to_restore_window.close();
				this.to_restore_window = null;
				this.show();
			} else {
				// TRANSLATORS Message shown when the user aborts a restoring operation (when restoring files from a backup to the hard disk)
				this.to_restore_label.set_label(_("Aborting restore operation"));
				this.to_restore_cancel = true;
			}
		}
	}
}
