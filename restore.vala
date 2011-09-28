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

class restore_instant : GLib.Object {

	private Gtk.Window? container;
	private backends backup_backend;
	private iconbrowser_backend icon_backend;
	private FilelistIcons.IconBrowser? browser;

	private time_t time_instant;
	
	private int res_x;
	private int res_y;
	private int base_x;
	private int base_y;
	private int base_w;
	private int base_h;	
	
	private int x;
	private int y;
	private int z;
	private int w;
	private int h;
	private double alpha;
	
	private int nx;
	private int ny;
	private int nz;
	private double nalpha;
	
	public void inc_z() {
		this.nz+=250;
	}
	
	public void dec_z() {
		this.nz-=250;
	}
	
	public restore_instant(int resx, int resy, int vz, backends p_backend, time_t instant) {
	
		this.backup_backend=p_backend;
		this.time_instant=instant;
		this.res_x=resx;
		this.res_y=resy;
		this.nz=vz;
		
		this.base_w=4*(resx/5);
		this.base_h=5*(resy/7);
		this.base_x=(resx-this.base_w)/2;
		this.base_y=(resy-this.base_h)*2/3;

		this.icon_backend=new iconbrowser_backend(this.backup_backend,instant);
	
	}
	
	public void repaint_window(int z) {
	
		this.set_window(this.base_x,this.base_y,z);
		this.z=z;
	
	}
	
	private void set_window(int x,int y, int z) {
	
		if ((z>=-250)&&(z<1000)) {
		
			if ((this.browser==null)||(this.container==null)) {
				this.browser=new FilelistIcons.IconBrowser(this.icon_backend,Environment.get_home_dir());
				this.container=new Gtk.Window(Gtk.WindowType.TOPLEVEL);
				this.container.add(this.browser);
				this.container.resizable=false;
				this.container.decorated=false;
				this.container.type_hint=WindowTypeHint.SPLASHSCREEN;
				this.container.show_all();
			}
			
			this.transform_coords(x,y,z,out this.x,out this.y,out this.w,out this.h);
	
			this.container.width_request=this.w;
			this.container.height_request=this.h;
			this.container.move(this.x,this.y);
		} else {
			if (this.browser!=null) {
				this.browser.destroy();
				this.browser=null;
			}
			if (this.container!=null) {
				this.container.destroy();
				this.container=null;
			}
		}
	}
	
	private void transform_coords(int x, int y, int z, out int ox, out int oy, out int ow, out int oh) {
	
		int eyedist = 2500;
		
		ox=(x*eyedist+((z*this.res_x)/2))/(z+eyedist);
		oy=(y*eyedist)/(z+eyedist);
		ow=(this.base_w*eyedist)/(z+eyedist);
		oh=(this.base_h*eyedist)/(z+eyedist);
	
	}
	
	public bool move() {
	
		int v;
	
		if (this.z==this.nz) {
			return false;
		}

		v=(5*this.z+this.nz)/6;
		if (v==this.z) {
			v=this.nz;
		}
		this.repaint_window(v);
		return true;
	}
	
}

class restore_iface : GLib.Object {

	
	private backends backend;
	private double opacity;
	private uint timer;
	private double divisor;
	private double counter;
	private int scr_w;
	private int scr_h;
	
	private Gee.List<restore_instant ?> windows;
	private Gee.List<time_t?>? backups;
	private EventBox mylabel;
	
	private Gtk.Window mywindow;

	public static int mysort_64(time_t? a, time_t? b) {

		if(a>b) {
			return 1;
		}
		if(a<b) {
			return -1;
		}
		return 0;
	}

	public restore_iface(backends p_backend) {
	
		this.backend=p_backend;

		this.mywindow = new Gtk.Window();

		this.mylabel = new EventBox();
		this.mylabel.add_events (Gdk.EventMask.SCROLL_MASK);
		this.mywindow.add(mylabel);
		
		this.mylabel.scroll_event.connect(this.on_scroll);
		
		this.mylabel.sensitive=true;
		this.mywindow.sensitive=true;
		

		this.mywindow.fullscreen();
		this.opacity=0.0;
		this.mywindow.opacity=this.opacity;
		
		this.backups=p_backend.get_backup_list();
		this.backups.sort((CompareFunc)mysort_64);
		this.windows=new Gee.ArrayList<restore_instant ?>();

		this.mywindow.show_all();

		var scr=this.mywindow.get_screen();
		this.scr_w=scr.get_width();
		this.scr_h=scr.get_height();

		int z_value=250*this.backups.size;

		foreach (time_t back_time in this.backups) {
			z_value-=250;
			restore_instant element = new restore_instant(this.scr_w,this.scr_h,z_value,this.backend,back_time);
			if (z_value>=1000) {
				element.repaint_window(z_value);
			} else {
				element.repaint_window(0);
			}
			this.windows.add(element);
		}
		
		this.divisor=20.0;
		this.counter=0.0;
		this.timer=Timeout.add(50,this.timer_show);

	}

	private bool on_scroll(Gdk.EventScroll event) {
	
		foreach (var w in this.windows) {
			w.dec_z();
		}
	
		if (this.timer==0) {
			this.timer=Timeout.add(50,this.timer_show);
		}
	
		return true;
	
	}


	public bool timer_show() {
	
		bool to_continue;
	
		if (this.counter<this.divisor) {
			this.counter+=1.0;
			this.mywindow.opacity=this.counter/this.divisor;
			return true;
		} else {

			to_continue=false;

			foreach (var wnd in this.windows) {
				if (wnd.move()) {
					to_continue=true;
				}
			}
			if (to_continue==false) {
				this.timer=0;
			}
			return (to_continue);
		}
	}


}