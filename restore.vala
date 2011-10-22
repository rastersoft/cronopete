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
	private double opacity;
	private uint timer;
	private uint timer2;
	private double divisor;
	private double counter;
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
	
	private Gee.List<time_t?>? backups;
	private time_t last_time;
	private time_t current_instant;
	private double scale_factor;
	private Fixed base_layout;
	private Gtk.Window mywindow;
	private int pos;
	
	private Gee.List<path_filename ?> restore_files;
	private Gee.List<path_filename ?> restore_folders;
	
	private DrawingArea drawing;
	private Cairo.ImageSurface base_surface;
	private Cairo.ImageSurface final_surface;
	private Cairo.ImageSurface nixies[13];
	private Cairo.ImageSurface grid;
	private int grid_w;
	private int grid_h;
	private int nixies_w[13];
	private int nixie_w;
	private int nixie_h;
	private int margin_nixie;

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
		this.basepath=paths;
		this.backend.restore_ended.connect(this.restoring_ended);

		this.scale_current_value=-1;

		this.restore_files = new Gee.ArrayList<path_filename ?>();
		this.restore_folders = new Gee.ArrayList<path_filename ?>();

		this.mywindow = new Gtk.Window();
		this.mywindow.fullscreen();
		var scr=this.mywindow.get_screen();
		this.scr_w=scr.get_width();
		this.scr_h=scr.get_height();
		//this.scr_w=1024;
		//this.scr_h=600;
		this.grid_h=0;
		this.grid_w=0;
		
		this.base_layout = new Fixed();

		this.drawing = new DrawingArea();
		this.drawing.expose_event.connect(this.repaint_draw);
		this.base_layout.add(this.drawing);
		
		this.box = new EventBox();
		this.box.add_events (Gdk.EventMask.SCROLL_MASK|Gdk.EventMask.BUTTON_RELEASE_MASK);
		this.box.add(this.base_layout);
		this.drawing.width_request=this.scr_w;
		this.drawing.height_request=this.scr_h;
		this.mywindow.add(box);
		
		this.box.scroll_event.connect(this.on_scroll);
		this.box.button_release_event.connect(this.on_click);
		
		this.box.sensitive=true;
		
		this.opacity=0.0;
		this.mywindow.opacity=this.opacity;
		
		this.backups=p_backend.get_backup_list();
		this.backups.sort((CompareFunc)mysort_64);

		this.browser=new FilelistIcons.IconBrowser(this.backend,Environment.get_home_dir());
		this.pos=0;
		this.browser.set_backup_time(this.backups[0]);

		this.create_cairo_layouts();
		
		this.base_layout.add(this.browser);
		this.browser.width_request=(int)this.browser_w;
		this.browser.height_request=(int)this.browser_h;
		this.base_layout.move(this.browser,(int)this.browser_x,(int)this.browser_y);

		this.paint_window();

		this.mywindow.show_all();
		
		this.divisor=25.0;
		this.counter=0.0;
		this.timer2=0;
		this.timer=Timeout.add(20,this.timer_show);

	}

	private void create_cairo_layouts() {
		
		this.base_surface = new Cairo.ImageSurface(Cairo.Format.ARGB32,this.scr_w,this.scr_h);
		this.final_surface = new Cairo.ImageSurface(Cairo.Format.ARGB32,this.scr_w,this.scr_h);
		var brass = new Cairo.ImageSurface.from_png(GLib.Path.build_filename(this.basepath,"brass.png"));
		var screw1 = new Cairo.ImageSurface.from_png(GLib.Path.build_filename(this.basepath,"screw1.png"));
		var screw2 = new Cairo.ImageSurface.from_png(GLib.Path.build_filename(this.basepath,"screw2.png"));
		var screw3 = new Cairo.ImageSurface.from_png(GLib.Path.build_filename(this.basepath,"screw3.png"));
		double w;
		w=(this.scr_w);
		double h;
		h=(this.scr_h);
		double scale;
		
		var c_base = new Cairo.Context(this.base_surface);
		c_base.set_source_surface(brass,0,0);
		c_base.paint();
		
		c_base.save();
		scale=w/2800.0;
		c_base.scale(scale,scale);
		c_base.set_source_surface(screw1,20/scale,20/scale);
		c_base.paint();
		c_base.set_source_surface(screw1,(this.scr_w-20)/scale-50,(this.scr_h-20)/scale-50);
		c_base.paint();
		c_base.set_source_surface(screw2,20/scale,(this.scr_h-20)/scale-50);
		c_base.paint();
		c_base.set_source_surface(screw3,(this.scr_w-20)/scale-50,20/scale);
		c_base.paint();
		
		
		c_base.restore();
		c_base.save();
		
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
		c_base.restore();

		double width;
		this.print_nixies(0, out width);
	
		double mx=(this.scr_w-width)/2.0;
		double my=(double)(this.nixie_h/3);
		double mh=(double)(this.nixie_h);

		this.browser_x=scr_w*0.1;
		this.browser_y=5*this.nixie_h/3;
		this.browser_w=scr_w*4/5;
		this.browser_h=scr_h-3*this.nixie_h;
		
		this.paint_border (c_base,mx,my,width,mh,1.5);
		this.paint_border (c_base,this.browser_x,this.browser_y,this.browser_w,this.browser_h,0.0);

		c_base.save();
		scale=this.scr_w/2800.0;
		c_base.scale(scale,scale);
		c_base.set_source_surface(screw2,(((this.scr_w-width)/2.0))/scale-60,((double)(this.nixie_h/3))/scale+60.0);
		c_base.paint();
		c_base.set_source_surface(screw1,(((this.scr_w+width)/2.0))/scale+10,((double)(this.nixie_h/3))/scale+60.0);
		c_base.paint();
		c_base.restore();

		this.exit_w=this.nixie_h*16/18;
		this.exit_h=this.nixie_h*16/18;
		this.exit_x=this.browser_x+this.browser_w-this.exit_w;
		this.exit_y=this.scr_h-20*this.nixie_h/19;
		this.paint_button (c_base,this.exit_x,this.exit_y,this.exit_w,this.exit_h,0.1,1.0,0.0,0.0,_("Exit"),false);

		this.restore_w=this.nixie_h*16/18;
		this.restore_h=this.nixie_h*16/18;
		this.restore_x=this.browser_x;
		this.restore_y=this.scr_h-20*this.nixie_h/19;
		this.paint_button (c_base,this.restore_x,this.restore_y,this.restore_w,this.restore_h,0.6,0.0,1.0,0.0,_("Restore files"),true);

		this.scale_x=this.scr_w/30;
		this.scale_y=this.scr_h/16;
		this.scale_w=this.scr_w/28;
		this.scale_h=this.scr_h*14/16;
		this.paint_border(c_base,this.scale_x,this.scale_y,this.scale_w,this.scale_h,2);

		var pattern = new Cairo.Pattern.linear(this.scale_x,this.scale_y,this.scale_x+this.scale_w,this.scale_y+this.scale_h);
		pattern.add_color_stop_rgba(1.0,0.9,0.9,0.7,1);
		pattern.add_color_stop_rgba(0.0,1.0,1.0,0.8,1);
		c_base.set_source(pattern);
		c_base.rectangle(this.scale_x,this.scale_y,this.scale_w,this.scale_h);
		c_base.fill();

		this.last_time=this.backups[this.backups.size-1];
		this.scale_factor=this.scale_h/(this.backups[0]-this.last_time);

		double last_pos_y=-1;
		double pos_y=this.scale_y+this.scale_h;
		double new_y;
		
		c_base.set_source_rgb(0,0,0);
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

	private void paint_border(Cairo.Context ctx, double mx, double my, double mw, double mh, double margin) {

		ctx.set_source_rgba(0,0,0,0.3);
		ctx.set_line_width(3.0);
		ctx.move_to(mx-margin,my+mh+margin);
		ctx.rel_line_to(0,-mh-2*margin);
		ctx.rel_line_to(mw+2*margin,0);
		ctx.stroke();
		ctx.set_source_rgba(1,1,1,0.3);
		ctx.move_to(mx-margin,my+mh+margin);
		ctx.rel_line_to(mw+2*margin,0);
		ctx.rel_line_to(0,-mh-2*margin);
		ctx.stroke();
	}
	
	private void paint_window() {
		
		double width;

		this.current_instant=this.backups[this.pos];
		
		var ctx = new Cairo.Context(this.final_surface);
		ctx.set_source_surface(this.base_surface,0,0);
		ctx.paint();
		
		var sf = this.print_nixies(this.current_instant,out width);
		double mx=(this.scr_w-width)/2.0;
		double my=(double)(this.nixie_h/3);
		ctx.set_source_surface(sf,mx,my);
		ctx.paint();
		this.scale_desired_value = this.scale_y+this.scale_h-this.scale_factor * (this.current_instant-this.last_time);
		if (this.scale_current_value==-1) {
			this.scale_current_value=this.scale_desired_value;
		}
	}


	private void paint_button(Cairo.Context ctx, double x, double y, double w, double h, double angle, double r, double g, double b, string text, bool at_end) {

		double radius;
		double radius2;
		Cairo.Pattern pattern;
		
		if (w>h) {
			radius=h/2;
			radius2=h;
		} else {
			radius=w/2;
			radius2=w;
		}
		double hex1;
		double hex2;
		hex1=radius*0.5;
		hex2=radius*0.886;

		ctx.save();
		ctx.reset_clip();
		ctx.translate(x+w/2,y+h/2);
		ctx.rotate(angle);
		ctx.move_to(-radius,0);
		ctx.rel_line_to(hex1,hex2);
		ctx.rel_line_to(radius,0);
		ctx.rel_line_to(hex1,-hex2);
		ctx.rel_line_to(-hex1,-hex2);
		ctx.rel_line_to(-radius,0);
		ctx.rel_line_to(-hex1,hex2);
		ctx.clip();
		ctx.rotate(-angle);
		ctx.set_source_rgb(0.6,0.6,0.6);
		ctx.rectangle(-radius,-radius,radius2,radius2);
		ctx.fill();
		pattern = new Cairo.Pattern.linear(-radius,-radius,radius2,radius2);
		pattern.add_color_stop_rgba(1.0,0.0,0.0,0.0,0.6);
		pattern.add_color_stop_rgba(0.0,1.0,1.0,1.0,0.6);
		ctx.set_source(pattern);
		ctx.rectangle(-radius,-radius,radius2,radius2);
		ctx.fill();
		ctx.reset_clip();
		ctx.restore();

		radius*=0.84;

		ctx.set_source_rgb(0.5,0.5,0.5);
		ctx.arc(x+w/2,y+h/2,radius,0,6.283184);
		ctx.fill();
		pattern = new Cairo.Pattern.linear(x,y,x+w,y+h);
		pattern.add_color_stop_rgba(1.0,0.0,0.0,0.0,0.3);
		pattern.add_color_stop_rgba(0.0,1.0,1.0,1.0,0.3);
		ctx.set_source(pattern);
		ctx.arc(x+w/2,y+h/2,radius,0,6.283184);
		ctx.fill();

		radius*=0.85;
		
		ctx.set_source_rgb(0,0,0);
		ctx.arc(x+w/2,y+h/2,radius,0,6.283184);
		ctx.fill();
		pattern = new Cairo.Pattern.linear(x,y,x+w,y+h);
		pattern.add_color_stop_rgba(1.0,0.0,0.0,0.0,0.3);
		pattern.add_color_stop_rgba(0.0,1.0,1.0,1.0,0.3);
		ctx.set_source(pattern);
		ctx.arc(x+w/2,y+h/2,radius,0,6.283184);
		ctx.fill();

		ctx.reset_clip();
		radius*=0.85;
		ctx.arc(x+w/2,y+h/2,radius,0,6.283184);
		ctx.clip();
		
		ctx.set_source_rgb(r,g,b);
		ctx.arc(x+w/2,y+h/2,radius,0,6.283184);
		ctx.fill();

		pattern = new Cairo.Pattern.linear(x,y,x+w,y+h);
		pattern.add_color_stop_rgba(0.0,0.0,0.0,0.0,0.2);
		pattern.add_color_stop_rgba(1.0,1.0,1.0,1.0,0.2);
		ctx.set_source(pattern);
		ctx.arc(x+w/2,y+h/2,radius,0,6.283184);
		ctx.fill();
		
		pattern = new Cairo.Pattern.linear(x,y,x+w,y+h);
		pattern.add_color_stop_rgba(1.0,0.0,0.0,0.0,0.4);
		pattern.add_color_stop_rgba(0.0,1.0,1.0,1.0,0.4);
		ctx.set_source(pattern);
		ctx.set_line_width(radius*0.25);
		ctx.arc(x+w/2,y+h/2,radius,0,6.283184);
		ctx.stroke();
		ctx.reset_clip();
		ctx.set_source_rgb(0,0,0);
		ctx.select_font_face("Serif",FontSlant.ITALIC,FontWeight.NORMAL);
		ctx.set_font_size(radius2*0.8);
		TextExtents extents;

		ctx.text_extents(text, out extents);

		//GLib.stdout.printf("%s %f %f %f\n",text,extents.height,extents.y_bearing,extents.y_advance);
		
		double nx;
		double ny;
		
		if (at_end) {
			nx=x+(w+radius2)/2+3;
		} else {
			nx=x+(w-radius2)/2-extents.width-3;
		}

		double fh;
		if (extents.y_bearing>=0) {
			fh=extents.y_bearing;
		} else {
			fh=-extents.y_bearing;
		}
		ny=y+(h+fh)/2;
		ctx.move_to(nx,ny);
		ctx.show_text(text);

		/*ctx.set_line_width(1);
		ctx.move_to(nx,ny);
		ctx.rel_line_to(extents.width,0);
		ctx.stroke();*/
	}
	

	private bool repaint_draw(EventExpose ev) {

		this.repaint_draw2();
		return true;

	}
	private void repaint_draw2() {

		var ctx = Gdk.cairo_create(this.drawing.window);		
		ctx.set_source_surface(this.final_surface,0,0);
		ctx.paint();
		ctx.set_source_rgb(1,0,0);
		ctx.set_line_width(3);
		ctx.move_to(this.scale_x,this.scale_current_value);
		ctx.rel_line_to(this.scale_w,0);
		ctx.stroke();
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
		var date="%02d:%02d %02d/%02d/%04d".printf(ctime.hour,ctime.minute,ctime.day,ctime.month+1,1900+ctime.year);
		
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

		if ((event.x_root>=this.exit_x)&&(event.x_root<(this.exit_x+this.exit_w))&&(event.y_root>=this.exit_y)&&(event.y_root<(this.exit_y+this.exit_h))) {
			this.exit_restore ();
			return true;
		}

		if ((event.x_root>=this.restore_x)&&(event.x_root<(this.restore_x+this.restore_w))&&(event.y_root>=this.restore_y)&&(event.y_root<(this.restore_y+this.restore_h))) {
			this.do_restore();
			return true;
		}
		
		return false;
		
	}

	private bool on_scroll(Gdk.EventScroll event) {

		if ((event.x_root>=((int)this.browser_x))&&(event.x_root<((int)(this.browser_x+this.browser_w)))&&(event.y_root>=((int)this.browser_y))&&(event.y_root<((int)(this.browser_y+this.browser_h)))) {
			return true;
		}
		
		if ((event.direction==ScrollDirection.UP)&&(this.pos>0)) {
			this.pos--;
			this.browser.set_backup_time(this.backups[this.pos]);
		}
		if ((event.direction==ScrollDirection.DOWN)&&(this.pos<(this.backups.size-1))) {
			this.pos++;
			this.browser.set_backup_time(this.backups[this.pos]);
		}
		this.paint_window();
		if (this.timer2==0) {
			this.timer2=Timeout.add(40,this.timer_move);
		}
		return true;
	}

	private bool timer_move() {

		if (this.scale_current_value==this.scale_desired_value) {
			this.timer2=0;
			return false;
		}

		double diff;

		if (this.scale_current_value>this.scale_desired_value) {
			diff=this.scale_current_value-this.scale_desired_value;
			this.scale_current_value-=(diff/4);
		} else {
			diff=this.scale_desired_value-this.scale_current_value;
			this.scale_current_value+=(diff/4);
		}
		if (diff<2) {
			this.scale_current_value=this.scale_desired_value;
		}
		this.repaint_draw2();
		return true;
	}

	private void exit_restore() {

		if (this.timer2!=0) {
			Source.remove(this.timer2);
		}
		
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
		
		if (file_ended!="") {
	
			GLib.stdout.printf("Terminado %s\n",file_ended);
			var current_time=time_t();
			var f=File.new_for_path(file_ended);
			try {
				f.set_attribute_uint64(FILE_ATTRIBUTE_TIME_MODIFIED,current_time,0,null);
				f.set_attribute_uint64(FILE_ATTRIBUTE_TIME_ACCESS,current_time,0,null);
			} catch (Error e) {
			}
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
		
		var path=this.browser.get_current_path();
		
		this.browser.get_selected_items(out files, out folders);
		foreach (string f in files) {
			var element = path_filename();
			element.original_file=GLib.Path.build_filename(path,f);
			element.restored_file=GLib.Path.build_filename(path,this.get_restored_filename(path,f));
			this.restore_files.add(element);
		}
		
		
  		foreach (string v in folders) {
		  	var restored_folder = GLib.Path.build_filename(path,this.get_restored_filename(path,v));
			this.add_folder_to_restore(GLib.Path.build_filename(path,v),restored_folder);
		}
		
		this.restoring_ended(this.backend,"",BACKUP_RETVAL.OK);
		
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
