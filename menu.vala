/*
 Copyright 2011 (C) Raster Software Vigo (Sergio Costas)

 This file is part of Nanockup

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

class main_menu : GLib.Object {

	private weak TextBuffer log;
	private string basepath;
	private StringBuilder messages;
	
	public main_menu(string path,bool show_log,string log) {

		var w = new Builder();
		int retval=0;
		
		this.basepath=path;
		
		w.add_from_file("%smain.ui".printf(this.basepath));
		
		Notebook tabs = (Notebook) w.get_object("notebook1");
		var main_w = (Dialog) w.get_object("dialog1");
		w.connect_signals(this);
		
		if (show_log) {
			tabs.set_current_page(1);
		} else {
			tabs.set_current_page(0);
		}
		
		this.log = (TextBuffer) w.get_object("textbuffer1");
		this.log.set_text(log,-1);
		main_w.show_all();
		do {
			retval=main_w.run();
		} while (retval!=-4);
		main_w.hide();
		main_w.destroy();
	}
	
}