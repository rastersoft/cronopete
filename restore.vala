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
using Cairo;

struct path_filename {
	string original_file;
	string restored_file;
}

class restore_iface : GLib.Object {

	private backends backend;
	private uint timer;
	private double current_alpha;
	private double desired_alpha;
	private int scr_w;
	private int scr_h;
	private string basepath;
	
	private EventBox box;
	private FilelistIcons.IconBrowser browser;
	private double browser_x;
	private double browser_y;
	private double browser_w;
	private double browser_h;

	private double restore_x;
	private double restore_y;
	private double restore_w;
	private double restore_h;

	private double exit_x;
	private double exit_y;
	private double exit_w;
	private double exit_h;

	private double scale_x;
	private double scale_y;
	private double scale_w;
	private double scale_h;
	private double scale_current_value;
	private double scale_desired_value;

	private double arrows_x;
	private double arrows_y;
	private double arrows_w;
	private double arrows_h;

	private int windows_current_value;
	private int zmul;
	
	private Gee.List<time_t?>? backups;
	private time_t last_time;
	private time_t current_instant;
	private double scale_factor;
	private Fixed base_layout;
	private Gtk.Window mywindow;
	private int pos;
	
	private Gee.List<path_filename ?> restore_files;
	private Gee.List<path_filename ?> restore_folders;
	private double total_to_restore;
	
	private DrawingArea drawing;
	private Cairo.ImageSurface base_surface;
	private Cairo.ImageSurface final_surface;
	private Cairo.ImageSurface animation_surface;
	private Cairo.ImageSurface nixies[13];
	private Cairo.ImageSurface grid;
	private int grid_w;
	private int grid_h;
	private int nixies_w[13];
	private int nixie_w;
	private int nixie_h;
	private int margin_nixie;
	private bool date_format;

	private Gtk.Window restore_window;
	private Gtk.Label restore_label;
	private Gtk.ProgressBar restore_bar;
	private bool cancel_restoring;
	private bool ignore_restoring_all;

	private Gtk.Window error_window;

	private unowned Thread <void *> c_thread;
	private uint timer_bar;

	private double icon_scale;
	private double icon_x_restore;
	private double icon_y_restore;
	private double icon_x_exit;
	private double icon_y_exit;
	private double icon_restore_scale;
	private double icon_exit_scale;
	private Cairo.ImageSurface restore_pic;
	private Cairo.ImageSurface exit_pic;

	private Gdk.Pixbuf capture;
	private bool capture_done;
	private bool browserhide;

	private double mx;
	private double my;
	private double mw;
	private double mh;
	

	public static int mysort_64(time_t? a, time_t? b) {

		if(a<b) {
			return 1;
		}
		if(a>b) {
			return -1;
		}
		return 0;
	}

	public restore_iface(backends p_backend,string paths) {
		
		this.backend=p_backend;
		this.backend.lock_delete_backup(true);
		this.basepath=paths;
		this.backend.restore_ended.connect(this.restoring_ended);

		this.scale_current_value=-1;
		this.windows_current_value=-1;
		this.zmul=1000;
		this.capture_done=false;

		this.icon_restore_scale=0.0;
		this.icon_exit_scale=0.0;

		this.backend.status.connect(this.refresh_status);
		
		// An ugly way of know if the current locale defines the date as MM/DD/YY or DD/MM/YY
		GLib.Time timeval = GLib.Time();
		timeval.day=1;
		timeval.month=2;
		timeval.year=2005;
		char mystr[9];
		timeval.strftime(mystr,"%x");
		if (mystr[1]=='1') {
			this.date_format=true; // European style
		} else {
			this.date_format=false; // USA style
		}
		
		this.restore_files = new Gee.ArrayList<path_filename ?>();
		this.restore_folders = new Gee.ArrayList<path_filename ?>();

		this.mywindow = new Gtk.Window();
		this.mywindow.fullscreen();
		var scr=this.mywindow.get_screen();
		this.scr_w=scr.get_width();
		this.scr_h=scr.get_height();
		//this.scr_w=800;
		//this.scr_h=600;
		this.grid_h=0;
		this.grid_w=0;
		
		this.base_layout = new Fixed();

		this.drawing = new DrawingArea();
		this.drawing.expose_event.connect(this.repaint_draw);
		this.base_layout.add(this.drawing);
		
		this.box = new EventBox();
		this.box.add_events (Gdk.EventMask.SCROLL_MASK|Gdk.EventMask.BUTTON_RELEASE_MASK|Gdk.EventMask.KEY_PRESS_MASK|Gdk.EventMask.KEY_RELEASE_MASK);
		this.box.add(this.base_layout);
		this.drawing.width_request=this.scr_w;
		this.drawing.height_request=this.scr_h;
		this.mywindow.add(box);
		
		this.box.scroll_event.connect(this.on_scroll);
		this.box.button_release_event.connect(this.on_click);
		this.box.key_press_event.connect(this.on_key_press);
		this.box.key_release_event.connect(this.on_key_release);
		
		this.box.sensitive=true;
		
		this.current_alpha=0.0;
		this.mywindow.opacity=this.current_alpha;
		
		this.backups=p_backend.get_backup_list();
		this.backups.sort((CompareFunc)mysort_64);

		this.browser=new FilelistIcons.IconBrowser(this.backend,Environment.get_home_dir());
		this.pos=0;
		this.browser.set_backup_time(this.backups[0]);
		this.browser.changed_path_list.connect(this.changed_path_list);

		this.create_cairo_layouts();
		
		this.base_layout.add(this.browser);
		this.browser.width_request=(int)this.browser_w;
		this.browser.height_request=(int)this.browser_h;
		this.base_layout.move(this.browser,(int)this.browser_x,(int)this.browser_y);

		this.paint_window();

		this.mywindow.show_all();
		
		this.desired_alpha=1.0;
		this.launch_animation ();
		
		//this.browser.show.connect_after(this.do_show);
	}

