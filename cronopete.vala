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
using Posix;
using Gee;
using Gtk;
using Gdk;
using Cairo;
using Gsl;

enum SystemStatus { IDLE, BACKING_UP, ABORTING, ENDED }
enum BackupStatus { STOPPED, ALLFINE, WARNING, ERROR }


class cp_callback : GLib.Object, callbacks {

	private StatusIcon trayicon;
	private SystemStatus backup_running;
	private BackupStatus current_status;
	private double angle;
	private int size;
	private unowned Thread <void *> b_thread;
	private uint main_timer;
	private uint refresh_timer;
	private StringBuilder messages;
	private string basepath;
	private Menu menuSystem;
	private string last_backup;
	private nanockup? basedir;
	private c_main_menu main_menu;
	private bool backup_pending;
	private bool backup_forced;
	private time_t next_backup;
	private uint cur_period;
	private uint new_period;
	private bool tooltip_changed;
	private string tooltip_value;
	
	public restore_iface restore_w;
	
	// Configuration data

	private bool skip_hiden_at_home;
	private Gee.List<string> origin_path_list;
	private Gee.List<string> exclude_path_list;
	private string backup_path;
	//private bool configuration_read;
	private bool _active;
	private backends? backend;
	public bool active {
		get {
			return this._active;
		}
		
		set {
			this._active=value;
			this.write_configuration();
			this.repaint(this.size);
			this.status_tooltip();
			if (this._active) {
				// Idle is the status of Cronopete when is doing nothing
				if (this.backup_pending) {
					this.timer_f();
				}
			}
		}
	}
	
	public string p_backup_path {
	
		get {
			return this.backup_path;
		}
		
		set {
			this.backup_path=value;
			this.write_configuration();
			this.backend=new usbhd_backend(value);
			this.backend.status.connect(this.refresh_status);
			this.refresh_status(null);
		}
	}

	public void get_path_list(out Gee.List<string> origin, out Gee.List<string> exclude, out bool backup_hiden_ah, out uint period) {
	
		origin=this.origin_path_list;
		exclude=this.exclude_path_list;
		if (this.skip_hiden_at_home) {
			backup_hiden_ah=false;
		} else {
			backup_hiden_ah=true;
		}
		period=this.new_period;
	}
	
	public void set_path_list(Gee.List<string>origin, Gee.List<string>exclude, bool backup_hiden_ah, uint period) {
		
		this.origin_path_list.clear();
		foreach (string s in origin) {
			this.origin_path_list.add(s);
		}
		this.exclude_path_list.clear();
		foreach (string s in exclude) {
			this.exclude_path_list.add(s);
		}
		if (backup_hiden_ah) {
			this.skip_hiden_at_home=false;
		} else {
			this.skip_hiden_at_home=true;
		}
		
		this.new_period=period;
		
	}

	public void refresh_status(usbhd_backend? b) {
	
		this.repaint(this.size);
		this.status_tooltip();
		this.main_menu.refresh_backup_data();
		if ((this._active) && (this.backend.available) && (this.backup_pending)) {
			this.timer_f();
		}
	}

	public cp_callback(string path) {
	
		this.messages = new StringBuilder("");
		this.backup_running = SystemStatus.IDLE;
		this.current_status = BackupStatus.STOPPED;
		this.angle = 0.0;
		this.size = 0;
		this.refresh_timer = 0;
		//this.configuration_read = false;
		this.backup_pending=false;
		this.backup_forced=false;
		this.tooltip_value="";
		this.new_period=3600;
		this.read_configuration();

		this.backend=new usbhd_backend(this.backup_path);
		this.backend.status.connect(this.refresh_status);
		
		this.fill_last_backup();

		this.basepath=path;
	
		this.basedir = null;
		this.main_menu = new c_main_menu(this.basepath,this);
	
		this.trayicon = new StatusIcon();
		this.trayicon.size_changed.connect(this.repaint);
		this.trayicon.set_visible(true);
		this.trayicon.popup_menu.connect(this.menuSystem_popup);
		this.trayicon.activate.connect(this.menuSystem_popup);
		this.refresh_status(null);
		this.set_tooltip (_("Idle"));
		// wait five minutes after being launched before doing the backup
		int init_delay=300;
		this.cur_period=init_delay;
		this.next_backup=init_delay+time_t();
		init_delay*=1000;
		this.main_timer=Timeout.add(init_delay,this.timer_f);
	}

