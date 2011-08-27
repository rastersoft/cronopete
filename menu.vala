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

class c_main_menu : GLib.Object {

	private weak TextBuffer log;
	private string basepath;
	private Window main_w;
	private Builder builder;
	private Notebook tabs;
	private cp_callback parent;
	private Image active;
	private Label Lvid;
	private Label Loldest;
	private Label Lnewest;
	private Label Lnext;
	private Label text_status;
	private Image img;
	private TextMark mark;
	private TextView log_view;
	private bool status;
	private string last_status;
	private Switch_Widget my_widget;
	
	public bool is_visible;
	
	public c_main_menu(string path, cp_callback p) {

		this.parent = p;
		this.basepath=path;
		
		this.builder = new Builder();		
		this.builder.add_from_file(Path.build_filename(this.basepath,"main.ui"));
		this.builder.connect_signals(this);		
		this.main_w = (Window) this.builder.get_object("window1");
		
		this.log = (TextBuffer) this.builder.get_object("textbuffer1");
		this.log_view = (TextView) this.builder.get_object("textview1");
		this.tabs = (Notebook) this.builder.get_object("notebook1");
		this.active = (Image) this.builder.get_object("is_active");
		this.Lvid = (Label) this.builder.get_object("label_volume");
		this.Loldest = (Label) this.builder.get_object("label_oldest_backup");
		this.Lnewest = (Label) this.builder.get_object("label_newest_backup");
		this.Lnext = (Label) this.builder.get_object("label_next_backup");
		this.text_status = (Label) this.builder.get_object("status_label");
		this.img = (Image) this.builder.get_object("image_disk");
		
		var cnt = (VBox) this.builder.get_object("vbox_switch");
		this.my_widget=new Switch_Widget();
		this.my_widget.toggled.connect(this.cronopete_is_active_callback);
		this.my_widget.show();
		cnt.pack_start(this.my_widget,false,true,0);
		//cnt.reorder_child(this.my_widget,1);

		this.is_visible = false;
		
	}

	public void set_status(string msg) {
	
		/* This string shows the current status of Cronopete. It could be
			Status: idle, or Status: copying file... */
		this.last_status=_("Status: %s").printf(msg);
		if (this.is_visible) {
			this.text_status.set_label(this.last_status);
		}
	}

	public void insert_log(string msg,bool reset) {
	
		if (this.is_visible) {
			TextIter iter;
			Gdk.threads_enter();
			if (reset) {
				this.log.set_text(msg,-1);
			} else {
				this.log.insert_at_cursor(msg,msg.length);
			}
			this.log.get_end_iter(out iter);				
			this.mark = this.log.create_mark("end", iter, false);
			this.log_view.scroll_to_mark(this.mark, 0.05, true, 0.0, 1.0);
			Gdk.flush();
			Gdk.threads_leave();
		}
	}

	private string parse_date(time_t val) {
		
		string retval;
		
		if (val==0) {
			// This is returned as the date for the first, last... backup when it doesn't exists (eg: last backup: none)
			retval=_("None");
		} else {
			var date = new DateTime.from_unix_local(val);
			
			
			time_t current = time_t();
			if ((current-val)<86400) {
				retval = date.format("%X").dup();
			} else {
				retval = date.format("%x").dup();
			}
		}
		
		return retval;		
	}

	public void show_main(bool show_log, string log) {

		this.refresh_backup_data();

		this.log.set_text(log,-1);
		this.main_w.show_all();
		this.main_w.present();
	
		this.tabs.set_current_page(0);
		
		this.my_widget.active=this.parent.active;
		
		TextIter iter;
		this.log.get_end_iter(out iter);				
		this.mark = this.log.create_mark("end", iter, false);
		this.log_view.scroll_to_mark(this.mark, 0.05, true, 0.0, 1.0);
		this.text_status.set_label(this.last_status);
		this.is_visible = true;
	
	}

	public void refresh_backup_data() {
	
		string? volume_id;
		time_t oldest;
		time_t newest;
		time_t next;

		this.parent.get_backup_data(out volume_id, out oldest, out newest, out next);
		
		if (volume_id==null) {
			// This text means that the user still has not selected a hard disk where to do the backups
			this.Lvid.set_text(_("Not defined"));
		} else {
			this.Lvid.set_text(volume_id);
		}
		this.Loldest.set_text(this.parse_date(oldest));
		this.Lnewest.set_text(this.parse_date(newest));
		this.Lnext.set_text(this.parse_date(next));
	
	}

	[CCode (instance_pos = -1)]
	public void cronopete_options_callback(Button source) {
	
		var tmp = new c_options(this.basepath,this.parent);
		tmp = null;
	
	}

	public void cronopete_is_active_callback() {
	
		if (this.my_widget.active) {
			this.parent.active=true;
		} else {
			this.parent.active=false;
			this.parent.stop_backup();
		}
		this.refresh_backup_data();
	}

	[CCode (instance_pos = -1)]
	public bool on_destroy_event(Gtk.Widget o) {
	
		this.main_w.hide();	
		this.is_visible = false;
		return true;
	}
	
	[CCode (instance_pos = -1)]
	public bool on_delete_event(Gtk.Widget source, Gdk.Event e) {
	
		this.is_visible = false;
		this.main_w.hide();
		return true;
		
	}
	
	[CCode (instance_pos = -1)]
	public void cronopete_change_disk_callback(Button source) {
	
		bool not_configured;

		if (this.parent.p_backup_path=="") {
			not_configured=true;
		} else {
			not_configured=false;
		}
		var tmp = new c_choose_disk(this.basepath,this.parent);
		tmp = null;
		this.refresh_backup_data();

		if ((this.parent.p_backup_path!="")&&(not_configured==true)&&(this.parent.active==false)) {
			this.parent.active=true;
			this.my_widget.active=true;
		}
	}
}