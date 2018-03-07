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
	/**
	 * Contains the inner canvas with the timeline
	 */
	public class RestoreCanvas : Gtk.Bin {
		private backup_base backend;
		private GLib.Settings cronopete_settings;

		private Gtk.EventBox box;
		private Gtk.Fixed base_layout;
		private Gtk.DrawingArea drawing;

		private Cairo.ImageSurface base_surface;
		private int screen_w;
		private int screen_h;

		private int current_backup;
		private int64 current_z_pos;
		private time_t current_timeline;
		private time_t desired_timeline;

		// file browser coordinates and size
		private double browser_x;
		private double browser_y;
		private double browser_margin;
		private double browser_w;
		private double browser_h;

		// timeline arrows coordinates, to know how to respond to mouse clicks
		private double arrows_x;
		private double arrows_y;
		private double arrows_w;
		private double arrows_h;

		// margin around the file browser
		private int margin_around;

		// scale values for the timeline, to allow to easily paint the current position
		private double scale_x;
		private double scale_y;
		private double scale_w;
		private double scale_h;
		private double timeline_scale_factor;

		// stores the tick callback uid, to know if it is already set
		private uint tick_cb;

		// this stores the last frame time, to now if a new frame must be animated
		private int64 last_time_frame;

		public signal void changed_backup_time(int backup_index);

		// backups and asociated data
		Gee.List<backup_element> ? backup_list;
		time_t oldest;
		time_t newest;

		public RestoreCanvas(backup_base backend, GLib.Settings settings) {
			this.backend            = backend;
			this.cronopete_settings = settings;
			this.backup_list        = this.backend.get_backup_list(out this.oldest, out this.newest);
			this.backup_list.sort(sort_backup_elements_newer_to_older);
			this.current_backup   = 0;
			this.current_z_pos    = 0;
			this.current_timeline = this.backup_list[0].utc_time;
			this.desired_timeline = this.current_timeline;
			this.tick_cb          = 0;
			this.last_time_frame  = 0;

			this.drawing = new DrawingArea();
			// base_layout will be the container of the drawing area where the graphics will be painted
			this.base_layout = new Fixed();
			this.base_layout.add(this.drawing);
			// an event_box is needed to receive the mouse and key events
			this.box = new EventBox();
			this.box.add_events(Gdk.EventMask.SCROLL_MASK | Gdk.EventMask.BUTTON_RELEASE_MASK | Gdk.EventMask.KEY_PRESS_MASK | Gdk.EventMask.KEY_RELEASE_MASK);
			this.box.add(this.base_layout);
			this.box.scroll_event.connect(this.on_scroll);
			this.box.button_release_event.connect(this.on_click);
			this.box.key_press_event.connect(this.on_key_press);
			this.box.key_release_event.connect(this.on_key_release);
			this.box.sensitive = true;
			this.box.draw.connect(this.do_draw);
			this.box.size_allocate.connect(this.size_changed);
			this.add(this.box);
			this.changed_backup_time(this.current_backup);
		}

		private void size_changed(Allocation allocation) {
			if ((this.screen_w != allocation.width) || (this.screen_h != allocation.height)) {
				this.screen_w = allocation.width;
				this.screen_h = allocation.height;
				this.build_background();
			}
		}

		/**
		 * Generates a Cairo surface with the background picture. This will be the current background
		 * image, toned to sepia, the backup scale and the arrows
		 */
		private void build_background() {
			this.base_surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, this.screen_w, this.screen_h);

			bool gnome_found  = false;
			var  list_schemas = GLib.SettingsSchemaSource.get_default();
			if (null != list_schemas.lookup("org.gnome.desktop.background", true)) {
				gnome_found = true;
			}

			var      c_base          = new Cairo.Context(this.base_surface);
			var      tonecolor       = this.cronopete_settings.get_string("toning-color");
			Gdk.RGBA tonecolor_final = Gdk.RGBA();
			Gdk.RGBA bgcolor_final   = Gdk.RGBA();

			tonecolor_final.parse(tonecolor);
			int32 final_r = (int32) (tonecolor_final.red * 255.0);
			int32 final_g = (int32) (tonecolor_final.green * 255.0);
			int32 final_b = (int32) (tonecolor_final.blue * 255.0);

			string bgcolor  = "#7f7f7f7f7f7f";
			string bgstr    = "";
			string bgformat = "";

			if (gnome_found) {
				var stng         = new GLib.Settings("org.gnome.desktop.background");
				var entries_list = stng.list_keys();
				foreach (var v in entries_list) {
					if (v == "primary-color") {
						bgcolor = stng.get_string("primary-color");
					} else if (v == "picture-uri") {
						bgstr = stng.get_string("picture-uri");
					} else if (v == "picture-options") {
						bgformat = stng.get_string("picture-options");
					}
				}
			}

			bgcolor_final.parse(bgcolor);

			int32 r   = (int32) (bgcolor_final.red * 255.0);
			int32 g   = (int32) (bgcolor_final.green * 255.0);
			int32 b   = (int32) (bgcolor_final.blue * 255.0);
			int32 bas = (r * 3 + g * 6 + b) / 10;
			// black will be black, white will be white, and intermediate tones will be sepia
			if (bas < 128) {
				r = (final_r * bas) / 128;
				g = (final_g * bas) / 128;
				b = (final_b * bas) / 128;
			} else {
				r = final_r + (((255 - final_r) * (bas - 128)) / 127);
				g = final_g + (((255 - final_g) * (bas - 128)) / 127);
				b = final_b + (((255 - final_b) * (bas - 128)) / 127);
			}

			c_base.set_source_rgb(((double) r) / 255.0, ((double) g) / 255.0, ((double) b) / 255.0);
			c_base.paint();

			Gdk.Pixbuf ? bgpic = null;
			double px_w = this.screen_w;
			double px_h = this.screen_h;
			try {
				if ((bgstr.length > 6) && (bgstr.substring(0, 7) == "file://")) {
					var tmpfile = GLib.File.new_for_uri(bgstr);
					bgstr = tmpfile.get_path();
				}
				bgpic = new Gdk.Pixbuf.from_file(bgstr);
				px_w  = (double) bgpic.width;
				px_h  = (double) bgpic.height;
				int            x;
				int            y;
				unowned uint8 *data;
				data = bgpic.pixels;

				var has_alpha = bgpic.has_alpha;

				for (y = 0; y < bgpic.height; y++) {
					for (x = 0; x < bgpic.width; x++) {
						r   = *(data);
						g   = *(data + 1);
						b   = *(data + 2);
						bas = (r * 3 + g * 6 + b) / 10;
						// tone to sepia
						if (bas < 128) {
							r = (final_r * bas) / 128;
							g = (final_g * bas) / 128;
							b = (final_b * bas) / 128;
						} else {
							r = final_r + (((255 - final_r) * (bas - 128)) / 127);
							g = final_g + (((255 - final_g) * (bas - 128)) / 127);
							b = final_b + (((255 - final_b) * (bas - 128)) / 127);
						}

						*(data++) = r;
						*(data++) = g;
						*(data++) = b;
						if (has_alpha) {
							data++;
						}
					}
				}
			} catch (GLib.Error v) {
			}

			if (bgpic != null) {
				if (bgformat == "wallpaper") {
					// repeat it several times
					double l1;
					double l2;
					double s1 = 0.0;
					double s2 = 0.0;
					if (px_w > this.screen_w) {
						s1 = (this.screen_w - px_w) / 2.0;
					}
					if (px_h > this.screen_h) {
						s2 = (this.screen_h - px_h) / 2.0;
					}
					for (l2 = s2; l2 < this.screen_h; l2 += px_h) {
						for (l1 = s1; l1 < this.screen_w; l1 += px_w) {
							Gdk.cairo_set_source_pixbuf(c_base, bgpic, l1, l2);
							c_base.paint();
						}
					}
				} else if (bgformat == "centered") {
					double s1 = 0.0;
					double s2 = 0.0;
					s1 = (this.screen_w - px_w) / 2.0;
					s2 = (this.screen_h - px_h) / 2.0;
					Gdk.cairo_set_source_pixbuf(c_base, bgpic, s1, s2);
					c_base.paint();
				} else if ((bgformat == "scaled") || (bgformat == "spanned")) {
					c_base.save();
					double new_w = px_w * (this.screen_h / px_h);
					double new_h = px_h * (this.screen_w / px_w);
					if (new_w > this.screen_w) {
						// width is the limiting factor
						double factor = screen_w / px_w;
						c_base.scale(factor, factor);
						Gdk.cairo_set_source_pixbuf(c_base, bgpic, 0, (this.screen_h - new_h) / (2.0 * factor));
					} else {
						// height is the limiting factor
						double factor = screen_h / px_h;
						c_base.scale(factor, factor);
						Gdk.cairo_set_source_pixbuf(c_base, bgpic, (this.screen_w - new_w) / (2.0 * factor), 0);
					}
					c_base.paint();
					c_base.restore();
				} else if (bgformat == "stretched") {
					c_base.save();
					double factor = screen_h / px_h;
					c_base.scale(screen_w / px_w, factor);
					Gdk.cairo_set_source_pixbuf(c_base, bgpic, 0, 0);
					c_base.paint();
					c_base.restore();
				} else if (bgformat == "zoom") {
					c_base.save();
					double new_w = px_w * (this.screen_h / px_h);
					double new_h = px_h * (this.screen_w / px_w);
					if (new_h > this.screen_h) {
						double factor = screen_w / px_w;
						c_base.scale(factor, factor);
						Gdk.cairo_set_source_pixbuf(c_base, bgpic, 0, (this.screen_h - new_h) / (2.0 * factor));
					} else {
						double factor = screen_h / px_h;
						c_base.scale(factor, factor);
						Gdk.cairo_set_source_pixbuf(c_base, bgpic, (this.screen_w - new_w) / (2.0 * factor), 0);
					}
					c_base.paint();
					c_base.restore();
				}
			}

			double scale = this.screen_w / 2800.0;

			this.margin_around = this.screen_h / 20;
			// Browser border
			this.browser_x      = this.screen_w * 0.1;
			this.browser_y      = this.margin_around;
			this.browser_margin = this.screen_h / 8.0;
			this.browser_w      = this.screen_w * 4.0 / 5.0;
			this.browser_h      = this.screen_h - this.browser_y - this.browser_margin - this.margin_around;
			double scale2 = (this.screen_w - 60.0 - 100.0 * scale) / 2175.0;
			c_base.save();
			c_base.scale(scale2, scale2);

			// arrows
			var arrows_pic = new Cairo.ImageSurface.from_png(GLib.Path.build_filename(Constants.PKGDATADIR, "arrows.png"));
			this.arrows_x = (this.browser_x + this.browser_w) - 256.0 * scale2;
			this.arrows_y = this.browser_y / 2.0;
			this.arrows_w = 256.0 * scale2;
			this.arrows_h = 150.0 * scale2;
			c_base.set_source_surface(arrows_pic, this.arrows_x / scale2, this.arrows_y / scale2);
			c_base.paint();
			c_base.restore();

			// timeline
			this.scale_x = 0;
			this.scale_y = this.browser_y;
			this.scale_w = this.screen_w / 28.0;
			this.scale_h = this.browser_h + this.browser_margin;

			this.timeline_scale_factor = this.scale_h / (this.newest - this.oldest);

			double last_pos_y = -1;
			double pos_y      = this.scale_y + this.scale_h;
			double new_y;

			var    incval = this.scale_w / 5.0;
			double nw     = this.scale_w * 3.0 / 5.0;
			this.scale_x += incval / 2.0;

			c_base.set_source_rgba(0, 0, 0, 0.6);
			this.rounded_rectangle(c_base, this.scale_x, this.scale_y - incval, this.scale_w, this.scale_h + 2.0 * incval, 2.0 * incval);
			c_base.fill();

			c_base.set_source_rgb(1, 1, 1);
			c_base.set_line_width(1);

			for (var i = 0; i < this.backup_list.size; i++) {
				new_y = pos_y - this.timeline_scale_factor * (this.backup_list[i].utc_time - this.oldest);
				if (new_y - last_pos_y < 2) {
					continue;
				}
				last_pos_y = new_y;
				c_base.move_to(this.scale_x + incval, new_y);
				c_base.rel_line_to(nw, 0);
				c_base.stroke();
			}
		}

		public void rounded_rectangle(Cairo.Context context, double x, double y, double w, double h, double r) {
			context.move_to(x + r, y);
			context.line_to(x + w - r, y);
			context.curve_to(x + w, y, x + w, y, x + w, y + r);
			context.line_to(x + w, y + h - r);
			context.curve_to(x + w, y + h, x + w, y + h, x + w - r, y + h);
			context.line_to(x + r, y + h);
			context.curve_to(x, y + h, x, y + h, x, y + h - r);
			context.line_to(x, y + r);
			context.curve_to(x, y, x, y, x + r, y);
		}

		private bool do_draw(Context cr) {
			cr.set_source_surface(this.base_surface, 0, 0);
			cr.paint();
			// Paint the timeline index
			double pos_y = this.scale_y + this.scale_h;
			cr.set_source_rgb(1, 0, 0);
			cr.set_line_width(3);
			cr.move_to(this.scale_x, pos_y - this.timeline_scale_factor * (this.current_timeline - this.oldest));
			cr.rel_line_to(this.scale_w, 0);
			cr.stroke();

			// Paint the windows
			double ox;
			double oy;
			double ow;
			double oh;
			double s_factor;
			int64  z_offset = (1000 - (this.current_z_pos % 1000)) % 1000;
			int    z_index  = (int) (this.current_z_pos / 1000);
			int    last     = 0;
			if (z_offset != 0) {
				z_index++;
			}
			if (z_offset >= 200) {
				last = -1;
			}
			cr.set_line_width(1.5);
			cr.set_source_rgb(0.2, 0.2, 0.2);
			for (int i = 9; i >= last; i--) {
				if (((z_index + i) < 0) || ((z_index + i) >= this.backup_list.size)) {
					continue;
				}
				var z2 = z_offset + i * 1000;
				this.transform_coords(z2, out ox, out oy, out ow, out oh, out s_factor);

				cr.select_font_face("Sans", FontSlant.NORMAL, FontWeight.BOLD);
				cr.set_font_size(18.0 * s_factor);
				var date = cronopete.date_to_string(this.backup_list[z_index + i].utc_time);

				Cairo.TextExtents extents;
				cr.text_extents(date, out extents);
				cr.set_source_rgb(1, 1, 1);
				double final_add = 4.0 * s_factor;
				cr.rectangle(ox, oy - 2 * final_add - extents.height, ow, oh + 2 * final_add + extents.height);
				cr.fill();
				cr.set_source_rgb(0.0, 0.0, 0.0);
				cr.rectangle(ox, oy - 2 * final_add - extents.height, ow, oh + 2 * final_add + extents.height);
				cr.stroke();
				cr.move_to(ox + (ow - extents.width + extents.x_bearing) / 2, oy - extents.height - extents.y_bearing - final_add);

				cr.show_text(date);
			}
			return false;
		}

		private void transform_coords(double z, out double ox, out double oy, out double ow, out double oh, out double s_factor) {
			double eyedist = 2500.0;

			ox       = (this.browser_x * eyedist + (z * ((double) this.screen_w) / 2)) / (z + eyedist);
			oy       = ((this.browser_margin) * eyedist) / (z + eyedist);
			ow       = (this.browser_w * eyedist) / (z + eyedist);
			oh       = (this.browser_h * eyedist) / (z + eyedist);
			oy      += this.browser_y;
			s_factor = eyedist / (z + eyedist);
		}

		private bool tick_callback(Gtk.Widget widget, Gdk.FrameClock clock) {
			var lt = clock.get_frame_time();
			if ((lt - this.last_time_frame) < 50000) {
				// keep the framerate at 20 FPS
				return true;
			}
			int64 desired_z_pos = 1000 * ((int64) this.current_backup);
			this.last_time_frame  = lt;
			this.current_timeline = (2 * this.current_timeline + this.desired_timeline) / 3;
			time_t dif_timeline;
			if (this.current_timeline > this.desired_timeline) {
				dif_timeline = this.current_timeline - this.desired_timeline;
			} else {
				dif_timeline = this.desired_timeline - this.current_timeline;
			}
			if (dif_timeline < 2) {
				this.current_timeline = this.desired_timeline;
			}
			this.current_z_pos = (2 * this.current_z_pos + desired_z_pos) / 3;
			if (((this.current_z_pos - desired_z_pos).abs()) < 20) {
				this.current_z_pos = desired_z_pos;
			}
			this.queue_draw();
			if ((this.desired_timeline == this.current_timeline) && (this.current_z_pos == desired_z_pos)) {
				this.tick_cb = 0;
				return false;
			} else {
				return true;
			}
		}

		private bool on_scroll(Gtk.Widget widget, Gdk.EventScroll event) {
			if ((event.direction == ScrollDirection.UP) && (this.current_backup > 0)) {
				this.go_prev_backup();
			}
			if ((event.direction == ScrollDirection.DOWN) && (this.current_backup < (this.backup_list.size - 1))) {
				this.go_next_backup();
			}
			return false;
		}

		private bool on_click(Gtk.Widget widget, Gdk.EventButton event) {
			return false;
		}

		private bool on_key_press(Gtk.Widget widget, Gdk.EventKey event) {
			return false;
		}

		private bool on_key_release(Gtk.Widget widget, Gdk.EventKey event) {
			return false;
		}

		private void go_prev_backup() {
			if (this.current_backup > 0) {
				this.current_backup--;
				this.desired_timeline = this.backup_list[this.current_backup].utc_time;
				this.changed_backup_time(this.current_backup);
				if (this.tick_cb == 0) {
					this.tick_cb = this.add_tick_callback(this.tick_callback);
				}
				return;
			}
		}

		private void go_next_backup() {
			if (this.current_backup < (this.backup_list.size - 1)) {
				this.current_backup++;
				this.desired_timeline = this.backup_list[this.current_backup].utc_time;
				this.changed_backup_time(this.current_backup);
				if (this.tick_cb == 0) {
					this.tick_cb = this.add_tick_callback(this.tick_callback);
				}
				return;
			}
		}
	}
}
