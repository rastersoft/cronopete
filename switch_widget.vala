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
 
 /* A switch widget, since GTK2 doesn't have it */
 
using Gtk;

public class Switch_Widget : DrawingArea {

	private bool _active;
	public bool active {
		get {
			return (this._active);
		}
		
		set {
			this._active=value;
			if (this.visible) {
				this.refresh(null);
			}
		}
	}

	public signal void toggled(Switch_Widget w);

	public Switch_Widget () {

		// Enable the events you wish to get notified about.
		// The 'expose' event is already enabled by the DrawingArea.
		this.add_events (Gdk.EventMask.BUTTON_RELEASE_MASK|Gdk.EventMask.BUTTON_PRESS_MASK|Gdk.EventMask.POINTER_MOTION_MASK|Gdk.EventMask.EXPOSURE_MASK|Gdk.EventMask.STRUCTURE_MASK);

		// Set favored widget size
		set_size_request (86, 26);
		this._active=false;
	}

	/* Widget is asked to draw itself */
	public override bool expose_event (Gdk.EventExpose event) {

		return (this.refresh(event));
		
	}

	private bool refresh(Gdk.EventExpose? event) {

		int width;
		int height;
		int ox;
		int oy;
		int pos;
		
		this.window.get_size(out width,out height);

		ox=(width-86)/2;
		oy=(height-26)/2;

		// Create a Cairo context
		var cr = Gdk.cairo_create (this.window);

		// Set clipping area in order to avoid unnecessary drawing
		if (event!=null) {
			cr.rectangle (event.area.x, event.area.y,event.area.width, event.area.height);
			cr.clip ();
		}


		if (this._active) {
			cr.set_source_rgb(1.0,0.5,0.0);
		} else {
			cr.set_source_rgb(0.1,0.1,0.1);
		}
		this.do_switch(ox,oy,86,26,cr);
		cr.fill();
		cr.set_source_rgb(0.4,0.4,0.4);
		cr.set_line_width(1.0);
		this.do_switch(ox,oy,86,26,cr);
		cr.stroke();
		cr.set_source_rgb(0.0,0.0,0.0);
		cr.set_line_width(1.8);
		cr.move_to(ox+20,oy+6);
		cr.line_to(ox+26,oy+6);
		cr.move_to(ox+23,oy+6);
		cr.line_to(ox+23,oy+20);
		cr.move_to(ox+20,oy+20);
		cr.line_to(ox+26,oy+20);
		cr.stroke();
		cr.set_source_rgb(1.0,0.1,0.1);
		cr.arc(ox+63,oy+13,7,0,6.283182);
		cr.stroke();
		var pattern=new Cairo.Pattern.linear(ox,oy,ox,oy+26);
		pattern.add_color_stop_rgb(0.0,0.9,0.9,0.9);
		pattern.add_color_stop_rgb(1.0,0.6,0.6,0.6);
		cr.set_source(pattern);
		if (this._active) {
			pos=43;
		} else {
			pos=0;
		}
		this.do_switch(ox+pos,oy,43,26,cr);
		cr.fill();
		cr.set_source_rgb(0.4,0.4,0.4);
		cr.set_line_width(1.0);
		this.do_switch(ox+pos,oy,43,26,cr);
		cr.stroke();

		return false;
	}

	void do_switch(int ox, int oy, int size_x, int size_y, Cairo.Context cr) {
	
		int cx;
		int cy;
	
		cx = ox+size_x;
		cy = oy+size_y;
	
		cr.move_to(ox+5,oy+1);
		cr.line_to(cx-5,oy+1);
		cr.arc(cx-5,oy+5,4,4.712388,0);
		cr.line_to(cx-1,cy-5);
		cr.arc(cx-5,cy-5,4,0,1.570796);
		cr.line_to(ox+5,cy-1);
		cr.arc(ox+5,cy-5,4,1.570796,3.141592);
		cr.line_to(ox+1,oy+5);
		cr.arc(ox+5,oy+5,4,3.141592,4.712388);
		cr.close_path();

	}

	/* Mouse button got released */
	public override bool button_release_event (Gdk.EventButton event) {
		
		int width;
		int height;
		int ox;
		int oy;

		this.window.get_size(out width,out height);
		ox=(width-86)/2;
		oy=(height-26)/2;

		if ((event.x>=ox)&&(event.x<ox+86)&&(event.y>=oy)&&(event.y<oy+26)) {

			if (this._active) {
				this._active=false;
			} else {
				this._active=true;
			}
		
			this.window.clear_area_e(0,0,width,height);
			this.toggled(this);
		}
		return false;
	}
}
