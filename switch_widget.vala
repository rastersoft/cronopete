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
 
 /* A switch widget, since GTK2 has not it */
 
using Gtk;

public class Switch_Widget : DrawingArea {

	private int w;
	private int h;
	private int px;
	private int py;
	private bool _active;

	public Switch_Widget () {

		// Enable the events you wish to get notified about.
		// The 'expose' event is already enabled by the DrawingArea.
		this.add_events (Gdk.EventMask.BUTTON_RELEASE_MASK|Gdk.EventMask.BUTTON_PRESS_MASK|Gdk.EventMask.POINTER_MOTION_MASK|Gdk.EventMask.EXPOSURE_MASK|Gdk.EventMask.STRUCTURE_MASK);

		// Set favored widget size
		set_size_request (86, 26);
		this.w=86;
		this.h=26;
		this.px=0;
		this.py=0;
		this._active=false;
	}

	/* Widget is asked to draw itself */
	public override bool expose_event (Gdk.EventExpose event) {

		GLib.stdout.printf("Expose\n");
		// Create a Cairo context
		var cr = Gdk.cairo_create (this.window);

		// Set clipping area in order to avoid unnecessary drawing
		cr.rectangle (event.area.x, event.area.y,event.area.width, event.area.height);
		cr.clip ();

		cr.set_source_rgb(0,0,0);
		cr.rectangle(this.px,this.py,86,26);
		cr.fill();

		return false;
	}

	/* Mouse button got released */
	public override bool button_release_event (Gdk.EventButton event) {
		GLib.stdout.printf("Click\n");
		return false;
	}

	/*public override void show() {
	
		GLib.stdout.printf("show\n");
	}*/

	public override void size_allocate (Gdk.Rectangle allocation) {

		this.w=allocation.width;
		this.h=allocation.height;
		this.px=(this.w-86)/2;
		this.py=(this.h-26)/2;
		GLib.stdout.printf("Nuevo tamano: %d %d\n",this.w,this.h);
		base.size_allocate(allocation);
	}
}