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
	private CheckButton active;
	private Label Lvid;
	private Label Loldest;
	private Label Lnewest;
	private Label Lnext;
	private Image img;
	
	public bool is_visible;
	
	public c_main_menu(string path, cp_callback p) {

		this.parent = p;

		this.builder = new Builder();
		
		this.basepath=path;
		
		this.builder.add_from_file(Path.build_filename(this.basepath,"main.ui"));
		
		this.main_w = (Window) this.builder.get_object("window1");
		this.builder.connect_signals(this);
		
		this.log = (TextBuffer) this.builder.get_object("textbuffer1");
		this.tabs = (Notebook) this.builder.get_object("notebook1");
		this.active = (CheckButton) this.builder.get_object("is_active");
		this.Lvid = (Label) this.builder.get_object("label_volume");
		this.Loldest = (Label) this.builder.get_object("label_oldest_backup");
		this.Lnewest = (Label) this.builder.get_object("label_newest_backup");
		this.Lnext = (Label) this.builder.get_object("label_next_backup");
		this.img = (Image) this.builder.get_object("image_disk");
		this.is_visible = false;
		
	}

	public void insert_log(string msg,bool reset) {
	
		if (this.is_visible) {
			Gdk.threads_enter();
			if (reset) {
				this.log.set_text(msg,-1);
			} else {
				this.log.insert_at_cursor(msg,msg.length);
			}
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

		string? volume_id;
		string icon;
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

		this.log.set_text(log,-1);
		this.main_w.show_all();
	
		if (show_log==true) {
			this.tabs.set_current_page(1);
		} else {
			this.tabs.set_current_page(0);
		}
		
		if (this.parent.active) {
			this.active.set_active(true);
		} else {
			this.active.set_active(false);
		}

		this.is_visible = true;
	
	}

	[CCode (instance_pos = -1)]
	public void cronopete_options_callback(Widget source) {
	
		var tmp = new c_options(this.basepath,this.parent);
		tmp = null;
	
	}

	[CCode (instance_pos = -1)]
	public void cronopete_is_active_callback(Widget source) {
		if (this.active.get_active()) {
			this.parent.active=true;
		} else {
			this.parent.active=false;
		}
	}

	[CCode (instance_pos = -1)]
	public bool on_destroy_event(Gdk.Event e) {
	
		this.main_w.hide_all();	
		this.is_visible = false;
		return true;
	}
	
	[CCode (instance_pos = -1)]
	public bool on_delete_event(Widget source, Gdk.Event e) {
	
		this.is_visible = false;
		this.main_w.hide_all();
		return true;
		
	}
	
	[CCode (instance_pos = -1)]
	public void cronopete_change_disk_callback(Widget source) {
	
		var tmp = new c_choose_disk(this.basepath,this.parent);
		tmp = null;
	
	}
	
}