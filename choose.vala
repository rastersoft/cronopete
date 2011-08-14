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
using Gdk;

class c_choose_disk : GLib.Object {

	private cp_callback parent;
	private string basepath;
	private Builder builder;
	private Dialog choose_w;
	private TreeView disk_list;
	ListStore disk_listmodel;
	private VolumeMonitor monitor;
	private Button ok_button;

	public c_choose_disk(string path, cp_callback p) {
	
		this.parent = p;
		this.basepath=path;
		this.builder = new Builder();
		this.builder.add_from_file(Path.build_filename(this.basepath,"chooser.ui"));
		this.builder.connect_signals(this);

		this.choose_w = (Dialog) this.builder.get_object("disk_chooser");

		this.disk_list = (TreeView) this.builder.get_object("disk_list");
		this.ok_button = (Button) this.builder.get_object("ok_button");
	
		this.disk_listmodel = new ListStore (5, typeof(string), typeof (string), typeof (string), typeof (string), typeof (string));
		this.disk_list.set_model(this.disk_listmodel);
		var crpb = new CellRendererPixbuf();
		crpb.stock_size = IconSize.DIALOG;
		this.disk_list.insert_column_with_attributes (-1, "", crpb , "icon_name", 0);
		this.disk_list.insert_column_with_attributes (-1, "", new CellRendererText (), "text", 1);
		this.disk_list.insert_column_with_attributes (-1, "", new CellRendererText (), "text", 2);
		this.disk_list.insert_column_with_attributes (-1, "", new CellRendererText (), "text", 3);
	
		this.monitor = VolumeMonitor.get();
		this.monitor.mount_added.connect_after(this.refresh_list);
		this.monitor.mount_removed.connect_after(this.refresh_list);
		this.refresh_list();
		this.set_ok();
		
		this.choose_w.show();

		var r=this.choose_w.run();
		if (r==-5) {
			var selected = this.disk_list.get_selection();
			if (selected.count_selected_rows()!=0) {
				TreeModel model;
				TreeIter iter;
				selected.get_selected(out model, out iter);
				GLib.Value val;
				model.get_value(iter,4,out val);
				this.parent.p_backup_path=val.get_string().dup();
			}
		}
		this.choose_w.hide();
		this.choose_w.destroy();
	}

	private void set_ok() {
	
		var selected = this.disk_list.get_selection();
		if (selected.count_selected_rows()!=0) {
			this.ok_button.sensitive=true;
		} else {
			this.ok_button.sensitive=false;
		}
	}

	private void refresh_list() {

		TreeIter iter;
		string tmp;
		Mount mnt;
		File root;
		string path;
		string bpath;
		string ssize;
		bool first;
	
		var volumes = this.monitor.get_volumes();
	
		this.disk_listmodel.clear();
		first = true;
		
		foreach (Volume v in volumes) {		

			mnt=v.get_mount();
			if ((mnt is Mount)==false) {
				continue;
			}

			root=mnt.get_root();
			path = root.get_path();
			bpath = root.get_basename();

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
			
			var info = root.query_filesystem_info("filesystem::type,filesystem::size",null);
			
			this.disk_listmodel.set (iter,0,tmp);
			this.disk_listmodel.set (iter,1,bpath);
			this.disk_listmodel.set (iter,2,info.get_attribute_string("filesystem::type"));
			var size = info.get_attribute_uint64("filesystem::size");
			if (size >= 1000000000) {
				ssize = "%lld GB".printf((size+500000000)/1000000000);
			} else if (size >= 1000000) {
				ssize = "%lld MB".printf((size+500000)/1000000);
			} else if (size >= 1000) {
				ssize = "%lld KB".printf((size+500)/1000);
			} else {
				ssize = "%lld B".printf(size);
			}
			
			this.disk_listmodel.set (iter,3,ssize);
			this.disk_listmodel.set (iter,4,path);
			if (first) {
				this.disk_list.get_selection().select_iter(iter);
				first = false;
			}
		}
		this.set_ok();
	}
	
	[CCode (instance_pos = -1)]
	public bool on_press_event(Widget w , Event v) {

		this.set_ok();
		return false;
	}
	
}