	public void changed_path_list() {

		this.capture_done=false;
		this.launch_animation ();
		
	}
	
	public void do_show() {

		if (this.capture_done==false) {
			this.capture.fill(0);
			Gdk.pixbuf_get_from_drawable(this.capture,this.browser.window,null,(int)this.browser_x,(int)this.browser_y,0,0,(int)this.browser_w,(int)this.browser_h);
			this.browser.do_refresh_icons ();
			this.browserhide=true;
			this.capture_done=true;
			this.repaint_draw2 ();
			this.paint_window ();
		}
	}

	public void refresh_status(usbhd_backend? b) {

		if (b.available==false) {
			this.exit_restore ();
		}
	}
	
	private void create_cairo_layouts() {
		
		this.base_surface = new Cairo.ImageSurface(Cairo.Format.ARGB32,this.scr_w,this.scr_h);
		this.final_surface = new Cairo.ImageSurface(Cairo.Format.ARGB32,this.scr_w,this.scr_h);
		this.animation_surface = new Cairo.ImageSurface(Cairo.Format.ARGB32,this.scr_w,this.scr_h);
		var brass = new Cairo.ImageSurface.from_png(GLib.Path.build_filename(this.basepath,"brass.png"));
		var screw1 = new Cairo.ImageSurface.from_png(GLib.Path.build_filename(this.basepath,"screw1.png"));
		var screw2 = new Cairo.ImageSurface.from_png(GLib.Path.build_filename(this.basepath,"screw2.png"));
		//var screw3 = new Cairo.ImageSurface.from_png(GLib.Path.build_filename(this.basepath,"screw3.png"));

		double w;
		w=(this.scr_w);
		double h;
		h=(this.scr_h);
		double scale;
		var c_base = new Cairo.Context(this.base_surface);
		c_base.set_source_rgb(0,0,0);
		c_base.paint();
		
		// Border screws
		scale=w/2800.0;

		// Generate nixies
		double scale2=(w-60.0-100.0*scale)/2175.0;
		this.nixie_w=(int)(145.0*scale2);
		this.nixie_h=(int)(150.0*scale2);
		this.margin_nixie=(int)(30.0+50.0*scale);
		Cairo.ImageSurface? nixie;
		double xtra;
		for (int c=0;c<13;c++) {
			switch (c) {
			case 10:
				nixie = new Cairo.ImageSurface.from_png(GLib.Path.build_filename(this.basepath,"nixiedots.png"));
				this.nixies_w[c]=(int)(70.0*scale2);
				xtra=-37.5;
			break;
			case 11:
				nixie = new Cairo.ImageSurface.from_png(GLib.Path.build_filename(this.basepath,"nixieslash.png"));
				this.nixies_w[c]=(int)(100.0*scale2);
				xtra=-22.5;
			break;
			case 12:
				nixie = null;
				this.nixies_w[c]=(int)(70.0*scale2);
				xtra=-37.5;
			break;
			default:
				nixie = new Cairo.ImageSurface.from_png(GLib.Path.build_filename(this.basepath,"nixie%d.png".printf(c)));
				this.nixies_w[c]=(int)(113.6*scale2);
				xtra=-16.2;
			break;
			}
			this.nixies[c] = new Cairo.ImageSurface(Cairo.Format.ARGB32,this.nixies_w[c],(int)(150.0*scale2));
			var ctx = new Context(this.nixies[c]);
			ctx.set_source_rgb(0,0,0);
			ctx.paint();
			if (nixie!=null) {
				ctx.save();
				ctx.scale(scale2,scale2);
				ctx.set_source_surface(nixie,xtra,0);
				ctx.paint();
				ctx.restore();
				ctx.set_source_rgb(0,0,0);
				ctx.move_to(0,0);
				ctx.set_line_width(6.0);
				ctx.line_to(this.nixies_w[c],0);
				ctx.line_to(this.nixies_w[c],150.0*scale2);
				ctx.line_to(0,150.0*scale2);
				ctx.close_path();
				ctx.stroke();
			}
		}

		double width;
		this.print_nixies(0, out width);
		scale=this.scr_w/2800.0;
		
		// Paint base surface
		this.mh=((double)(this.nixie_h))*4.0/3.0;
		this.mx=(this.scr_w-width)/2.0-80.0*scale;
		this.my=(this.scr_h)-(mh+(double)(this.nixie_h/6));
		this.mw=width+160*scale;
		
		c_base.set_source_surface(brass,0,this.my);
		c_base.rectangle(this.mx-this.mh,this.my,this.mw+2.0*this.mh,this.mh);
		c_base.fill();
		this.paint_border (c_base,this.mx,this.my,this.mw,this.mh,-1.5,true);

		// Browser border
		this.browser_x=scr_w*0.1;
		this.browser_y=this.scr_h/8;
		this.browser_w=scr_w*4/5;
		this.browser_h=this.my-this.browser_y-this.nixie_h/6;
		this.capture = new Gdk.Pixbuf(Gdk.Colorspace.RGB,false, 8,(int)this.browser_w,(int)this.browser_h);
		//this.paint_border (c_base,this.browser_x,this.browser_y,this.browser_w,this.browser_h,0.0,true);
		
		c_base.save();
		c_base.scale(scale2,scale2);
		this.icon_scale=scale2;
		double button_border = (mh/scale2-150.0)/2;
		
		// Restore button
		this.icon_x_restore=(this.mx-this.mh)/scale2+button_border;
		this.icon_y_restore=this.my/scale2+button_border;
		this.restore_pic = new Cairo.ImageSurface.from_png(GLib.Path.build_filename(this.basepath,"restore.png"));
		c_base.set_source_surface(restore_pic,this.icon_x_restore,this.icon_y_restore);
		c_base.paint();
		// Exit button
		this.icon_x_exit=(this.mx+this.mw)/scale2+button_border;
		this.icon_y_exit=this.my/scale2+button_border;
		this.exit_pic = new Cairo.ImageSurface.from_png(GLib.Path.build_filename(this.basepath,"exit.png"));
		c_base.set_source_surface(exit_pic,this.icon_x_exit,this.icon_y_exit);
		c_base.paint();
		
		// arrows
		var arrows_pic = new Cairo.ImageSurface.from_png(GLib.Path.build_filename(this.basepath,"arrows.png"));
		this.arrows_x=(this.browser_x+this.browser_w)-256.0*scale2;
		this.arrows_y=scale2*10.0;
		this.arrows_w=256*scale2;
		this.arrows_h=150*scale2;
		c_base.set_source_surface(arrows_pic,this.arrows_x/scale2,this.arrows_y/scale2);
		c_base.paint();
		c_base.restore();

		// Exit button coords
		this.exit_w=this.mh;
		this.exit_h=this.mh;
		this.exit_x=this.mx+this.mw;
		this.exit_y=this.my;
		this.paint_border (c_base,this.exit_x,this.exit_y,this.exit_w,this.exit_h,-1.5,true);

		// Restore button coords
		this.restore_w=this.mh;
		this.restore_h=this.mh;
		this.restore_x=this.mx-this.mh;
		this.restore_y=this.my;
		this.paint_border (c_base,this.restore_x,this.restore_y,this.restore_w,this.restore_h,-1.5,true);
			
		// Nixies border
		double mx2=(this.scr_w-width)/2.0;
		double my2=this.my+(double)(this.nixie_h/6);
		double mh2=(double)(this.nixie_h);
		
		this.paint_border (c_base,mx2,my2,width,mh2,1.5,false);

		// Nixies screws
		c_base.save();
		c_base.scale(scale,scale);
		c_base.set_source_surface(screw2,(((this.scr_w-width)/2.0))/scale-65,this.my/scale+90.0);
		c_base.paint();
		c_base.set_source_surface(screw1,(((this.scr_w+width)/2.0))/scale+15,this.my/scale+90.0);
		c_base.paint();
		c_base.restore();

		// timeline
		this.scale_x=this.restore_x;
		this.scale_y=5;
		this.scale_w=this.scr_w/28;
		this.scale_h=this.my-this.scale_y-5;
				
		this.last_time=this.backups[this.backups.size-1];
		this.scale_factor=this.scale_h/(this.backups[0]-this.last_time);

		double last_pos_y=-1;
		double pos_y=this.scale_y+this.scale_h;
		double new_y;
		
		c_base.set_source_rgb(1,1,1);
		c_base.set_line_width(1);
		
		double incval = this.scale_w/5;
		double nw = this.scale_w*3/5;

		for(var i=0;i<this.backups.size;i++) {
			new_y = pos_y-this.scale_factor*(this.backups[i]-this.last_time);
			if (new_y-last_pos_y<2) {
				continue;
			}
			last_pos_y=new_y;
			c_base.move_to(this.scale_x+incval,new_y);
			c_base.rel_line_to(nw,0);
			c_base.stroke();
		}
		
	}