	private void fill_last_backup() {
	
		if (this.backend==null) {
			this.last_backup=_("Latest backup: %s").printf(_("Not defined"));
			return;
		}

		var backups = this.backend.get_backup_list();
		if (backups==null) {
			this.last_backup=_("Latest backup: %s").printf(_("None"));
			return;
		}
		
		time_t lastb=0;
		foreach (time_t t in backups) {
			if (t>lastb) {
				lastb=t;
			}
		}
		if (lastb==0) {
			this.last_backup=_("Latest backup: %s").printf(_("None"));
			return;
		}
		var lb = new DateTime.from_unix_local(lastb);
		this.last_backup = _("Latest backup: %s").printf(lb.format("%x %X"));
	}

	public void PixbufDestroyNotify (uint8* pixels) {
		delete pixels;	
	}

	public void set_tooltip(string? message, bool backup_thread=false) {

		if (backup_thread) {
			// this function can be called both from the main thread and the backup thread, so is mandatory to take precautions
			lock (this.tooltip_value) {
				if (message==null) {
					this.tooltip_value="";
				} else {
					this.tooltip_value=message.dup();
				}
				this.tooltip_changed=true;
			}
		} else {
			lock (this.tooltip_value) {
				if (message==null) {
					this.trayicon.set_tooltip_text (this.tooltip_value);
					this.main_menu.set_status(this.tooltip_value);
					this.tooltip_changed=false;
				} else {
					this.trayicon.set_tooltip_text (message);
					this.main_menu.set_status(message);
				}
			}
		}
	}

	public bool timer_f() {
	
		if (this.tooltip_changed) {
				this.set_tooltip(null);
		}
	
		if (this.backup_running==SystemStatus.IDLE) {
		
			if (this.cur_period!=this.new_period) {
				this.cur_period=this.new_period;
				if (this.main_timer!=0) {
					Source.remove(this.main_timer);
				}
				this.main_timer=Timeout.add(this.cur_period*1000,this.timer_f);
			}
	
			this.next_backup=this.cur_period+time_t();
		
			if (((this._active==false)||(this.backend.available==false))&&(this.backup_forced==false)) {
				this.backup_pending=true;
				return true;
			}
			
			this.backup_pending=false;
			
			this.backup_running=SystemStatus.BACKING_UP;
			b_thread=Thread.create <void *>(this.do_backup, false);
			if (this.refresh_timer!=0) {
				Source.remove(this.refresh_timer);
			}
			this.refresh_timer=Timeout.add(20,this.timer_f);
			
		} else if (this.backup_running==SystemStatus.ENDED) {
			this.backup_forced=false;
			this.backup_running=SystemStatus.IDLE;
			if ((this.current_status==BackupStatus.ALLFINE)||(this.current_status==BackupStatus.WARNING)) {
				this.fill_last_backup();
				this.set_tooltip(_("Idle"));
			}
			if (this.current_status==BackupStatus.ALLFINE) {
				this.current_status=BackupStatus.STOPPED;
			}
			
			if (this.refresh_timer!=0) {
				Source.remove(this.refresh_timer);
				this.refresh_timer=0;
			}
		}

		this.repaint(this.size);
		this.angle-=0.20;
		this.angle%=120.0*Gsl.MathConst.M_PI;
		
		if (this.backup_running==SystemStatus.ABORTING) {
			return false;
		} else {
			return true;
		}
	}

	private void status_tooltip() {
		if (this.backend.available==false) {
			this.set_tooltip(_("Storage not available"));
		} else {
			if (this._active) {
				this.set_tooltip(_("Idle"));
			} else {
				this.set_tooltip(_("Backup disabled"));
			}
		}
	}

