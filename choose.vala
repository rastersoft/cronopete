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

class c_format : GLib.Object {

	public int retval;

	public c_format(string path, string filesystem) {
	
		var builder = new Builder();
		builder.add_from_file(Path.build_filename(path,"format.ui"));
		builder.connect_signals(this);
	
		var message = _("The file system %s is acceptable for Cronopete, but not optimal. The best file system is ReiserFS.\n\nTo use the disk with the current file format, click the <i>Accept</i> button.\n\nTo change the file format in the disk, click the <i>Format disk</i> button. <b>All the data in the drive will be erased</b>.").printf(filesystem);
		
		var label = (Label) builder.get_object("label_text");
		label.set_label(message);
		
		var window = (Dialog) builder.get_object("dialog_format");
		
		window.show_all();
		this.retval=window.run();
		window.destroy();

	}
}

class c_format_fat : GLib.Object {

	public int retval;

	public c_format_fat(string path, string filesystem) {
	
		var builder = new Builder();
		builder.add_from_file(Path.build_filename(path,"format_fat.ui"));
		builder.connect_signals(this);
	
		var message = _("The file system %s is not valid for Cronopete. The optimal file system is ReiserFS, but you can also use Ext3/Ext4 if you prefer.\n\nTo change the file format in the disk, click the <i>Format disk</i> button. <b>All the data in the drive will be erased</b>.").printf(filesystem);
		
		var label = (Label) builder.get_object("label_text");
		label.set_label(message);
		
		var window = (Dialog) builder.get_object("dialog_format");
		
		window.show_all();
		this.retval=window.run();
		window.destroy();
	}
}

class c_format_btrfs : GLib.Object {

	public int retval;

	public c_format_btrfs(string path, string filesystem) {
	
		var builder = new Builder();
		builder.add_from_file(Path.build_filename(path,"format_fat.ui"));
		builder.connect_signals(this);
	
		var message = _("The file system %s is not valid for Cronopete because, currently, it has several bugs that can put in risk your backups. The optimal file system is ReiserFS, but you can also use Ext3/Ext4 if you prefer.\n\nTo change the file format in the disk, click the <i>Format disk</i> button. <b>All the data in the drive will be erased</b>.").printf(filesystem);
		
		var label = (Label) builder.get_object("label_text");
		label.set_label(message);
		
		var window = (Dialog) builder.get_object("dialog_format");
		
		window.show_all();
		this.retval=window.run();
		window.destroy();
	}
}

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

		bool do_run;
		
		do_run=true;
		while (do_run) {
			var r=this.choose_w.run();
			if (r!=-5) {
				do_run = false;
				break;
			}

			var selected = this.disk_list.get_selection();
			if (selected.count_selected_rows()!=0) {
				TreeModel model;
				TreeIter iter;
				selected.get_selected(out model, out iter);
				GLib.Value spath;
				GLib.Value stype;
				model.get_value(iter,4,out spath);
				model.get_value(iter,2,out stype);
				var fstype = stype.get_string();
				if (fstype == "reiserfs") { // Reiser3 is the recomended filesystem for cronopete
					this.parent.p_backup_path=spath.get_string().dup();
					do_run=false;
					break;
				}
				
				if ((fstype.has_prefix("ext2")) || (fstype.has_prefix("ext3")) || (fstype.has_prefix("ext4"))) {
					var w = new c_format(this.basepath,fstype);
					if (w.retval==0) {
						this.parent.p_backup_path=spath.get_string().dup();
						do_run=false;
						break;
					}
					continue;
				}
				
				if (fstype=="btrfs") {
					var w = new c_format_btrfs(this.basepath, fstype);
					continue;
				}
				var w = new c_format_fat(this.basepath, fstype);
				continue;
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
		string fsystem;
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
			var info = root.query_filesystem_info("filesystem::type,filesystem::size",null);
			fsystem = info.get_attribute_string("filesystem::type");
			
			if (fsystem=="isofs") {
				continue;
			}
			
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
			
			this.disk_listmodel.set (iter,0,tmp);
			this.disk_listmodel.set (iter,1,bpath);
			this.disk_listmodel.set (iter,2,fsystem);
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
	public bool on_press_event(Gtk.Widget w , Gdk.Event v) {

		this.set_ok();
		return false;
	}
	
}