	private void paint_border(Cairo.Context ctx, double mx, double my, double mw, double mh, double margin,bool reversed) {

		if (reversed) {
			ctx.set_source_rgba(0,0,0,0.3);
		} else {
			ctx.set_source_rgba(1,1,1,0.3);
		}
		ctx.set_line_width(3.0);
		ctx.move_to(mx-margin,my-margin);
		ctx.rel_line_to(mw+2*margin,0);
		ctx.rel_line_to(0,mh+2*margin);
		ctx.stroke();
		if (reversed) {
			ctx.set_source_rgba(1,1,1,0.3);
		} else {
			ctx.set_source_rgba(0,0,0,0.3);
		}
		ctx.move_to(mx-margin,my-margin);
		ctx.rel_line_to(0,mh+2*margin);
		ctx.rel_line_to(mw+2*margin,0);
		ctx.stroke();
	}
	
	private void paint_window() {
		
		double width;

		this.current_instant=this.backups[this.pos];
		
		var ctx = new Cairo.Context(this.final_surface);
		ctx.set_source_surface(this.base_surface,0,0);
		ctx.paint();
		
		var sf = this.print_nixies(this.current_instant,out width);
		double mx2=(this.scr_w-width)/2.0;
		double my2=this.my+(double)(this.nixie_h/6);
		ctx.set_source_surface(sf,mx2,my2);
		ctx.paint();
		this.scale_desired_value = this.scale_y+this.scale_h-this.scale_factor * (this.current_instant-this.last_time);
		if (this.scale_current_value==-1) {
			this.scale_current_value=this.scale_desired_value;
		}
	}