	public bool repaint(int size) {
	
		if (size==0) {
			return false;
		}
	
		this.size = size;
	
		var canvas = new Cairo.ImageSurface(Cairo.Format.ARGB32,size,size);
		var ctx = new Cairo.Context(canvas);
		
		ctx.scale(size,size);

		if (this.backend.available==false) {
			ctx.set_source_rgb(1,0,0);
		} else {
			if ((this._active)||(this.backup_forced)) {
				switch (this.current_status) {
				case BackupStatus.STOPPED:
					ctx.set_source_rgb(1,1,1);
				break;
				case BackupStatus.ALLFINE:
					ctx.set_source_rgb(0,1,0);
				break;
				case BackupStatus.WARNING:
					ctx.set_source_rgb(1,0.7,0);
				break;
				case BackupStatus.ERROR:
					ctx.set_source_rgb(1,0,0);
				break;
				}
			} else {
				ctx.set_source_rgb(1,0.5,0);
			}
		}
		ctx.set_line_width(0.0);
		ctx.move_to(0.0,0.45);
		ctx.line_to(0.4,0.45);
		ctx.line_to(0.2,0.625);
		ctx.close_path();
		ctx.fill();
		ctx.arc(0.54,0.5,0.34,(double)Gsl.MathConst.M_PI,-(double)(Gsl.MathConst.M_PI*6.0/5.0));
		ctx.set_line_width(0.11);
		ctx.stroke();
		ctx.translate(0.54,0.5);
		ctx.set_line_width(0.08);
		ctx.save();
		ctx.rotate(this.angle);
		ctx.move_to(0,0.02);
		ctx.line_to(0,-0.25);
		ctx.stroke();
		ctx.restore();
		ctx.save();
		ctx.rotate(this.angle/15);
		ctx.move_to(0,0.02);
		ctx.line_to(0,-0.16);
		ctx.restore();
		ctx.stroke();
		
		uint8 *data_icon=new uint8[size*size*4];
		uint8 *p1=data_icon;
		uint8 *p2=canvas.get_data();
		int counter;
		
		int max=size*size;
		for(counter=0;counter<max;counter++) {
			// R and B channels are swapped in Cairo and Pixbuf areas
			*p1    =*(p2+2);
			*(p1+1)=*(p2+1);
			*(p1+2)=*p2;
			*(p1+3)=*(p2+3);
			p1+=4;
			p2+=4;
		}
		
		var pix=new Pixbuf.from_data((uint8[])data_icon,Gdk.Colorspace.RGB,true,8,size,size,size*4,PixbufDestroyNotify);
		this.trayicon.set_from_pixbuf(pix);
		return true;
	}


	private void menuSystem_popup() {
	
		this.menuSystem = new Menu();

		this.fill_last_backup();
		var menuDate = new MenuItem.with_label(this.last_backup);

		menuDate.sensitive=false;
		menuSystem.append(menuDate);
		
		MenuItem menuBUnow;
		if (this.backup_running==SystemStatus.IDLE) {
			menuBUnow = new MenuItem.with_label(_("Back Up Now"));
			menuBUnow.activate.connect(backup_now);
		} else {
			menuBUnow = new MenuItem.with_label(_("Stop Backing Up"));
			menuBUnow.activate.connect(stop_backup);
		}
		this.menuSystem.append(menuBUnow);

		menuBUnow.sensitive=this.backend.available;

		var menuEnter = new MenuItem.with_label(_("Restore files"));
		menuEnter.activate.connect(enter_clicked);
		menuSystem.append(menuEnter);
		if (this.backend.available) {
			var list = this.backend.get_backup_list ();
			if ((list==null)||(list.size<=0)) {
				menuEnter.sensitive=false;
			} else {
				menuEnter.sensitive=true;
			}
		} else {
			menuEnter.sensitive=false;
		}
		
		var menuBar = new MenuItem();
		menuSystem.append(menuBar);
		
		var menuMain = new MenuItem.with_label(_("Open Cronopete Preferences..."));
		menuMain.activate.connect(main_clicked);
		menuSystem.append(menuMain);
		
		var menuBar2 = new MenuItem();
		menuSystem.append(menuBar2);
		
		var menuAbout = new ImageMenuItem.from_stock(Stock.ABOUT, null);
		menuAbout.activate.connect(about_clicked);
		this.menuSystem.append(menuAbout);
	
		menuSystem.show_all();
	
		this.menuSystem.popup(null,null,this.trayicon.position_menu,2,Gtk.get_current_event_time());
	
	}
	
	
	public void backup_now() {
	
		if (this.backup_running==SystemStatus.IDLE) {
			if (this.refresh_timer>0) {
				Source.remove(this.refresh_timer);
			}
			if (this.main_timer>0) {
				Source.remove(this.main_timer);
				this.main_timer=Timeout.add(3600000,this.timer_f);
			}
			if (this._active==false) {
				this.backup_forced=true;
			}
			this.timer_f();
		}
	}
	
	public void stop_backup() {
	
		if ((this.backup_running==SystemStatus.BACKING_UP)&&(this.basedir!=null)) {
			this.backup_forced=false;
			this.basedir.abort_backup();
		}
	
	}
	
