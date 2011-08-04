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
using Posix;
using Gee;

class usbhd_backend: Object, nsnanockup.backends {

	public string backup_path;
	
	public usbhd_backend(string bpath) {
	
		this.backup_path=Path.build_filename(bpath,"nanockup",Environment.get_user_name());
	}

	public Gee.List<time_t?>? get_backup_list() {
	
		var blist = new Gee.ArrayList<time_t?>();
		string dirname;
					
		var directory = File.new_for_path(this.backup_path);

		try {
			var myenum = directory.enumerate_children(FILE_ATTRIBUTE_STANDARD_NAME, 0, null);
			
			FileInfo file_info;
		
			// Try to find the last directory, based in the origin's date of creation
		
			while ((file_info = myenum.next_file (null)) != null) {
				
				// If the directory starts with 'B', it's a temporary directory from an
		 		// unfinished backup, so remove it
				
				dirname=file_info.get_name();
				if (dirname[0]=='B') {
					Process.spawn_command_line_sync("rm -rf "+Path.build_filename(this.backup_path,dirname));
				} else {
					blist.add(dirname.substring(20).to_long());
				}
			}
		} catch (Error e) {
	
			// The main directory doesn't exist, so we create it
			try {
				directory.make_directory_with_parents(null);
			} catch (Error e) {
				return null; // Error: can't create the base directory
			}
		}
		return blist;

	}
	
	public bool delete_backup(time_t backup_date) {
	
		var ctime = GLib.Time.local((time_t)backup_date);
		var tmppath="%04d_%02d_%02d_%02d:%02d:%02d_%lld".printf(1900+ctime.year,ctime.month+1,ctime.day,ctime.hour,ctime.minute,ctime.second,backup_date);
		var final_path=Path.build_filename(this.backup_path,tmppath);
		
		Process.spawn_command_line_sync("rm -rf "+final_path);
		return true;
	}

/*	public BACKUP_RETVAL start_backup();
	public BACKUP_RETVAL end_backup();
	public BACKUP_RETVAL abort_backup();
	public BACKUP_RETVAL copy_file(string path);
	public BACKUP_RETVAL link_file(string path);*/



}