	private bool repaint_draw(EventExpose ev) {

		
		this.repaint_draw2();
		return true;

	}
	private void repaint_draw2() {

		var ctx = new Cairo.Context(this.animation_surface);

		// Paint the base image
		ctx.set_source_surface(this.final_surface,0,0);
		ctx.paint();

		// Paint the timeline index
		ctx.set_source_rgb(1,0,0);
		ctx.set_line_width(3);
		ctx.move_to(this.scale_x,this.scale_current_value);
		ctx.rel_line_to(this.scale_w,0);
		ctx.stroke();

		int maxval;

		if ((this.pos+10)<this.backups.size) {
			maxval=this.pos+10;
		} else {
			maxval=this.backups.size;
		}
		double ox;
		double oy;
		double ow;
		double oh;
		double scale;
		ctx.set_line_width(1.5);
		ctx.set_source_rgb(0.2,0.2,0.2);
		for(int c=maxval-1;c>=this.pos;c--) {
			double z;
			z=this.zmul*c-(this.windows_current_value);
			if (z<0) {
				continue;
			}
			this.transform_coords (z,out ox, out oy, out ow, out oh);
			/*ctx.set_source_rgb(1,1,1);
			//ctx.set_source_rgb(0.7,0.7,0.7);
			ctx.rectangle(ox,oy,ow,oh);
			ctx.fill();*/
			scale = ow/this.browser_w;
			ctx.save();
			ctx.scale(scale,scale);
			Gdk.cairo_set_source_pixbuf(ctx,this.capture,ox/scale,oy/scale);
			ctx.paint();
			ctx.restore();
			ctx.rectangle(ox,oy,ow,oh);
			ctx.stroke();
		}
		/*ctx.set_source_rgb(0.2,0.2,0.2);
		ctx.rectangle(this.browser_x,this.browser_y,this.browser_w,this.browser_h);
		ctx.stroke();*/

		// paint buttons

		if (this.icon_restore_scale!=0.0) {
			ctx.save();
			ctx.scale(this.icon_restore_scale,this.icon_restore_scale);
			var factor=(this.icon_restore_scale/this.icon_scale-1);
			var dif_factor=this.restore_pic.get_width()*factor/(this.icon_restore_scale*3);
			ctx.set_source_surface(this.restore_pic,this.icon_x_restore*this.icon_scale/this.icon_restore_scale-dif_factor,this.icon_y_restore*this.icon_scale/this.icon_restore_scale-dif_factor);
			ctx.paint_with_alpha(2.0-(this.icon_restore_scale/this.icon_scale));
			ctx.restore();
		}

		if (this.icon_exit_scale!=0.0) {
			ctx.save();
			ctx.scale(this.icon_exit_scale,this.icon_exit_scale);
			var factor=(this.icon_exit_scale/this.icon_scale-1);
			var dif_factor=this.exit_pic.get_width()*factor/(this.icon_exit_scale*3);
			ctx.set_source_surface(this.exit_pic,this.icon_x_exit*this.icon_scale/this.icon_exit_scale-dif_factor,this.icon_y_exit*this.icon_scale/this.icon_exit_scale-dif_factor);
			ctx.paint_with_alpha(2.0-(this.icon_exit_scale/this.icon_scale));
			ctx.restore();
		}
		
		var ctx2 = Gdk.cairo_create(this.drawing.window);
		ctx2.set_source_surface(this.animation_surface,0,0);
		ctx2.paint();
	}