	public void about_clicked() {
		
		var w = new Builder();
		
		w.add_from_file(GLib.Path.build_filename(this.basepath,"about.ui"));

		var about_w = (Dialog)w.get_object("aboutdialog1");
		
		about_w.show();
		about_w.run();
		about_w.hide();
		about_w.destroy();
		
	}
	
	public void enter_clicked() {

		if (this.backend.available) {
			this.restore_w=new restore_iface(this.backend,this.basepath);
		}
	}
	
	public void main_clicked() {
	
		if ((this.current_status==BackupStatus.WARNING)||(this.current_status==BackupStatus.ERROR)) {
			this.main_menu.show_main(true,this.messages.str);
		} else {
			this.main_menu.show_main(false,this.messages.str);
		}
	}
	
	public void backup_folder(string dirpath) {
		
		var msg = _("Backing up folder %s\n").printf(dirpath);
		this.set_tooltip(msg,true);
		//this.show_message(msg);
	}
	
	public void backup_file(string filepath) {
		//GLib.stdout.printf("Backing up file %s\n",filepath);
	}
	
	public void backup_link_file(string filepath) {
		//GLib.stdout.printf("Linking file %s\n",filepath);
	}
	
	public void warning_link_file(string o_filepath) {
		//GLib.stdout.printf("Can't link file %s to %s\n",o_filepath,d_filepath);
	}
	
	public void error_copy_file(string filepath) {
		this.current_status=BackupStatus.WARNING;
		this.show_message(_("Can't copy file %s\n").printf(filepath));
	}
	
	public void error_access_directory(string dirpath) {
		this.current_status=BackupStatus.WARNING;
		this.show_message(_("Can't access directory %s\n").printf(dirpath));
	}
	
	public void error_create_directory(string dirpath) {
		this.current_status=BackupStatus.WARNING;
		this.show_message(_("Can't create directory %s\n").printf(dirpath));
	}
	
	public void excluding_folder(string dirpath) {
		//GLib.stdout.printf("Excluding folder %s\n",dirpath);
	}
	
	public void show_message(string msg) {
	
		this.messages.append(msg);
		this.main_menu.insert_log(msg,false);
	}
	
	private void* do_backup() {

		int retval;

		this.basedir = new nanockup(this,this.backend);
		
		this.messages = new StringBuilder(_("Starting backup\n"));
		this.main_menu.insert_log(this.messages.str,true);
		
		this.current_status=BackupStatus.ALLFINE;
		
		basedir.set_config(this.origin_path_list,this.exclude_path_list,this.skip_hiden_at_home);
		this.set_tooltip(_("Erasing old backups"));
		this.basedir.delete_old_backups();
		
		retval=basedir.do_backup();
		this.backup_running=SystemStatus.ENDED;
		switch (retval) {
		case 0:
		break;
		case -1:
			this.current_status=BackupStatus.WARNING;
		break;
		case -6:
			this.set_tooltip (_("Backup aborted"));
			this.current_status=BackupStatus.ERROR;
		break;
		case -7:
			this.set_tooltip (_("Can't do backup; disk is too small"));
			this.current_status=BackupStatus.ERROR;
		break;
		default:
			this.set_tooltip (_("Can't do backup"));
			this.current_status=BackupStatus.ERROR;
		break;
		}
		this.basedir=null;
		return null;
	}
	
	public int write_configuration() {

		try {
			FileOutputStream file_write;
	
			var home=Environment.get_home_dir();
	
			var config_file = File.new_for_path (GLib.Path.build_filename(home,".cronopete.cfg"));
	
			try {
				file_write=config_file.replace(null,false,0,null);
			} catch {
				return -2;
			}
	
			var out_stream = new DataOutputStream (file_write);
		
			if (this.skip_hiden_at_home==false) {
				out_stream.put_string("backup_hiden_at_home\n",null);
			}
		
			if (this._active==true) {
				out_stream.put_string("active\n",null);
			}
		
			if (this.backup_path!="") {
				out_stream.put_string("backup_directory %s\n".printf(this.backup_path),null);
			}
		
			out_stream.put_string("backup_period %d\n".printf((int)this.new_period));
		
			foreach (string str in this.origin_path_list) {
				out_stream.put_string("add_directory %s\n".printf(str),null);
			}
			foreach (string str in this.exclude_path_list) {
				out_stream.put_string("exclude_directory %s\n".printf(str),null);
			}
		} catch (IOError e) {
		
		}		
		return 0;
	}
	
