/*
 Copyright 2011 (C) Raster Software Vigo (Sergio Costas)

 This file is part of Nanockup

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
using Posix;
using Gee;
using Gtk;
using Gdk;
using Cairo;

void show_usage() {
	GLib.stdout.printf("Usage:\n");
	GLib.stdout.printf("nanockup [-c|--config config_file] [-a|--add directory to backup] [-a|--add...] [-e|--exclude directory to exclude] [-e|--exclude...] [--hiden] [-h|--help] [-v|--version]\n");
	exit(0);
}

void print_version() {
	GLib.stdout.printf("Nanockup Version 0.3\n");
}

class nc_callback : GLib.Object, nsnanockup.callbacks {

	private StatusIcon trayicon;
	uint8 [] data_icon;

	public bool repaint(int size) {
	
		var canvas = new Cairo.ImageSurface(Cairo.Format.ARGB32,size,size);
		var ctx = new Cairo.Context(canvas);
		
		ctx.set_antialias(Cairo.Antialias.GRAY);
		ctx.scale(size,size);
		ctx.set_source_rgb(0,1,0);
		ctx.arc(0.5,0.5,0.3,0,2.0*Gsl.MathConst.M_PI);
		ctx.set_line_width(0.2);
		ctx.stroke();
		
		data_icon=new uint8[size*size*4];
		uint8 *p1=data_icon;
		uint8 *p2=canvas.get_data();
		int counter;
		int max;
		
		max=size*size*4;
		for(counter=0;counter<max;counter++) {
			*p1=*p2;
			p1++;
			p2++;
		}
		
		var pix=new Pixbuf.from_data(data_icon,Gdk.Colorspace.RGB,true,8,size,size,size*4,null);
		this.trayicon.set_from_pixbuf(pix);
		
		return true;
	}

	public nc_callback() {
		this.trayicon = new StatusIcon();
		this.trayicon.set_tooltip_text ("Tray");
		this.trayicon.set_visible(true);
		this.trayicon.size_changed.connect(this.repaint);
	}

	public void backup_folder(string dirpath) {
		GLib.stdout.printf("Backing up folder %s\n",dirpath);
	}
	
	public void backup_file(string filepath) {
		//GLib.stdout.printf("Backing up file %s\n",filepath);
	}
	
	public void backup_link_file(string filepath) {
		//GLib.stdout.printf("Linking file %s\n",filepath);
	}
	
	public void warning_link_file(string o_filepath, string d_filepath) {
		GLib.stdout.printf("Can't link file %s to %s\n",o_filepath,d_filepath);
	}
	
	public void error_copy_file(string o_filepath, string d_filepath) {
		GLib.stdout.printf("Can't copy file %s to %s\n",o_filepath,d_filepath);
	}
	
	public void error_access_directory(string dirpath) {
		GLib.stdout.printf("Can't access directory %s\n",dirpath);
	}
	
	public void error_create_directory(string dirpath) {
		GLib.stdout.printf("Can't create directory %s\n",dirpath);
	}
	
	public void excluding_folder(string dirpath) {
		//GLib.stdout.printf("Excluding folder %s\n",dirpath);
	}
}

void do_backup(nc_callback callbacks) {

	var basedir = new nsnanockup.nanockup(callbacks);
	int retval;

	if (0!=basedir.read_configuration(null)) {
		GLib.stdout.printf("Error reading configuration\n");
	}
	
	retval=basedir.do_backup();
	
	if (0!=retval) {
		return;
	}

	GLib.stdout.printf("Backup done! needed %ld seconds.\n",(long)basedir.time_used);

}

int main(string[] args) {
	
	
	Gdk.threads_init();
	Gtk.init(ref args);
	
	var callbacks = new nc_callback();
	
	Gtk.main();
	
	do_backup(callbacks);
	
	return 0;
}