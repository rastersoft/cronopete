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
using Posix;

[DBus (name = "org.freedesktop.UDisks")]
interface UDisk_if : GLib.Object {
	public abstract void EnumerateDevices(out ObjectPath[] path) throws IOError;
}

[DBus (timeout = 10000000, name = "org.freedesktop.UDisks.Device")]
interface Device_if : GLib.Object {
	public abstract string IdLabel { owned get; }
	public abstract string[] DeviceMountPaths { owned get; }
	public signal void JobChanged(bool job_in_progress,string job_id,uint job_initiated_by_uid,bool job_is_cancellable,double job_percentage);
	public signal void Changed();
	
	public abstract async void FilesystemUnmount(string[]? options) throws IOError;
	public abstract async void FilesystemCreate(string type, string[] options) throws IOError;
	public abstract async void PartitionModify (string type, string label, string[]? options) throws IOError;
	public abstract async void FilesystemMount(string type, string[]? options, out string mount_path) throws IOError;
}


class c_format : GLib.Object {

	public int retval;
	public string? final_path;
	private ObjectPath? device;
	private string? mount_path;
	private string uipath;
	private string? ioerror;
	private string? label;
	private Dialog format_window;
	private bool job_in_progress;
	private string? waiting_for_job;
	private bool job_found;

	public signal void format_ended(int status);
	
	private void show_error(string msg) {

		GLib.stdout.printf("Error: %s\n",msg);
		
		var builder=new Builder();
		builder.add_from_file(Path.build_filename(this.uipath,"format_error.ui"));
		var label = (Label) builder.get_object("msg_error");
		label.set_label(msg);
		var w = (Dialog) builder.get_object("error_dialog");
		w.show_all();
		w.run();
		w.hide();
		w.destroy();

	}

	private bool find_drive(string path_mount) {
	
		ObjectPath[] retval;
	
		try {
			UDisk_if udisk = Bus.get_proxy_sync<UDisk_if> (BusType.SYSTEM, "org.freedesktop.UDisks","/org/freedesktop/UDisks");
			udisk.EnumerateDevices(out retval);
			udisk=null;

			Device_if device2;

			this.device=null;
			this.mount_path=null;
			this.label=null;
			// Find the device which is mounted in the specified path
			foreach (ObjectPath o in retval) {
				device2 = Bus.get_proxy_sync<Device_if> (BusType.SYSTEM, "org.freedesktop.UDisks",o);
				foreach (string s in device2.DeviceMountPaths) {
					if (s == path_mount) {
						this.device=o;
						this.mount_path=path_mount.dup();
						this.label = device2.IdLabel.dup();
						return (true);
					}
				}
			}
		} catch (IOError e) {
			this.show_error(e.message);
		}
		return (false);
	}
	
	private async void remount(string format) {

		Device_if device2;
		
		try {
			device2 = Bus.get_proxy_sync<Device_if> (BusType.SYSTEM, "org.freedesktop.UDisks",this.device);
		} catch (IOError e) {
			this.ioerror=e.message.dup();
			return;
		}

		try {
			yield device2.PartitionModify("131","",null);
		} catch (IOError e) {
			this.retval=-1;
			return;
		}
		
		try {
			string out_path;
			yield device2.FilesystemMount(format,null,out out_path);
			this.final_path=out_path.dup();
		} catch (IOError e) {
			this.ioerror=e.message.dup();
			this.retval=-1;
			return;
		}
		this.retval=0;
	}

	private async void format_drive(string format) {

		if (this.device==null) {
			final_path=null;
			return;
		}

		this.ioerror=null;

		Device_if device2;
		
		try {
			device2 = Bus.get_proxy_sync<Device_if> (BusType.SYSTEM, "org.freedesktop.UDisks",this.device);
		} catch (IOError e) {
			this.ioerror =e.message.dup();
			GLib.stdout.printf("Error %s\n",e.message);
			return;
		}

		try {
			yield device2.FilesystemUnmount(null);
		} catch (IOError e) {
		}
		
		string[] options;
		if ((this.label==null)||(this.label=="")) {
			options = new string[2];
		} else {
			options = new string[3];
			if (this.label.length>16) {
				this.label=this.label.substring(0,16);
			}
			options[2]="label=%s".printf(this.label);
		}			
		options[0]="take_ownership_uid=%d".printf((int)Posix.getuid());
		options[1]="take_ownership_gid=%d".printf((int)Posix.getgid());

		var handler_id = device2.JobChanged.connect((inprogress,jobid,job_init,iscancelable,percentage) => {
			//GLib.stdout.printf("Evento %s %s %d %s %f\n",inprogress ? "activo":"inactivo",jobid,(int)job_init,iscancelable ? "cancelable" : "no cancelable", percentage);
			if ((this.job_found)&&(inprogress==false)) {
				this.job_in_progress=false;
				this.format_drive.callback();
				return;
			}
			if ((this.waiting_for_job==null)||(this.waiting_for_job!=jobid)) {
				return;
			}
			this.waiting_for_job=null;
			this.job_found=true;
		});
		
		try {
			device2.FilesystemCreate.begin(format,options);
			
			this.job_in_progress=true;
			this.job_found=false;
			this.waiting_for_job="FilesystemCreate";
			while(true) {
				if (this.job_in_progress==false) {
					break;
				} else {
					yield;
				}
			}
		} catch (IOError e) {
			this.ioerror=e.message.dup();
			this.retval=-1;
			return;
		}
		device2.disconnect(handler_id);

		yield this.remount(format);
		if (this.retval!=0) {
			return;
		}
		this.retval=0;
		return;
	}

