/*
 Copyright 2011-2015 (C) Raster Software Vigo (Sergio Costas)

 This file is part of Cronopete

 Cronopete is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 3 of the License, or
 (at your option) any later version.

 Cronopete is distributed in the hope that it will be useful,
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
using Posix;

// project version=3.27.0

#if !NO_APPINDICATOR
using AppIndicator;
#endif

enum SystemStatus { IDLE, BACKING_UP, ABORTING, ENDED }
enum BackupStatus { STOPPED, ALLFINE, WARNING, ERROR }

void print_debug(string debug) {
	print(debug+"\n");
}

void print_file(string filename) {
	//print("copiando "+filename+"\n");
}

void print_message(string msg) {
	print("Mensaje "+msg+"\n");
}

void print_warning(string msg) {
	print("WARNING "+msg+"\n");
}

void print_error(string msg) {
	print("ERROR "+msg+"\n");
}

int main(string[] args) {

	/*int fork_pid;
	int status;*/
	Gtk.init(ref args);

	var tmp = new cronopete.backup_rsync();
	tmp.send_debug.connect(print_debug);
	tmp.send_message.connect(print_message);
	tmp.send_warning.connect(print_warning);
	tmp.send_error.connect(print_error);
	tmp.send_file_backed_up.connect(print_file);
	tmp.delete_old_backups(false);
	Gtk.main();
	return 0;
	tmp.do_backup();
	Gtk.main();
	return 0;
}

[DBus (name = "com.rastersoft.cronopete2")]
public class DetectServer : GLib.Object {

	public int do_ping(int v) {
		return (v+1);
	}

	public void do_backup() {
		//callback_object.backup_now();
	}

	public void stop_backup() {
		//callback_object.stop_backup();
	}

	public void show_preferences() {
		//callback_object.main_clicked ();
	}

	public void restore_files() {
		//callback_object.enter_clicked ();
	}
}