	private void transform_coords(double z, out double ox, out double oy, out double ow, out double oh) {
	
		double eyedist = 2500.0;

		ox=(this.browser_x*eyedist+(z*((double)this.scr_w)/2))/(z+eyedist);
		oy=((this.browser_y)*eyedist)/(z+eyedist);
		ow=(this.browser_w*eyedist)/(z+eyedist);
		oh=(this.browser_h*eyedist)/(z+eyedist);
	
	}
	
	private int get_nixie_pos(char v) {
		
		if ((v>='0')&&(v<='9')) {
			return (v-'0');
		}
		if (v==':') {
			return (10);
		}
		if (v=='/') {
			return (11);
		}
		if (v==' ') {
			return (12);
		}
		return 0;
	}

	private void print_mesh(Cairo.Context ctx,double ox, double ow, double oh) {
		
		var rnd = new Rand.with_seed((int)ox);
		var dx = rnd.next_double();
		var dy = rnd.next_double();
		
		double v1=5.0;
		double v2=v1/2.0;
		double v31=v1/2;
		double v32=v1*0.866;
		double v4=2*v1+2*v31;
		double v5=2*v32;

		dx*=v1;
		dy*=v2;
		
		ctx.set_source_rgb(0,0,0);
		ctx.set_line_width(0.25);
		for(double x=-dx;x<ow;x+=v4) {
			for (double y=-dy;y<oh;y+=v5) {
				ctx.move_to(x+ox,y);
				ctx.rel_line_to(v1,0);
				ctx.rel_line_to(v31,v32);
				ctx.rel_line_to(v1,0);
				ctx.rel_line_to(v31,-v32);
				ctx.rel_line_to(-v31,-v32);
				ctx.move_to(x+ox+v1,y);
				ctx.rel_line_to(v31,-v32);
				ctx.stroke();
			}
		}	
	}

	private Cairo.ImageSurface print_nixies(time_t backup_date, out double width) {

		var ctime = GLib.Time.local(backup_date);
		string date;
		if (this.date_format) {
			date="%02d:%02d %02d/%02d/%04d".printf(ctime.hour,ctime.minute,ctime.day,ctime.month+1,1900+ctime.year);
		} else {
			date="%02d:%02d %02d/%02d/%04d".printf(ctime.hour,ctime.minute,ctime.month+1,ctime.day,1900+ctime.year);
		}
		
		bool repaint_grid;
		double size=0;
		double pos=0;

		for (int c=0;c<date.length;c++) {
			size+=this.nixies_w[this.get_nixie_pos(date[c])];
		}
		
		width=size;
		
		var surface = new Cairo.ImageSurface(Cairo.Format.ARGB32,(int)size,this.nixie_h);
		var ctx = new Cairo.Context(surface);
		if ((this.grid_w!=((int)size))||(this.grid_h!=this.nixie_h)) {
			this.grid = new Cairo.ImageSurface(Cairo.Format.ARGB32,(int)size,this.nixie_h);
			repaint_grid=true;
			this.grid_w = (int)size;
			this.grid_h = this.nixie_h;
		} else {
			repaint_grid=false;
		}

		var ctx2 = new Cairo.Context(this.grid);
		
		int element;
		ctx.set_line_width(0.0);
		for (int c=0;c<date.length;c++) {
			element=this.get_nixie_pos(date[c]);
			ctx.reset_clip();
			ctx.move_to(pos,0.0);
			ctx.rel_line_to(this.nixies_w[element],0.0);
			ctx.rel_line_to(0,this.nixie_h);
			ctx.rel_line_to(-this.nixies_w[element],0.0);
			ctx.rel_line_to(0,-this.nixie_h);
			ctx.clip();
			ctx.new_path();
			ctx.set_source_surface(this.nixies[element],pos,0.0);
			ctx.paint();
			if (repaint_grid) {
				ctx2.reset_clip();
				ctx2.move_to(pos,0.0);
				ctx2.rel_line_to(this.nixies_w[element],0.0);
				ctx2.rel_line_to(0,this.nixie_h);
				ctx2.rel_line_to(-this.nixies_w[element],0.0);
				ctx2.rel_line_to(0,-this.nixie_h);
				ctx2.clip();
				ctx2.new_path();
				this.print_mesh(ctx2,pos,this.nixies_w[element],this.nixie_h);
			}
			pos+=this.nixies_w[element];
		}
		ctx.reset_clip();
		ctx.set_source_surface(this.grid,0.0,0.0);
		ctx.paint();
		return surface;
	}

