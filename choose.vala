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


class c_choose_disk : GLib.Object {

	private cp_callback parent;
	private string basepath;
	private Builder builder;
	private Dialog choose_w;
	private TreeView disk_list;
	ListStore disk_listmodel;

	public c_choose_disk(string path, cp_callback p) {
	
		this.parent = p;
		this.basepath=path;
		this.builder = new Builder();
		this.builder.add_from_file(Path.build_filename(this.basepath,"chooser.ui"));

		this.choose_w = (Dialog) this.builder.get_object("disk_chooser");
		this.builder.connect_signals(this);

		this.disk_list = (TreeView) this.builder.get_object("disk_list");
	
		this.disk_listmodel = new ListStore (3, typeof(string), typeof (string), typeof (string));
		this.disk_list.set_model(this.disk_listmodel);
		var crpb = new CellRendererPixbuf();
		crpb.stock_size = IconSize.DIALOG;
		this.disk_list.insert_column_with_attributes (-1, "", crpb , "icon_name", 0);
		this.disk_list.insert_column_with_attributes (-1, "", new CellRendererText (), "text", 1);
		this.disk_list.insert_column_with_attributes (-1, "", new CellRendererText (), "text", 2);
		
		this.refresh_list();
		
		this.choose_w.show();
		int r;
		do {
			r=this.choose_w.run();
			if (r==3) {
				this.refresh_list();
			} else {
				break;
			}
		} while (true);
		this.choose_w.hide();
		this.choose_w.destroy();
	
	}

	private void refresh_list() {

		TreeIter iter;
		string tmp;
		Mount mnt;
		File root;
		string path;
	
		var monitor = VolumeMonitor.get();
		var volumes = monitor.get_volumes();
	
		this.disk_listmodel.clear();
		
		foreach (Volume v in volumes) {		

			mnt=v.get_mount();
			if ((mnt is Mount)==false) {
				continue;
			}

			root=mnt.get_root();
			path = root.get_path();

			this.disk_listmodel.append (out iter);
			
			tmp="";
			foreach (string s in v.get_icon().to_string().split(" ")) {
			
				if (s=="GThemedIcon") {
					continue;
				}
				if (s==".") {
					continue;
				}
				tmp=s;
				break;
			}
			
			GLib.stdout.printf("nombre %s\n",path);
			
			this.disk_listmodel.set (iter,0,tmp);
			this.disk_listmodel.set (iter,1,path);
			this.disk_listmodel.set (iter,2,"");
			
		}
	
	}

}
