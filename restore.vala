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

		this.mywindow = new Gtk.Window();

		this.base_layout = new Fixed();
		this.box = new EventBox();
		this.box.add_events (Gdk.EventMask.SCROLL_MASK);
		this.box.add(this.base_layout);
		this.mywindow.add(box);
		
		this.box.scroll_event.connect(this.on_scroll);
		
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
		this.base_layout.move(this.browser,scr_w*1/10,scr_h*1/10);

		this.mywindow.show_all();
		
		this.divisor=50.0;
		this.counter=0.0;
		this.timer=Timeout.add(20,this.timer_show);

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


	public bool timer_show() {
	
		if (this.counter<this.divisor) {
			this.counter+=1.0;
			this.mywindow.opacity=this.counter/this.divisor;
			return true;
		} else {
			return false;
		}
	}


}
