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
	public class RestoreCanvas : Gtk.Bin {
		private backup_base backend;
		private GLib.Settings cronopete_settings;

		private Gtk.EventBox box;
		private Gtk.Fixed base_layout;
		private Gtk.DrawingArea drawing;

		private Cairo.ImageSurface base_surface;
		private int screen_w;
		private int screen_h;

		public RestoreCanvas(backup_base backend, GLib.Settings settings) {
			this.backend            = backend;
			this.cronopete_settings = settings;

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
				if (bgformat == "wallpaper") {                                                                                                                                                                                                                                                 // repeat it several times
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
		}

		private bool do_draw(Context cr) {
			cr.set_source_surface(this.base_surface, 0, 0);
			cr.paint();
			return false;
		}

		private bool on_scroll(Gtk.Widget widget, Gdk.EventScroll event) {
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
	}
}
