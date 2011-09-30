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
	private Fixed base_layout;

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
	
	public restore_instant(int resx, int resy, int vz, backends p_backend, time_t instant,Fixed blayout) {
	
		this.base_layout=blayout;
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
		this.browser=new FilelistIcons.IconBrowser(this.icon_backend,Environment.get_home_dir());
		this.browser.shadow=ShadowType.ETCHED_IN;
		this.base_layout.add(this.browser);
		this.set_window(this.base_x,this.base_y,vz);
	}
	
	public void set_window(int x,int y, int z) {
		
		this.transform_coords(this.base_x,this.base_y,z,out this.x,out this.y,out this.w,out this.h);
	
		this.browser.width_request=this.w;
		this.browser.height_request=this.h;
		this.base_layout.move(this.browser,this.x,this.y);
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
	
	private EventBox box;
	private Gee.List<restore_instant ?> windows;
	private Gee.List<time_t?>? backups;
	private Fixed base_layout;
	
	private Gtk.Window mywindow;
	
	private restore_instant lista[5];
	private int z2;

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
		this.windows=new Gee.ArrayList<restore_instant ?>();

		var scr=this.mywindow.get_screen();
		this.scr_w=scr.get_width();
		this.scr_h=scr.get_height();

		int z=0;

		foreach (time_t back_time in this.backups) {
			this.lista[z]=new restore_instant(this.scr_w,this.scr_h,z*250,this.backend,back_time,this.base_layout);
			z++;
			if (z==5){
				break;
			}
		}

		this.mywindow.show_all();
		z2=0;
		
		this.divisor=20.0;
		this.counter=0.0;
		this.timer=Timeout.add(50,this.timer_show);

	}

	private bool on_scroll(Gdk.EventScroll event) {
	
		GLib.stdout.printf("Scroll\n");
	
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