	private bool on_click(Gdk.EventButton event) {

		if(event.button!=1) {
			return false;
		}

		if ((event.x_root>=this.exit_x)&&(event.x_root<(this.exit_x+this.exit_w))&&(event.y_root>=this.exit_y)&&(event.y_root<(this.exit_y+this.exit_h))) {
			this.exit_restore ();
			return true;
		}

		if ((event.x_root>=this.restore_x)&&(event.x_root<(this.restore_x+this.restore_w))&&(event.y_root>=this.restore_y)&&(event.y_root<(this.restore_y+this.restore_h))) {
			this.do_restore();
			return true;
		}

		if ((event.x_root>=this.arrows_x)&&(event.x_root<(this.arrows_x+(this.arrows_w/2)))&&(event.y_root>=this.arrows_y)&&(event.y_root<(this.arrows_y+this.arrows_h))) {
			this.move_timeline(false);
			return true;
		}
		if ((event.x_root>=(this.arrows_x+(this.arrows_w/2)))&&(event.x_root<(this.arrows_x+this.arrows_w))&&(event.y_root>=this.arrows_y)&&(event.y_root<(this.arrows_y+this.arrows_h))) {
			this.move_timeline(true);
			return true;
		}
		return false;
		
	}

	private bool on_scroll(Gdk.EventScroll event) {

		if ((event.x_root>=((int)this.browser_x))&&(event.x_root<((int)(this.browser_x+this.browser_w)))&&(event.y_root>=((int)this.browser_y))&&(event.y_root<((int)(this.browser_y+this.browser_h)))) {
			return false;
		}
		
		if (event.direction==ScrollDirection.UP) {
			this.move_timeline(false);
		}
		if (event.direction==ScrollDirection.DOWN) {
			this.move_timeline(true);
		}
		return true;
	}

	private bool on_key_press(Gdk.EventKey event) {

		if (event.keyval==0xFF55) { // PG UP key
			this.move_timeline(false);
			return true;
		}
		if (event.keyval==0xFF56) { // PG DOWN key
			this.move_timeline(true);
			return true;
		}
		if (event.keyval==0xFF1B) { // ESC key
			this.exit_restore ();
			return true;
		}
		return false;
	}

	private bool on_key_release(Gdk.EventKey event) {

		if (event.keyval=='r') {
			this.do_restore ();
			return true;
		}
		
		return false;
	}
	
	private void move_timeline(bool increase) {

		if (increase) {
			if (this.pos>=(this.backups.size-1)) {
				return;
			} else {
				this.browser.hide();
				this.browserhide=true;
				this.pos++;
			}
		} else {
			if (this.pos==0) {
				return;
			} else {
				this.browser.hide();
				this.browserhide=true;
				this.pos--;
			}
		}

		this.browser.set_backup_time(this.backups[this.pos]);
		this.paint_window();
		this.launch_animation();
	}

	private void launch_animation() {
		if (this.timer==0) {
			this.timer=Timeout.add(40,this.timer_move);
		}
	}
	
