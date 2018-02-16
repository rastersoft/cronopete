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

int main(string[] args) {

	/*int fork_pid;
	int status;*/
	Gtk.init(ref args);

	backup_base tmp = new cronopete.backup_rsync();
	tmp.send_debug.connect(print_debug);
	tmp.send_file_backed_up.connect(print_file);
	var lista = tmp.get_backup_list();
	if (lista != null) {
		foreach(var l in lista) {
			var ctime = l.local_time;
			print("%04d_%02d_%02d_%02d:%02d:%02d_%ld\n".printf(1900 + ctime.year, ctime.month + 1, ctime.day, ctime.hour, ctime.minute, ctime.second, l.utc_time));
		}
	}
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
