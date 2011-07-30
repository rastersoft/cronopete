/*
 Copyright 2011 (C) Raster Software Vigo (Sergio Costas)

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
using Gtk;

class c_options : GLib.Object {

	private cp_callback parent;
	private string basepath;
	private Builder builder;
	private Dialog main_w;

	public c_options(string path, cp_callback p) {
	
		this.parent = p;
		this.basepath=path;
		this.builder = new Builder();
		this.builder.add_from_file(Path.build_filename(this.basepath,"options.ui"));
		
		this.main_w = (Dialog) this.builder.get_object("window1");
		this.builder.connect_signals(this);
		
	}
	
}