	private bool timer_move() {

		bool end_animation=true;
		bool do_repaint=false;

		this.do_show ();
		
		if (this.scale_current_value!=this.scale_desired_value) {
			double diff;
			end_animation=false;
			if (this.scale_current_value>this.scale_desired_value) {
				diff=this.scale_current_value-this.scale_desired_value;
				this.scale_current_value-=(diff/3);
			} else {
				diff=this.scale_desired_value-this.scale_current_value;
				this.scale_current_value+=(diff/3);
			}
			if (diff<6) {
				this.scale_current_value=this.scale_desired_value;
			}
			do_repaint=true;
		}

		int windows_desired_value=this.pos*this.zmul;
		
		if (this.windows_current_value!=windows_desired_value) {
			int diff2;
			end_animation=false;
			if (this.windows_current_value>windows_desired_value) {
				diff2=this.windows_current_value-windows_desired_value;
				this.windows_current_value-=(diff2/3);
			} else {
				diff2=windows_desired_value-this.windows_current_value;
				this.windows_current_value+=(diff2/3);
			}
			if (diff2<(this.zmul/5)) {
				this.windows_current_value=windows_desired_value;
			}
			do_repaint=true;
		} else {
			if (this.browserhide) {
				this.browser.do_refresh_icons();
				this.browser.show();
				this.browserhide=false;
			}
		}

		if (this.icon_restore_scale!=0.0) {
			do_repaint=true;
			var final_value = this.icon_scale*2;
			double diff=((final_value-this.icon_restore_scale)/4);
			if (this.icon_restore_scale>=final_value*0.95) {
				this.icon_restore_scale=0.0;
			} else {
				this.icon_restore_scale+=diff;
				end_animation=false;
			}
		}	

		if (this.icon_exit_scale!=0.0) {
			do_repaint=true;
			var final_value = this.icon_scale*2;
			double diff=((final_value-this.icon_exit_scale)/4);
			if (this.icon_exit_scale>=final_value*0.95) {
				this.icon_exit_scale=0.0;
			} else {
				this.icon_exit_scale+=diff;
				end_animation=false;
			}
		}	
		
		if (do_repaint) {
			this.repaint_draw2();
		}
		
		if (this.desired_alpha!=this.current_alpha) {
			double diff;
			if (this.desired_alpha>this.current_alpha) {
				diff=this.desired_alpha-this.current_alpha;
				this.current_alpha+=(diff/6);
			} else {
				diff=this.current_alpha-this.desired_alpha;
				this.current_alpha-=(diff/6);
			}
			if (diff<0.05) {
				this.current_alpha=this.desired_alpha;
			}
			
			if (this.current_alpha==0.0) {
				this.mywindow.hide();
				this.mywindow.destroy();
				this.backend.lock_delete_backup(false);
				end_animation=true;
			} else {
				this.mywindow.opacity=this.current_alpha;
				end_animation=false;
			}
		}
		
		if (end_animation) {
			this.timer=0;
			return false;
		} else {
			return true;
		}
	}

	private void exit_restore() {

		this.icon_exit_scale=this.icon_scale;
		this.launch_animation ();
		
		this.desired_alpha=0.0;
		
		this.launch_animation ();
		
	}
	
