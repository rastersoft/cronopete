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
using Gsl;

enum SystemStatus { IDLE, BACKING_UP, ENDED }
enum BackupStatus { STOPPED, ALLFINE, WARNING, ERROR }

class nc_callback : GLib.Object, nsnanockup.callbacks {

	private StatusIcon trayicon;
	private SystemStatus backup_running;
	private BackupStatus current_status;
	private double angle;
	private int size;
	private unowned Thread <void *> b_thread;
	private uint timer;
	private StringBuilder messages;

	public void PixbufDestroyNotify (uint8* pixels) {
		delete pixels;	
	}

	public bool timer_f() {
	
		if (this.backup_running==SystemStatus.IDLE) {
			this.backup_running=SystemStatus.BACKING_UP;
			b_thread=Thread.create <void *>(this.do_backup, false);
			if (this.timer!=0) {
				Source.remove(this.timer);
			}
			this.timer=Timeout.add(20,this.timer_f);
		}
		if (this.backup_running==SystemStatus.ENDED) {
			this.backup_running=SystemStatus.IDLE;
			if (this.current_status==BackupStatus.ALLFINE) {
				this.current_status=BackupStatus.STOPPED;
			}
			if (this.timer!=0) {
				Source.remove(this.timer);
			}
			this.timer=Timeout.add(3600000,this.timer_f);
		}
		this.repaint(this.size);
		this.angle-=0.20;
		this.angle%=120.0*Gsl.MathConst.M_PI;
		return true;
	}

	public bool repaint(int size) {
	
		if (size==0) {
			return false;
		}
	
		this.size = size;
	
		var canvas = new Cairo.ImageSurface(Cairo.Format.ARGB32,size,size);
		var ctx = new Cairo.Context(canvas);
		
		//ctx.set_antialias(Cairo.Antialias.GRAY);
		ctx.scale(size,size);

		switch (this.current_status) {
		case BackupStatus.STOPPED:
			ctx.set_source_rgb(1,1,1);
		break;
		case BackupStatus.ALLFINE:
			ctx.set_source_rgb(0,1,0);
		break;
		case BackupStatus.WARNING:
			ctx.set_source_rgb(1,1,0);
		break;
		case BackupStatus.ERROR:
			ctx.set_source_rgb(1,0,0);
		break;
		}
		ctx.arc(0.5,0.5,0.4,0,2.0*Gsl.MathConst.M_PI);
		ctx.set_line_width(0.1);
		ctx.stroke();
		ctx.translate(0.5,0.5);
		ctx.save();
		ctx.rotate(this.angle);
		ctx.move_to(0,0.02);
		ctx.line_to(0,-0.4);
		ctx.stroke();
		ctx.restore();
		ctx.rotate(this.angle/30);
		ctx.move_to(0,0.02);
		ctx.line_to(0,-0.25);
		ctx.stroke();
		
		uint8 *data_icon=new uint8[size*size*4];
		uint8 *p1=data_icon;
		uint8 *p2=canvas.get_data();
		int counter;
		
		int max=size*size;
		for(counter=0;counter<max;counter++) {
			*p1    =*(p2+2);
			*(p1+1)=*(p2+1);
			*(p1+2)=*p2;
			*(p1+3)=*(p2+3);
			p1+=4;
			p2+=4;
		}
		
		var pix=new Pixbuf.from_data((uint8[])data_icon,Gdk.Colorspace.RGB,true,8,size,size,size*4,PixbufDestroyNotify);
		this.trayicon.set_from_pixbuf(pix);
		return true;
	}

	public nc_callback() {
	
		this.messages = new StringBuilder("");
		this.backup_running = SystemStatus.IDLE;
		this.current_status = BackupStatus.STOPPED;
		this.angle = 0.0;
		this.size = 0;
		this.timer = 0;
	
		this.trayicon = new StatusIcon();
		this.trayicon.set_tooltip_text ("Idle");
		this.trayicon.set_visible(true);
		this.trayicon.size_changed.connect(this.repaint);
		this.trayicon.activate.connect(() => {GLib.stdout.printf("%s",this.messages.str); } );
		this.timer_f();
	}

	public void backup_folder(string dirpath) {
		
		string message = "Backing up folder %s\n".printf(dirpath);
		
		this.trayicon.set_tooltip_text (message);
	}
	
	public void backup_file(string filepath) {
		//GLib.stdout.printf("Backing up file %s\n",filepath);
	}
	
	public void backup_link_file(string filepath) {
		//GLib.stdout.printf("Linking file %s\n",filepath);
	}
	
	public void warning_link_file(string o_filepath, string d_filepath) {
		//GLib.stdout.printf("Can't link file %s to %s\n",o_filepath,d_filepath);
	}
	
	public void error_copy_file(string o_filepath, string d_filepath) {
		this.current_status=BackupStatus.WARNING;
		this.messages.append_printf("Can't copy file %s to %s\n",o_filepath,d_filepath);
	}
	
	public void error_access_directory(string dirpath) {
		this.current_status=BackupStatus.WARNING;
		this.messages.append_printf("Can't access directory %s\n",dirpath);
	}
	
	public void error_create_directory(string dirpath) {
		this.current_status=BackupStatus.WARNING;
		this.messages.append_printf("Can't create directory %s\n",dirpath);
	}
	
	public void excluding_folder(string dirpath) {
		//GLib.stdout.printf("Excluding folder %s\n",dirpath);
	}
	
	void* do_backup() {

		var basedir = new nsnanockup.nanockup(this);
		int retval;

		this.messages = new StringBuilder("Starting backup\n");
		
		this.current_status=BackupStatus.ALLFINE;
		if (0!=basedir.read_configuration(null)) {
			this.current_status=BackupStatus.ERROR;
			this.backup_running=SystemStatus.ENDED;
			this.trayicon.set_tooltip_text ("Error reading configuration");
			return null;
		}
	
		retval=basedir.do_backup();
		this.backup_running=SystemStatus.ENDED;
		switch (retval) {
		case 0:
			this.trayicon.set_tooltip_text ("Backup done!");
			this.messages.append_printf("Backup done. Needed %ld seconds.\n",(long)basedir.time_used);
		break;
		case -1:
			this.current_status=BackupStatus.WARNING;
		break;
		default:
			this.trayicon.set_tooltip_text ("Can't do backup");
			this.current_status=BackupStatus.ERROR;
		break;
		}

		return null;
	}
}


int main(string[] args) {
	
	
	Gdk.threads_init();
	Gtk.init(ref args);
	
	var callbacks = new nc_callback();
	
	Gtk.main();
	
	return 0;
}