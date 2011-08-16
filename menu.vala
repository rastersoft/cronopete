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
	private Image img;
	private TextMark mark;
	private TextView log_view;
	private bool status;
	
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
		this.img = (Image) this.builder.get_object("image_disk");
		this.is_visible = false;
		
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
	
		if (show_log==true) {
			this.tabs.set_current_page(1);
		} else {
			this.tabs.set_current_page(0);
		}
		
		if (this.parent.active) {
			this.active.set_from_file("cronopete_on.png");
			status=true;
		} else {
			this.active.set_from_file("cronopete_off.png");
			status=false;
		}
		
		TextIter iter;
		this.log.get_end_iter(out iter);				
		this.mark = this.log.create_mark("end", iter, false);
		this.log_view.scroll_to_mark(this.mark, 0.05, true, 0.0, 1.0);

		this.is_visible = true;
	
	}

	public void refresh_backup_data() {
	
		string? volume_id;
		time_t oldest;
		time_t newest;
		time_t next;

		this.parent.get_backup_data(out volume_id, out oldest, out newest, out next);
		
		if (volume_id==null) {
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

	[CCode (instance_pos = -1)]
	public void cronopete_is_active_callback(Button source) {
	
		if (this.parent.active) {
			this.parent.active=false;
			this.parent.stop_backup();
			this.active.set_from_file("cronopete_off.png");
		} else {
			this.active.set_from_file("cronopete_on.png");
			this.parent.active=true;
		}
	}

	[CCode (instance_pos = -1)]
	public bool on_destroy_event(Gtk.Object o) {
	
		this.main_w.hide_all();	
		this.is_visible = false;
		return true;
	}
	
	[CCode (instance_pos = -1)]
	public bool on_delete_event(Gtk.Widget source, Gdk.Event e) {
	
		this.is_visible = false;
		this.main_w.hide_all();
		return true;
		
	}
	
	[CCode (instance_pos = -1)]
	public void cronopete_change_disk_callback(Button source) {
	
		var tmp = new c_choose_disk(this.basepath,this.parent);
		tmp = null;
		this.refresh_backup_data();
	
	}
	
}