	private string get_restored_filename(string path, string filename) {
		
		string newfilename="%s.restored".printf(filename);
		int counter=1;
		File fs;
		
		while(true) {
			fs = File.new_for_path(GLib.Path.build_filename(path,newfilename));
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
		
		if ((rv!=BACKUP_RETVAL.OK)&&(this.ignore_restoring_all==false)) {
			string error_msg;
			if (rv==BACKUP_RETVAL.NO_SPC) {
				error_msg=_("Failed to restore file\n\n%s\n\nThere's not enought free space").printf(file_ended);
			} else {
				error_msg=_("Failed to restore file\n\n%s").printf(file_ended);
			}

			var w2 = new Builder();
			
			w2.add_from_file(GLib.Path.build_filename(this.basepath,"restore_error.ui"));
			w2.connect_signals(this);
			this.error_window = (Gtk.Window)w2.get_object("restore_error");
			var error_label = (Gtk.Label)w2.get_object("error_msg");
			error_label.label=error_msg;
			
			error_window.show_all();
			return;
		}
		
		if (file_ended!="") {
			var current_time=time_t();
			var f=File.new_for_path(file_ended);
			try {
				f.set_attribute_uint64(FILE_ATTRIBUTE_TIME_MODIFIED,current_time,0,null);
				f.set_attribute_uint64(FILE_ATTRIBUTE_TIME_ACCESS,current_time,0,null);
			} catch (Error e) {
			}
		}
		
		if (this.restore_files.is_empty) {
			this.mywindow.window.set_cursor(null);
			this.restore_window.destroy();
			return;
		}

		if (this.cancel_restoring) {
			this.mywindow.window.set_cursor(null);
			this.restore_files.clear();
			this.restore_window.destroy();
			return;
		}
		
		var percent=1.0-(((double)this.restore_files.size)/this.total_to_restore);
		var filename = this.restore_files.get(0);
		this.restore_files.remove_at(0);
		this.restore_label.label=_("Restoring file:\n\n%s").printf(filename.restored_file);
		this.restore_bar.fraction=percent;
		this.backend.restore_file(filename.original_file,this.backups[this.pos],filename.restored_file);
		
	}
	
	private void do_restore() {

		this.icon_restore_scale=this.icon_scale;
		this.launch_animation ();
		
		this.ignore_restoring_all=false;
		var w = new Builder();
		
		w.add_from_file(GLib.Path.build_filename(this.basepath,"restoring.ui"));
		w.connect_signals(this);

		this.restore_window = (Gtk.Window)w.get_object("restore_status");
		this.restore_bar = (Gtk.ProgressBar)w.get_object("restore_progressbar");
		this.restore_label = (Gtk.Label)w.get_object("restoring_file");

		this.cancel_restoring=false;
		this.restore_label.label=_("Preparing folders to restore");
		this.restore_window.show_all();
		this.timer_bar=Timeout.add(250,this.timer_bar_f);

		var cursor_working = new Gdk.Cursor(Gdk.CursorType.WATCH);
		this.mywindow.window.set_cursor(cursor_working);
		
		this.launch_fill_restore_list.begin( (obj,res) => {
			this.launch_fill_restore_list.end(res);
			Source.remove(this.timer_bar);
			if (!this.cancel_restoring) {
				this.total_to_restore=(double)this.restore_files.size;
				this.restoring_ended(this.backend,"",BACKUP_RETVAL.OK);
			} else {
				this.restore_files.clear();
				this.restore_window.destroy();
				this.mywindow.window.set_cursor(null);
			}
		});
	}

	public bool timer_bar_f() {
		this.restore_bar.pulse();
		return true;
	}
	
	private async void launch_fill_restore_list() {

		SourceFunc callback = launch_fill_restore_list.callback;
		
		ThreadFunc<void *> run = () => {

			Gee.List<string> files;
			Gee.List<string> folders;
			
			var path=this.browser.get_current_path();
			
			this.browser.get_selected_items(out files, out folders);
			foreach (string f in files) {
				if (this.cancel_restoring) {
					Idle.add((owned)callback);
					return null;
				}
				var element = path_filename();
				element.original_file=GLib.Path.build_filename(path,f);
				element.restored_file=GLib.Path.build_filename(path,this.get_restored_filename(path,f));
				this.restore_files.add(element);
			}

			foreach (string v in folders) {
				if (this.cancel_restoring) {
					Idle.add((owned)callback);
					return null;
				}
				var restored_folder = GLib.Path.build_filename(path,this.get_restored_filename(path,v));
				this.add_folder_to_restore(GLib.Path.build_filename(path,v),restored_folder);
			}
			Idle.add((owned)callback);
			return null;
		};

		c_thread=Thread.create <void *>(run, false);
		yield;
	}
	
	private BACKUP_RETVAL add_folder_to_restore(string o_path, string f_path) {
		
		Gee.List<FilelistIcons.file_info ?> files;
		string date;
		string new_opath;
		string new_rpath;
		
		try {
			var dir2 = File.new_for_path(GLib.Path.build_filename(f_path));
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
			if (this.cancel_restoring) {
				return BACKUP_RETVAL.ABORTED;
			}
			if (v.isdir) {
				new_opath = GLib.Path.build_filename(o_path,v.name);
				new_rpath = GLib.Path.build_filename(f_path,v.name);
				this.add_folder_to_restore(new_opath,new_rpath);
			} else {
				var element = path_filename();
				element.original_file=GLib.Path.build_filename(o_path,v.name);
				element.restored_file=GLib.Path.build_filename(f_path,v.name);
				this.restore_files.add(element);
			}
		}
		return BACKUP_RETVAL.OK;
	}

	[CCode (instance_pos = -1)]
	public void on_cancel_clicked(Button source) {
		this.cancel_restoring=true;
	}

	[CCode (instance_pos = -1)]
	public void on_cancel_restore_error_clicked(Button source) {

		this.error_window.destroy();
		this.cancel_restoring=true;
		this.restoring_ended(this.backend,"",BACKUP_RETVAL.OK);
	}

	[CCode (instance_pos = -1)]
	public void on_ignore_restore_error_clicked(Button source) {
		this.error_window.destroy();
		this.restoring_ended(this.backend,"",BACKUP_RETVAL.OK);
	}

	[CCode (instance_pos = -1)]
	public void on_ignore_all_restore_error_clicked(Button source) {
		this.ignore_restoring_all=true;
		this.error_window.destroy();
		this.restoring_ended(this.backend,"",BACKUP_RETVAL.OK);
	}
	
	[CCode (instance_pos = -1)]
	public bool on_delete_event(Event event) {

		return true;
	}
}
