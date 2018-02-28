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
	public class RestoreCanvas : Gtk.Container {
		private Gtk.EventBox box;
		private Gtk.Fixed base_layout
		private Gtk.DrawingArea drawing;

		public RestoreCanvas() {
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
		}
	}
}