	private int read_configuration() {
		
		/****************************************************************************************
		 * This function will read the configuration from the file ~/.cronopete.cfg             *
		 * If not, it will use that file to get the configuration                               *
		 * Returns:                                                                             *
		 *   0: on success                                                                      *
		 *  -1: the config file doesn't exists                                                  *
		 *  -2: can't read the config file                                                      *
		 *  +N: parse error at line N in config file                                            *			 
		 ****************************************************************************************/
	
		this.origin_path_list = new Gee.ArrayList<string>();
		this.exclude_path_list = new Gee.ArrayList<string>();
		this.backup_path = "";
		this.skip_hiden_at_home = true;
		this._active = false;
		this.new_period=3600;

		bool failed=false;
		FileInputStream file_read;
		
		string home=Environment.get_home_dir();
		var config_file = File.new_for_path (GLib.Path.build_filename(home,".cronopete.cfg"));
		
		if (!config_file.query_exists (null)) {
			this.origin_path_list.add(home);
			this.skip_hiden_at_home = false;
			return -1;
		}

		try {
			file_read=config_file.read(null);
		} catch {
			return -2;
		}
		var in_stream = new DataInputStream (file_read);
		string line;
		int line_counter=0;

		while ((line = in_stream.read_line (null, null)) != null) {
			line_counter++;
			
			// ignore comments
			if (line[0]=='#') {
				continue;
			}
			
			// remove unwanted blank spaces
			line.strip();

			// ignore empty lines				
			if (line.length==0) {
				continue;
			}
			
			if (line.has_prefix("add_directory ")) {
				this.origin_path_list.add(line.substring(14).strip());
				continue;
			}
			
			if (line.has_prefix("exclude_directory ")) {
				this.exclude_path_list.add(line.substring(18).strip());
				continue;
			}
			
			if (line.has_prefix("backup_directory ")) {
				this.backup_path=line.substring(17).strip();
				continue;
			}
			
			if (line=="backup_hiden_at_home") {
				this.skip_hiden_at_home=false;
				continue;
			}
			
			if (line=="active") {
				this._active=true;
				continue;
			}
			
			if (line.has_prefix("backup_period ")) {
				this.new_period=int.parse(line.substring(14).strip());
				continue;
			}
			
			failed=true;
			break;
		}

		try {
			in_stream.close(null);
		} catch {
		}
		try {
			file_read.close(null);
		} catch {
		}

		if (failed) {
			GLib.stderr.printf(_("Invalid parameter in config file %s (line %d)\n"),config_file.get_path(),line_counter);
			return line_counter;
		}
		
		return 0;
	}
	
	public void get_backup_data(out string id, out time_t oldest, out time_t newest, out time_t next,
															out uint64 total_space, out uint64 free_space) {
	
	
		this.fill_last_backup();

		this.backend.get_free_space(out total_space,out free_space);
	
		id = this.backend.get_backup_id();

		oldest=0;
		newest=0;
		next=0;
		
		var list_backup = this.backend.get_backup_list();
		if (list_backup == null) {
			oldest=0;
			newest=0;
			next=0;
			return;
		}

		if (list_backup==null) {
			return;
		}
		
		foreach(time_t v in list_backup) {
			if ((oldest==0) || (oldest>v)) {
				oldest=v;
			}
			if ((newest==0) || (newest<v)) {
				newest=v;
			}
		}
		if (this._active) {
			next=this.next_backup;
		} else {
			next=0;
		}
	}
}


int main(string[] args) {
	
	if (args.length>1) {
		sleep(3); // To ensure that the menu bar has been loaded
	}

	nice(19); // Minimum priority
	string basepath;
	
	var file=File.new_for_path("./interface/main.ui");
	if (file.query_exists()) {
		basepath="./interface/";
		Intl.bindtextdomain( "cronopete", "/usr/local/share/locale");
	} else {
		file=File.new_for_path("/usr/share/cronopete/main.ui");
		if (file.query_exists()) {
			basepath="/usr/share/cronopete/";
			Intl.bindtextdomain( "cronopete", "/usr/share/locale");
		} else {
			basepath="/usr/local/share/cronopete/";
			Intl.bindtextdomain( "cronopete", "/usr/local/share/locale");
		}
	}
	
	//Intl.setlocale (LocaleCategory.ALL, "");
	Intl.textdomain("cronopete");
	Intl.bind_textdomain_codeset( "cronopete", "UTF-8" );

	Gdk.threads_init();
	Gtk.init(ref args);

	var callbacks = new cp_callback(basepath);

	Gdk.threads_enter();
	Gtk.main();

	Gdk.threads_leave();
	return 0;
}
