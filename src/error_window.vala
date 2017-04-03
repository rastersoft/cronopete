/*
 Copyright 2017 (C) Raster Software Vigo (Sergio Costas)

 This file is part of Cronopete

 Nanockup is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 3 of the License, or
 (at your option) any later version.

 Nanockup is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>. */

using GLib;
using Gee;
using Gtk;
using Gdk;
using Cairo;

public class error_window : GLib.Object {

	private Gtk.Label content;
	private Gtk.Dialog error_window;

	public error_window(string basepath, string title, string error) {
		var w = new Builder();
		w.add_from_file(GLib.Path.build_filename(basepath,"nodisk.ui"));
		this.error_window = (Gtk.Dialog)w.get_object("error_window");
		this.content = (Gtk.Label)w.get_object("error_label");
		this.error_window.title = title;
		this.content.set_text(error);
		this.error_window.show_all();
		this.error_window.run();
		this.error_window.destroy();
	}

}