	private async void do_format(string path, string filesystem, string disk_path) {

		if (this.find_drive(disk_path)) {
			var builder2 = new Builder();
			builder2.add_from_file(Path.build_filename(path,"formatting.ui"));
			this.format_window = (Dialog) builder2.get_object("formatting");
			this.retval=2;
			this.format_window.show_all();
			yield this.format_drive("reiserfs");
			if (this.retval!=0) {
				yield this.format_drive("ext4");
			}
			this.format_window.close();
			this.format_window.destroy();
		} else {
			GLib.stdout.printf("Error, can't find disk %s\n",disk_path);
			this.retval=-1;
		}
		if (this.ioerror!=null) {
			this.show_error(this.ioerror);
		}
	}
	public async void run(string path, string filesystem, string disk_path,bool not_writable) {
		
		this.mount_path=null;
		this.device=null;
		this.final_path="";
		this.uipath=path;
		this.ioerror=null;

		string message;
		var builder = new Builder();

		builder.add_from_file(Path.build_filename(path,"format_force.ui"));
		if (not_writable) {
			message = _("The file system %s is not writable, so Cronopete will format it. The optimal file system is ReiserFS, but you can also use Ext3/Ext4 if you prefer.\n\nTo format the disk, click the <i>Format disk</i> button. <b>All the data in the drive will be erased</b>.").printf(filesystem);
		} else if (filesystem=="btrfs") {
			message = _("The file system %s is not valid for Cronopete because, currently, it has several bugs that can put in risk your backups. The optimal file system is ReiserFS, but you can also use Ext3/Ext4 if you prefer.\n\nTo change the file format in the disk, click the <i>Format disk</i> button. <b>All the data in the drive will be erased</b>.").printf(filesystem);
		} else {
			message = _("The file system %s is not valid for Cronopete. The optimal file system is ReiserFS, but you can also use Ext3/Ext4 if you prefer.\n\nTo change the file format in the disk, click the <i>Format disk</i> button. <b>All the data in the drive will be erased</b>.").printf(filesystem);
		}
		builder.connect_signals(this);

		var label = (Label) builder.get_object("label_text");
		label.set_label(message);
				
		var window = (Dialog) builder.get_object("dialog_format");
		
		window.show_all();
		var rv=window.run();
		window.destroy();
		if (rv==1) { // format
			yield this.do_format(path,filesystem,disk_path);
		} else if (rv==0) {
			this.final_path=disk_path.dup();
			this.retval=0;
		} else {
			retval=-1;
		}
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

	public async void run(string path, cp_callback p) {
	
		this.parent = p;
		this.basepath=path;
		this.builder = new Builder();
		this.builder.add_from_file(Path.build_filename(this.basepath,"chooser.ui"));
		this.builder.connect_signals(this);

		this.choose_w = (Dialog) this.builder.get_object("disk_chooser");

		this.disk_list = (TreeView) this.builder.get_object("disk_list");
		this.ok_button = (Button) this.builder.get_object("ok_button");
	
		this.disk_listmodel = new ListStore (5, typeof(Icon), typeof (string), typeof (string), typeof (string), typeof (string));
		this.disk_list.set_model(this.disk_listmodel);
		var crpb = new CellRendererPixbuf();
		crpb.stock_size = IconSize.DIALOG;
		this.disk_list.insert_column_with_attributes (-1, "", crpb , "gicon", 0);
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
		bool not_writable;
		
		do_run=true;
		while (do_run) {
			var r=this.choose_w.run	();
			
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
				var final_path = spath.get_string().dup();
				
				// Reiser3 is the recomended filesystem for cronopete
				not_writable=false;
				if ((fstype == "reiserfs") ||
					(fstype.has_prefix("ext3")) ||
					(fstype.has_prefix("ext4"))) {
						var backup_path=Path.build_filename(final_path,"cronopete");
						var directory2 = File.new_for_path(backup_path);
						// if the media doesn't have the folder "cronopete", try to create it
						if (false==directory2.query_exists()) {
							try {
								// if it's possible to create it, go ahead
								directory2.make_directory_with_parents();
								this.parent.p_backup_path=final_path;
								do_run=false;
								break;
							} catch (IOError e) {
								// if not, the media is not writable by this user, so propose to format it
								not_writable=true;
							}
						} else {
							this.parent.p_backup_path=final_path;
							do_run=false;
							break;
						}
				}
				this.choose_w.hide();

				var w = new c_format();
				yield w.run(this.basepath,fstype,final_path,not_writable);
				if (w.retval==0) {
					this.parent.p_backup_path=w.final_path;
					do_run=false;
					break;
				}
				this.choose_w.show();
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
		//string tmp;
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

			if (fsystem==null) {
				fsystem=_("Unknown FS");
			}
			
			path = root.get_path();
			bpath = root.get_basename();

			this.disk_listmodel.append (out iter);
			
			var tmp = new ThemedIcon.from_names(v.get_icon().to_string().split(" "));
			
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
