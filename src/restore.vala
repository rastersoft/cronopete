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
	private double browser_margin;
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

	private int margin_around;

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

	private bool date_format;

	private Gtk.Window restore_window;
	private Gtk.Label restore_label;
	private Gtk.ProgressBar restore_bar;
	private Gtk.ProgressBar restore_file_bar;
	private bool cancel_restoring;
	private bool ignore_restoring_all;

	private Gtk.Window error_window;

	private uint timer_bar;

	private bool capture_done;
	private bool browserhide;

	private double my;
	private double mh;

	private double screen_w;
	private double screen_h;
	private int topmargin;

	private Gtk.Label current_date;

	private GLib.Settings cronopete_settings;

	private double incval;

	private bool doshow; // this is for testing

	public static int mysort_64(time_t? a, time_t? b) {

		if(a<b) {
			return 1;
		}
		if(a>b) {
			return -1;
		}
		return 0;
	}

	public restore_iface(backends p_backend,string paths,GLib.Settings stg) {

		this.doshow=true; // if false, will not paint the windows, allowing to check the background rendering

		this.cronopete_settings=stg;
		this.backend=p_backend;
		this.backend.lock_delete_backup(true);
		this.basepath=paths;

		this.topmargin=0;
		this.scale_current_value=-1;
		this.windows_current_value=-1;
		this.zmul=1000;
		this.capture_done=false;

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
		this.scr_w=0;
		this.screen_w=scr.get_width();
		this.scr_h=0;
		this.screen_h=scr.get_height();

		//this.scr_w=640;
		//this.scr_h=480; // for tests

		this.base_layout = new Fixed();

		this.drawing = new DrawingArea();

		this.base_layout.add(this.drawing);

		this.box = new EventBox();
		this.box.add_events (Gdk.EventMask.SCROLL_MASK|Gdk.EventMask.BUTTON_RELEASE_MASK|Gdk.EventMask.KEY_PRESS_MASK|Gdk.EventMask.KEY_RELEASE_MASK);
		this.box.add(this.base_layout);

#if USE_GTK2
		var main_box=new Gtk.VBox(false,0);
		var button_box=new Gtk.HBox(false,0);
		var container1=new Gtk.HBox(false,0);
		var container2=new Gtk.HBox(false,0);

		// quirk way of centering the text and the icon in Gtk2
		container1.pack_start(new Gtk.Label(""),true,true,0);
		container2.pack_start(new Gtk.Label(""),true,true,0);
#else
		var main_box=new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		var button_box=new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
		var container1=new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
		var container2=new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
		container1.halign=Gtk.Align.CENTER;
		container2.halign=Gtk.Align.CENTER;
#endif


		this.current_date=new Label("<span size=\"xx-large\"> </span>");
		this.current_date.use_markup=true;

		var pic1=new Gtk.Image.from_stock(Gtk.Stock.REVERT_TO_SAVED,Gtk.IconSize.DND);
		var label1=new Label("<span size=\"xx-large\">"+_("Restore files")+"</span>");
		label1.use_markup=true;
		container1.pack_start(pic1,false,false,0);
		container1.pack_start(label1,false,false,0);
		var restore_button=new Gtk.Button();
		restore_button.add(container1);

		var pic2=new Gtk.Image.from_stock(Gtk.Stock.QUIT,Gtk.IconSize.DND);
		var label2=new Label("<span size=\"xx-large\">"+_("Exit")+"</span>");
		label2.use_markup=true;
		container2.pack_start(pic2,false,false,0);
		container2.pack_start(label2,false,false,0);
		var quit_button=new Gtk.Button();
		quit_button.add(container2);

#if USE_GTK2
		// quirk way of centering the text and the icon in Gtk2
		container1.pack_start(new Gtk.Label(""),true,true,0);
		container2.pack_start(new Gtk.Label(""),true,true,0);
#endif

		restore_button.clicked.connect(this.do_restore);
		quit_button.clicked.connect(this.exit_restore);

		var sizegroup=new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
		sizegroup.add_widget(restore_button);
		sizegroup.add_widget(quit_button);

		button_box.pack_start(restore_button,false,false,0);
		button_box.pack_start(this.current_date,true,true,0);
		button_box.pack_start(quit_button,false,false,0);

		main_box.pack_start(button_box,false,true,0);
		main_box.pack_start(box,true,true,0);

		this.mywindow.add(main_box);

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

		//this.create_cairo_layouts();

		this.base_layout.add(this.browser);

		this.paint_window();

		this.backend.restore_ended.connect(this.restoring_ended);
		this.backend.status.connect(this.refresh_status);

#if USE_GTK2
		this.drawing.expose_event.connect(this.repaint_draw);
#else
		this.drawing.draw.connect(this.repaint_draw3);
#endif

		this.mywindow.show_all();

		this.desired_alpha=0.0;
		GLib.Timeout.add(250,start_all,0); // wait to end the window animation

	}

	public bool start_all() {
		this.desired_alpha=1.0;
		this.launch_animation();
		return false;
	}

	public void changed_path_list() {

		this.capture_done=false;
		this.launch_animation ();

	}

	public bool do_show() {

		this.browser.do_refresh_icons ();
		this.browserhide=true;
		this.capture_done=true;
		//this.repaint_draw2();
		this.paint_window();
		return false;
	}

	public void refresh_status(usbhd_backend? b) {

		if (b.available==false) {
			this.exit_restore ();
		}
	}

	private void create_cairo_layouts() {

		Allocation fsize;
		this.base_layout.get_allocation(out fsize);
		if ((fsize.width<=0)||(fsize.height<=0)) {
			return;
		}
		if ((fsize.width==this.scr_w)&&(fsize.height==this.scr_h)) {
			return;
		}

		this.scr_w=fsize.width;
		this.scr_h=fsize.height;

		double top_margin=this.screen_h-((double)this.scr_h);
		this.topmargin=(int)top_margin;

		this.drawing.width_request=this.scr_w;
		this.drawing.height_request=this.scr_h;

		this.base_surface = new Cairo.ImageSurface(Cairo.Format.ARGB32,this.scr_w,this.scr_h);
		this.final_surface = new Cairo.ImageSurface(Cairo.Format.ARGB32,this.scr_w,this.scr_h);
		this.animation_surface = new Cairo.ImageSurface(Cairo.Format.ARGB32,this.scr_w,this.scr_h);

		double w;
		w=(this.scr_w);
		double h;
		h=(this.scr_h);
		double scale;
		var c_base = new Cairo.Context(this.base_surface);

		var tonecolor=this.cronopete_settings.get_string("toning-color");
		Color tonecolor_final;
		Gdk.Color.parse(tonecolor,out tonecolor_final);

		int32 final_r;
		int32 final_g;
		int32 final_b;

		final_r=tonecolor_final.red/256;
		final_g=tonecolor_final.green/256;
		final_b=tonecolor_final.blue/256;

		var list_schemas = GLib.Settings.list_schemas();

		bool gnome_found=false;

		foreach(var v in list_schemas) {
			if (v=="org.gnome.desktop.background") {
				gnome_found=true;
				break;
			}
		}

		string bgstr;
		string bgformat;
		string bgcolor;

		bgcolor="#7f7f7f7f7f7f";
		bgstr="";
		bgformat="";

		if (gnome_found) {
			var stng = new GLib.Settings("org.gnome.desktop.background");
			var entries_list = stng.list_keys();
			foreach(var v in entries_list) {
				if (v=="primary-color") {
					bgcolor=stng.get_string("primary-color");
				} else if (v=="picture-uri") {
					bgstr = stng.get_string("picture-uri");
				} else if (v=="picture-options") {
					bgformat=stng.get_string("picture-options");
				}
			}
		}

		Color bgcolor_final;
		Gdk.Color.parse(bgcolor,out bgcolor_final);

		int32 r;
		int32 g;
		int32 b;
		int32 bas;

		r=bgcolor_final.red/256;
		g=bgcolor_final.green/256;
		b=bgcolor_final.blue/256;

		bas=(r*3+g*6+b)/10;
		// tone to sepia
		if (bas<128) {
			r=(final_r*bas)/128;
			g=(final_g*bas)/128;
			b=(final_b*bas)/128;
		} else {
			r=final_r+(((255-final_r)*(bas-128))/127);
			g=final_g+(((255-final_g)*(bas-128))/127);
			b=final_b+(((255-final_b)*(bas-128))/127);
		}

		c_base.set_source_rgb(((double)r)/255.0,((double)g)/255.0,((double)b)/255.0);
		c_base.paint();

		Gdk.Pixbuf ?bgpic=null;
		double px_w=this.screen_w;
		double px_h=this.screen_h;
		try {
			if ((bgstr.length>6)&&(bgstr.substring(0,7)=="file://")) {
				var tmpfile = GLib.File.new_for_uri(bgstr);
				bgstr=tmpfile.get_path();
			}
			bgpic = new Gdk.Pixbuf.from_file(bgstr);
			px_w=(double)bgpic.width;
			px_h=(double)bgpic.height;
			int x;
			int y;
			unowned uint8 *data;
			data = bgpic.pixels;

			var has_alpha = bgpic.has_alpha;

			for(y=0;y<bgpic.height;y++) {
				for(x=0;x<bgpic.width;x++) {
					r=*(data);
					g=*(data+1);
					b=*(data+2);
					bas=(r*3+g*6+b)/10;
					// tone to sepia
					if (bas<128) {
						r=(final_r*bas)/128;
						g=(final_g*bas)/128;
						b=(final_b*bas)/128;
					} else {
						r=final_r+(((255-final_r)*(bas-128))/127);
						g=final_g+(((255-final_g)*(bas-128))/127);
						b=final_b+(((255-final_b)*(bas-128))/127);
					}

					*(data++)=r;
					*(data++)=g;
					*(data++)=b;
					if(has_alpha) {
						data++;
					}
				}
			}
		} catch(GLib.Error v) {
		}

		if (bgpic!=null) {
			if (bgformat=="wallpaper") { // repeat it several times
				double l1;
				double l2;
				double s1=0.0;
				double s2=0.0;
				if (px_w>this.screen_w) {
					s1=(this.screen_w-px_w)/2.0;
				}
				if (px_h>this.screen_h) {
					s2=(this.screen_h-px_h)/2.0;
				}
				for(l2=s2;l2<this.screen_h;l2+=px_h) {
					for(l1=s1;l1<this.screen_w;l1+=px_w) {
						Gdk.cairo_set_source_pixbuf(c_base,bgpic,l1,l2-top_margin);
						c_base.paint();
					}
				}

			} else if (bgformat=="centered") {
				double s1=0.0;
				double s2=0.0;
				s1=(this.screen_w-px_w)/2.0;
				s2=(this.screen_h-px_h)/2.0;
				Gdk.cairo_set_source_pixbuf(c_base,bgpic,s1,s2-top_margin);
				c_base.paint();

			} else if ((bgformat=="scaled")||(bgformat=="spanned")) {
				c_base.save();
				double new_w=px_w*(this.screen_h/px_h);
				double new_h=px_h*(this.screen_w/px_w);
				if (new_w>this.screen_w) { // width is the limiting factor
					double factor=screen_w/px_w;
					c_base.scale(factor,factor);
					Gdk.cairo_set_source_pixbuf(c_base,bgpic,0,(this.screen_h-new_h)/(2.0*factor)-(top_margin/factor));
				} else { // height is the limiting factor
					double factor=screen_h/px_h;
					c_base.scale(factor,factor);
					Gdk.cairo_set_source_pixbuf(c_base,bgpic,(this.screen_w-new_w)/(2.0*factor),-(top_margin/factor));
				}
				c_base.paint();
				c_base.restore();

			} else if (bgformat=="stretched") {
				c_base.save();
				double factor=screen_h/px_h;
				c_base.scale(screen_w/px_w,factor);
				Gdk.cairo_set_source_pixbuf(c_base,bgpic,0,-(top_margin/factor));
				c_base.paint();
				c_base.restore();

			} else if (bgformat=="zoom") {
				c_base.save();
				double new_w=px_w*(this.screen_h/px_h);
				double new_h=px_h*(this.screen_w/px_w);
				if (new_h>this.screen_h) {
					double factor=screen_w/px_w;
					c_base.scale(factor,factor);
					Gdk.cairo_set_source_pixbuf(c_base,bgpic,0,(this.screen_h-new_h)/(2.0*factor)-(top_margin/factor));
				} else {
					double factor=screen_h/px_h;
					c_base.scale(factor,factor);
					Gdk.cairo_set_source_pixbuf(c_base,bgpic,(this.screen_w-new_w)/(2.0*factor),-(top_margin/factor));
				}
				c_base.paint();
				c_base.restore();

			}
		}

		scale=w/2800.0;

		this.margin_around=this.scr_h/20;
		this.mh=0.0;
		// Browser border
		this.browser_x=scr_w*0.1;
		this.browser_y=this.mh+this.margin_around;
		this.browser_margin=this.scr_h/8.0;
		this.browser_w=scr_w*4.0/5.0;
		this.browser_h=this.scr_h-this.browser_y-this.browser_margin-this.margin_around;
		double scale2=(w-60.0-100.0*scale)/2175.0;
		c_base.save();
		c_base.scale(scale2,scale2);

		// arrows
		var arrows_pic = new Cairo.ImageSurface.from_png(GLib.Path.build_filename(this.basepath,"arrows.png"));
		this.arrows_x=(this.browser_x+this.browser_w)-256.0*scale2;
		this.arrows_y=this.browser_y/2.0;
		this.arrows_w=256.0*scale2;
		this.arrows_h=150.0*scale2;
		c_base.set_source_surface(arrows_pic,this.arrows_x/scale2,this.arrows_y/scale2);
		c_base.paint();
		c_base.restore();

		// timeline
		this.scale_x=this.restore_x;
		this.scale_y=this.browser_y;
		this.scale_w=this.scr_w/28.0;
		this.scale_h=this.browser_h+this.browser_margin;

		this.last_time=this.backups[this.backups.size-1];
		this.scale_factor=this.scale_h/(this.backups[0]-this.last_time);

		double last_pos_y=-1;
		double pos_y=this.scale_y+this.scale_h;
		double new_y;

		this.incval = this.scale_w/5.0;
		double nw = this.scale_w*3.0/5.0;
		this.scale_x+=this.incval/2.0;

		c_base.set_source_rgba(0,0,0,0.6);
		this.rounded_rectangle(c_base,this.scale_x,this.scale_y-incval,this.scale_w,this.scale_h+2.0*incval,2.0*incval);
		c_base.fill();

		c_base.set_source_rgb(1,1,1);
		c_base.set_line_width(1);

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

		this.browser.width_request=(int)(this.browser_w);
		this.browser.height_request=(int)(this.browser_h);
		this.base_layout.move(this.browser,(int)(this.browser_x),(int)(this.browser_y+this.browser_margin));
	}

	public void rounded_rectangle(Cairo.Context context, double x, double y, double w, double h, double r) {

		context.move_to(x+r,y);
		context.line_to(x+w-r,y);
		context.curve_to(x+w,y,x+w,y,x+w,y+r);
		context.line_to(x+w,y+h-r);
		context.curve_to(x+w,y+h,x+w,y+h,x+w-r,y+h);
		context.line_to(x+r,y+h);
		context.curve_to(x,y+h,x,y+h,x,y+h-r);
		context.line_to(x,y+r);
		context.curve_to(x,y,x,y,x+r,y);
	}


	private void paint_window() {

		this.current_instant=this.backups[this.pos];

		var ctx = new Cairo.Context(this.final_surface);
		ctx.set_source_surface(this.base_surface,0,0);
		ctx.paint();

		this.print_nixies(this.current_instant);
		this.scale_desired_value = this.scale_y+this.scale_h-this.scale_factor * (this.current_instant-this.last_time);
		if (this.scale_current_value==-1) {
			this.scale_current_value=this.scale_desired_value;
		}
	}

	private bool repaint_draw(EventExpose ev) {
		this.repaint_draw2();
		return false;
	}

	private void repaint_draw2() {

		var ctx = new Cairo.Context(this.animation_surface);
		this.repaint_draw3 (ctx);

	}

	private bool repaint_draw3(Context ctx) {

		this.create_cairo_layouts();

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
		double s_factor;
		ctx.set_line_width(1.5);
		ctx.set_source_rgb(0.2,0.2,0.2);
		for(int c=maxval-1;c>=this.pos;c--) {
			double z;
			z=this.zmul*c-(this.windows_current_value);
			if (z<0) {
				continue;
			}

			this.transform_coords (z,out ox, out oy, out ow, out oh, out s_factor);
			ctx.select_font_face("Sans",FontSlant.NORMAL,FontWeight.BOLD);
			ctx.set_font_size(18.0*s_factor);
			var ctime = GLib.Time.local(this.backups[c]);
			string date;
			if (this.date_format) {
				date="%02d:%02d %02d/%02d/%04d".printf(ctime.hour,ctime.minute,ctime.day,ctime.month+1,1900+ctime.year);
			} else {
				date="%02d:%02d %02d/%02d/%04d".printf(ctime.hour,ctime.minute,ctime.month+1,ctime.day,1900+ctime.year);
			}

			Cairo.TextExtents extents;
			ctx.text_extents(date,out extents);
			ctx.set_source_rgb(1,1,1);

			double final_add=4.0*s_factor;

			ctx.rectangle(ox,oy-2*final_add-extents.height,ow,oh+2*final_add+extents.height);
			if (this.doshow) {
				ctx.fill();
			}
			ctx.set_source_rgb(0.0, 0.0, 0.0);
			ctx.rectangle(ox,oy-2*final_add-extents.height,ow,oh+2*final_add+extents.height);
			ctx.stroke();
			ctx.move_to(ox+(ow-extents.width+extents.x_bearing)/2, oy-extents.height-extents.y_bearing-final_add);

			ctx.show_text(date);

		}

		var ctx2 = Gdk.cairo_create(this.drawing.get_window());
		ctx2.set_source_surface(this.animation_surface,0,0);
		ctx2.paint();
		return false;
	}

	private void transform_coords(double z, out double ox, out double oy, out double ow, out double oh, out double s_factor) {

		double eyedist = 2500.0;

		ox=(this.browser_x*eyedist+(z*((double)this.scr_w)/2))/(z+eyedist);
		oy=((this.browser_margin)*eyedist)/(z+eyedist);
		ow=(this.browser_w*eyedist)/(z+eyedist);
		oh=(this.browser_h*eyedist)/(z+eyedist);
		oy+=this.browser_y;
		s_factor=eyedist/(z+eyedist);
	}

	private void print_nixies(time_t backup_date) {

		var ctime = GLib.Time.local(backup_date);
		var ctime_now = GLib.Time.local(time_t());
		var ctime_yesterday = GLib.Time.local(time_t()-86400);

		string date;
		if ((ctime_now.day==ctime.day)&&(ctime_now.month==ctime.month)&&(ctime_now.year==ctime.year)) {
			/// This string is used to show the date of a backup when it is in today;
			/// %H gets replaced by the hour, and %M by the minute of the backup
			/// Singular and plurar forms are chosen based on the hour's value (%H)
			date=ctime.format(ngettext("Today, at %H:%M","Today, at %H:%M",ctime.hour));
		} else if ((ctime_yesterday.day==ctime.day)&&(ctime_yesterday.month==ctime.month)&&(ctime_yesterday.year==ctime.year)) {
			/// This string is used to show the date of a backup when it is in yesterday;
			/// %H gets replaced by the hour, and %M by the minute of the backup
			/// Singular and plurar forms are chosen based on the hour's value (%H)
			date=ctime.format(ngettext("Yesterday, at %H:%M","Yesterday, at %H:%M",ctime.hour));
		} else {
			if (this.date_format) {
				/// This string is used to show the date of a backup in european format (day/month/year);
				/// %A gets replaced by the day's name; %d by the day (in number);
				/// %B by the month (in letters); %Y by the year in four-digits format
				/// %H gets replaced by the hour, and %M by the minute of the backup
				/// Singular and plurar forms are chosen based on the hour's value (%H)
				date=ctime.format(ngettext("%A, %d %B %Y at %H:%M","%A, %d %B %Y at %H:%M",ctime.hour));
			} else {
				/// This string is used to show the date of a backup in USA format (month/day/year);
				/// %A gets replaced by the day's name; %B by the month (in letters);
				/// %d by the day (in number); %Y by the year in four-digits format
				/// %H gets replaced by the hour, and %M by the minute of the backup
				/// Singular and plurar forms are chosen based on the hour's value (%H)
				date=ctime.format(ngettext("%A, %B %d %Y at %H:%M","%A, %B %d %Y at %H:%M",ctime.hour));
			}
		}
		this.current_date.set_markup("<span size=\"xx-large\">"+date+"</span>");
	}

	private bool on_click(Gdk.EventButton event) {

		if(event.button!=1) {
			return false;
		}

		if ((event.x_root>=this.arrows_x)&&(event.x_root<(this.arrows_x+(this.arrows_w/2)))&&(event.y_root>=this.arrows_y+this.topmargin)&&(event.y_root<(this.arrows_y+this.arrows_h+this.topmargin))) {
			this.move_timeline(false);
			return true;
		}
		if ((event.x_root>=(this.arrows_x+(this.arrows_w/2)))&&(event.x_root<(this.arrows_x+this.arrows_w))&&(event.y_root>=this.arrows_y+this.topmargin)&&(event.y_root<(this.arrows_y+this.arrows_h+this.topmargin))) {
			this.move_timeline(true);
			return true;
		}
		return false;

	}

	private bool on_scroll(Gdk.EventScroll event) {

		if ((event.x_root>=((int)this.browser_x))&&(event.x_root<((int)(this.browser_x+this.browser_w)))&&(event.y_root>=((int)(this.browser_y+this.browser_margin+this.topmargin)))&&(event.y_root<((int)(this.browser_y+this.browser_margin+this.browser_h+this.topmargin)))) {
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
				this.browser_visible(false);
				this.browserhide=true;
				this.pos++;
			}
		} else {
			if (this.pos==0) {
				return;
			} else {
				this.browser_visible(false);
				this.browserhide=true;
				this.pos--;
			}
		}

		this.browser.set_backup_time(this.backups[this.pos]);
		this.paint_window();
		this.launch_animation();
	}

	private void browser_visible(bool visible) {

		if(visible) {
			if (this.doshow) {
				this.browser.show();
			} else {
				this.browser.hide();
			}
		} else {
			this.browser.hide();
		}
	}

	private void launch_animation() {
		if (this.timer==0) {
			this.timer=GLib.Timeout.add(40,this.timer_move);
		}
	}

	private bool timer_move() {

		bool end_animation=true;
		bool do_repaint=false;

		if (this.capture_done==false) {
			GLib.Idle.add(this.do_show);
			this.capture_done=true;
		}

		if (this.scale_current_value!=this.scale_desired_value) {
			double diff;
			end_animation=false;
			if (this.scale_current_value>this.scale_desired_value) {
				diff=this.scale_current_value-this.scale_desired_value;
				this.scale_current_value-=(diff/4);
			} else {
				diff=this.scale_desired_value-this.scale_current_value;
				this.scale_current_value+=(diff/4);
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
				this.backend.restore_ended.disconnect(this.restoring_ended);
				this.backend.status.disconnect(this.refresh_status);
				this.mywindow.hide();
				this.browser.hide();
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
			this.browser.do_refresh_icons();
			this.browser_visible(true);
			this.browserhide=false; // repaint all, to ensure that there is no failure when ending animation
			return false;
		} else {
			return true;
		}
	}

	private void exit_restore() {

		this.launch_animation ();

		this.desired_alpha=0.0;

		this.launch_animation ();

	}

	private string get_restored_filename(string path, string filename) {

		int pos,pos2;
		string preffix;
		string suffix;

		if ((filename[0]=='.')&&(-1==filename.index_of_char('.',1))) {
			preffix=filename;
			suffix="";
		} else {
			pos=-1;
			pos2=pos;
			do {
				pos2=filename.index_of_char('.',pos+1);
				if (pos2>=0) {
					pos=pos2;
				}
			} while(pos2!=-1);

			if (pos==-1) {
				preffix=filename;
				suffix="";
			} else {
				preffix=filename.slice(0,pos);
				suffix=filename.substring(pos);
			}
		}

		string newfilename="%s.restored%s".printf(preffix,suffix);
		int counter=1;
		File fs;

		while(true) {
			fs = File.new_for_path(GLib.Path.build_filename(path,newfilename));
			if (fs.query_exists()) {
				newfilename="%s.restored.%d%s".printf(preffix,counter,suffix);
				counter++;
			} else {
				break;
			}
		}

		return newfilename;
	}

	public void restore_progress_cb (int64 current_num_bytes, int64 total_num_bytes) {

		double a;
		double b;

		a=(double)current_num_bytes;
		b=(double)total_num_bytes;

		this.restore_file_bar.fraction=a/b;
	}

	public async void restoring_ended() {

		BACKUP_RETVAL rv;

		while(!this.restore_files.is_empty) {

			var percent=1.0-(((double)this.restore_files.size)/this.total_to_restore);
			var filename = this.restore_files.get(0);
			this.restore_files.remove_at(0);
			this.restore_label.label=_("Restoring file:\n\n%s").printf(filename.restored_file);
			this.restore_bar.fraction=percent;
			this.restore_file_bar.fraction=0.0;
			rv=yield this.backend.restore_file(filename.original_file,this.backups[this.pos],filename.restored_file,this.restore_progress_cb);

			if (this.cancel_restoring) {
				this.restore_files.clear();

			} else if ((rv!=BACKUP_RETVAL.OK)&&(this.ignore_restoring_all==false)) {

				string error_msg;
				if (rv==BACKUP_RETVAL.NO_SPC) {
					error_msg=_("Failed to restore file\n\n%s\n\nThere's not enought free space").printf(filename.restored_file);
				} else {
					error_msg=_("Failed to restore file\n\n%s").printf(filename.restored_file);
				}

				var w2 = new Builder();

				w2.add_from_file(GLib.Path.build_filename(this.basepath,"restore_error.ui"));
				w2.connect_signals(this);
				this.error_window = (Gtk.Window)w2.get_object("restore_error");
				var error_label = (Gtk.Label)w2.get_object("error_msg");
				error_label.label=error_msg;

				error_window.show_all();
				this.restore_files.clear();
			} else {
				var current_time=time_t();
				var f=File.new_for_path(filename.restored_file);
				try {
					f.set_attribute_uint64(FileAttribute.TIME_MODIFIED,current_time,0,null);
					f.set_attribute_uint64(FileAttribute.TIME_ACCESS,current_time,0,null);
				} catch (Error e) {
				}
			}
		}

		this.mywindow.get_window().set_cursor(null);
		this.restore_window.destroy();

		var w = new Builder();
		w.add_from_file(GLib.Path.build_filename(this.basepath,"restore_ok.ui"));
		var rok = (Gtk.Window)w.get_object("restore_ok");
		var button = (Gtk.Button)w.get_object("restore_ok_button");
		button.clicked.connect(() => {
			restoring_ended.callback();
		});
		rok.delete_event.connect(() => {
			restoring_ended.callback();
			return true;
		});
		rok.focus_out_event.connect(() => { // If we click outside the window, destroy it
			restoring_ended.callback();
			return false;
		});
		rok.show();
		yield;
		rok.hide();
		rok.destroy();
		return;
	}

	private void do_restore() {

		this.launch_animation ();

		this.ignore_restoring_all=false;
		var w = new Builder();

		w.add_from_file(GLib.Path.build_filename(this.basepath,"restoring.ui"));
		w.connect_signals(this);

		this.restore_window = (Gtk.Window)w.get_object("restore_status");
		this.restore_bar = (Gtk.ProgressBar)w.get_object("restore_progressbar");
		this.restore_file_bar = (Gtk.ProgressBar)w.get_object("restore_file_progressbar");
		this.restore_label = (Gtk.Label)w.get_object("restoring_file");

		this.cancel_restoring=false;
		this.restore_label.label=_("Preparing folders to restore");
		this.restore_window.show_all();
		this.timer_bar=GLib.Timeout.add(250,this.timer_bar_f);

		var cursor_working = new Gdk.Cursor(Gdk.CursorType.WATCH);
		this.mywindow.get_window().set_cursor(cursor_working);

		this.launch_fill_restore_list.begin( (obj,res) => {
			this.launch_fill_restore_list.end(res);
			Source.remove(this.timer_bar);
			if (!this.cancel_restoring) {
				this.total_to_restore=(double)this.restore_files.size;
				this.restoring_ended.begin();
			} else {
				this.restore_files.clear();
				this.restore_window.destroy();
				this.mywindow.get_window().set_cursor(null);
			}
		});
	}

	public bool timer_bar_f() {
		this.restore_bar.pulse();
		return true;
	}

	private async void launch_fill_restore_list() {

		Gee.List<string> files;
		Gee.List<string> folders;

		var path=this.browser.get_current_path();

		this.browser.get_selected_items(out files, out folders);
		foreach (string f in files) {
			if (this.cancel_restoring) {
				return;
			}
			var element = path_filename();
			element.original_file=GLib.Path.build_filename(path,f);
			element.restored_file=GLib.Path.build_filename(path,this.get_restored_filename(path,f));
			this.restore_files.add(element);
			GLib.Idle.add(launch_fill_restore_list.callback);
			yield;
		}

		foreach (string v in folders) {
			if (this.cancel_restoring) {
				return;
			}
			var restored_folder = GLib.Path.build_filename(path,this.get_restored_filename(path,v));
			var rv=yield this.add_folder_to_restore(GLib.Path.build_filename(path,v),restored_folder);
			if (rv!=BACKUP_RETVAL.OK) {
				GLib.Idle.add(launch_fill_restore_list.callback);
				yield;
			}
		}
	}

	private async BACKUP_RETVAL add_folder_to_restore(string o_path, string f_path) {

		Gee.List<file_info ?> files;
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
				yield this.add_folder_to_restore(new_opath,new_rpath);
			} else {
				var element = path_filename();
				element.original_file=GLib.Path.build_filename(o_path,v.name);
				element.restored_file=GLib.Path.build_filename(f_path,v.name);
				this.restore_files.add(element);
			}
			GLib.Idle.add(add_folder_to_restore.callback);
			yield;
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
		this.restoring_ended.begin();
	}

	[CCode (instance_pos = -1)]
	public void on_ignore_restore_error_clicked(Button source) {
		this.error_window.destroy();
		this.restoring_ended.begin();
	}

	[CCode (instance_pos = -1)]
	public void on_ignore_all_restore_error_clicked(Button source) {
		this.ignore_restoring_all=true;
		this.error_window.destroy();
		this.restoring_ended.begin();
	}

	[CCode (instance_pos = -1)]
	public bool on_delete_event(Event event) {
		return true;
	}
}
