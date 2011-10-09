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
using Gee;
using Gtk;
using Gdk;

struct path_filename {
	string original_file;
	string restored_file;
}

class restore_iface : GLib.Object {

	
	private backends backend;
	private double opacity;
	private uint timer;
	private double divisor;
	private double counter;
	private int scr_w;
	private int scr_h;
	
	private EventBox box;
	private FilelistIcons.IconBrowser browser;
	private Gee.List<time_t?>? backups;
	private Fixed base_layout;
	private Gtk.Window mywindow;
	private int pos;
	
	private Button restore;
	private Button do_exit;
	
	private Gee.List<path_filename ?> restore_files;
	private Gee.List<path_filename ?> restore_folders;

	public static int mysort_64(time_t? a, time_t? b) {

		if(a<b) {
			return 1;
		}
		if(a>b) {
			return -1;
		}
		return 0;
	}

	public restore_iface(backends p_backend) {
	
		this.backend=p_backend;
		this.backend.restore_ended.connect(this.restoring_ended);

		this.restore_files = new Gee.ArrayList<path_filename ?>();
		this.restore_folders = new Gee.ArrayList<path_filename ?>();

		this.mywindow = new Gtk.Window();

		this.base_layout = new Fixed();
		this.box = new EventBox();
		this.box.add_events (Gdk.EventMask.SCROLL_MASK|Gdk.EventMask.BUTTON_RELEASE_MASK);
		this.box.add(this.base_layout);
		this.mywindow.add(box);
		
		this.box.scroll_event.connect(this.on_scroll);
		this.box.button_release_event.connect(this.on_click);
		
		this.box.sensitive=true;
		
		this.mywindow.fullscreen();
		this.opacity=0.0;
		this.mywindow.opacity=this.opacity;
		
		this.backups=p_backend.get_backup_list();
		this.backups.sort((CompareFunc)mysort_64);

		var scr=this.mywindow.get_screen();
		this.scr_w=scr.get_width();
		this.scr_h=scr.get_height();

		this.browser=new FilelistIcons.IconBrowser(this.backend,Environment.get_home_dir());
		this.pos=0;
		this.browser.set_backup_time(this.backups[0]);
		
		this.base_layout.add(this.browser);
		this.browser.width_request=scr_w*4/5;
		this.browser.height_request=scr_h*4/5;
		this.base_layout.move(this.browser,scr_w*1/10,scr_h*3/20);

		this.do_exit=new Button.with_label("Exit");
		this.do_exit.clicked.connect(this.exit_restore);
		this.base_layout.add(this.do_exit);

		this.restore=new Button.with_label("Restore");
		this.restore.clicked.connect(this.do_restore);
		this.base_layout.add(this.restore);
		this.base_layout.move(this.restore,500,0);

		this.mywindow.show_all();
		
		this.divisor=25.0;
		this.counter=0.0;
		this.timer=Timeout.add(20,this.timer_show);

	}

	private bool on_click(Gdk.EventButton event) {
		
		GLib.stdout.printf("Click\n");
		return false;
		
	}

	private bool on_scroll(Gdk.EventScroll event) {
	
		if ((event.direction==ScrollDirection.UP)&&(this.pos>0)) {
			this.pos--;
			this.browser.set_backup_time(this.backups[this.pos]);
		}
		if ((event.direction==ScrollDirection.DOWN)&&(this.pos<(this.backups.size-1))) {
			this.pos++;
			this.browser.set_backup_time(this.backups[this.pos]);
		}
		
		return true;
	
	}

	private void exit_restore() {
		
		if (this.timer==0) {
			this.divisor=25.0;
			this.counter=25.0;
			this.timer=Timeout.add(20,this.timer_hide);
		}
	}
	
	private string get_restored_filename(string path, string filename) {
		
		string newfilename="%s.restored".printf(filename);
		int counter=1;
		File fs;
		
		while(true) {
			fs = File.new_for_path(Path.build_filename(path,newfilename));
			if (fs.query_exists()) {
				newfilename="%s.restored.%d".printf(filename,counter);
				counter++;
			} else {
				break;
			}
		}
		
		return newfilename;
	}
	
	public void restoring_ended(backends b, string file_ended, BACKUP_RETVAL rv) {
		
		if (file_ended!="") {
		
			GLib.stdout.printf("Terminado %s\n",file_ended);
			var current_time=time_t();
			var f=File.new_for_path(file_ended);
			f.set_attribute_uint64(FILE_ATTRIBUTE_TIME_MODIFIED,current_time,0,null);
			f.set_attribute_uint64(FILE_ATTRIBUTE_TIME_ACCESS,current_time,0,null);
		}
		
		if (this.restore_files.is_empty) {
			return;
		}
		
		var filename = this.restore_files.get(0);
		this.restore_files.remove_at(0);
		this.backend.restore_file(filename.original_file,this.backups[this.pos],filename.restored_file);
		
	}
	
	private void do_restore() {
		
		Gee.List<string> files;
		Gee.List<string> folders;
		
		this.mywindow.hide();
		
		var path=this.browser.get_current_path();
		
		this.browser.get_selected_items(out files, out folders);
		foreach (string f in files) {
			var element = new path_filename();
			element.original_file=Path.build_filename(path,f);
			element.restored_file=Path.build_filename(path,this.get_restored_filename(path,f));
			this.restore_files.add(element);
		}
		
		
  		foreach (string v in folders) {
		  	var restored_folder = Path.build_filename(path,this.get_restored_filename(path,v));
			this.add_folder_to_restore(Path.build_filename(path,v),restored_folder);
		}
		
		this.restoring_ended(this.backend,"",BACKUP_RETVAL.OK);
		
	}

	private BACKUP_RETVAL add_folder_to_restore(string o_path, string f_path) {
		
		Gee.List<FilelistIcons.file_info ?> files;
		string date;
		string new_opath;
		string new_rpath;
		
		try {
			var dir2 = File.new_for_path(Path.build_filename(f_path));
			dir2.make_directory_with_parents(null);
		} catch (IOError e) {
			if (e is IOError.NO_SPACE) {
				return BACKUP_RETVAL.NO_SPC;
			} else {
				return BACKUP_RETVAL.CANT_CREATE_FOLDER;
			}
		}
		
		if (false==this.backend.get_filelist(o_path,this.backups[this.pos],out files,out date)) {
			return BACKUP_RETVAL.NOT_AVAILABLE;
		}

		foreach (var v in files) {
			if (v.isdir) {
				new_opath = Path.build_filename(o_path,v.name);
				new_rpath = Path.build_filename(f_path,v.name);
				this.add_folder_to_restore(new_opath,new_rpath);
			} else {
				var element = new path_filename();
				element.original_file=Path.build_filename(o_path,v.name);
				element.restored_file=Path.build_filename(f_path,v.name);
				this.restore_files.add(element);
			}
		}
		return BACKUP_RETVAL.OK;
	}

	public bool timer_show() {
	
		if (this.counter<this.divisor) {
			this.counter+=1.0;
			this.mywindow.opacity=this.counter/this.divisor;
			return true;
		} else {
			this.timer=0;
			return false;
		}
	}

	public bool timer_hide() {
		
		if (this.counter>0) {
			this.counter-=1.0;
			this.mywindow.opacity=this.counter/this.divisor;
			return true;
		} else {
			this.mywindow.destroy();
			return false;
		}
	}
}
