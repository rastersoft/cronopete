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

class usbhd_backend: Object, backends {

	private string backup_path;
	private string id;
	private string? cbackup_path;
	private string? cfinal_path;
	private string? last_backup;
	private callbacks callback;
	
	public usbhd_backend(string bpath, callbacks cb) {
	
		this.callback=cb;
		this.id=bpath.dup();
		this.backup_path=Path.build_filename(bpath,"cronopete",Environment.get_user_name());
		this.cbackup_path=null;
		this.cfinal_path=null;
	}

	public string? get_backup_id() {
	
		return (this.id);
	
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
				if (dirname[0]!='B') {
					blist.add(long.parse(dirname.substring(20)));
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


	public BACKUP_RETVAL end_backup() {
	
		if (this.cfinal_path==null) {
			return BACKUP_RETVAL.NO_STARTED;
		}
	
		this.callback.show_message("Syncing disk\n");

		// sync the disk to ensure that all the data has been commited
		Posix.sync();
		
		// rename the directory from Bxxxxx to xxxxx to confirm the backup
		var directory2 = File.new_for_path(this.cbackup_path);
		try {
			directory2.set_display_name(this.cfinal_path,null);
		} catch (Error e) {
			this.callback.show_message("Can't rename the temporal backup %s to its definitive name %s (%s). Aborting backup.\n".printf(this.cbackup_path,this.cfinal_path,e.message));
			this.cfinal_path=null;
			return BACKUP_RETVAL.ERROR;
		}
	
		// and sync again the disk to confirm the new name
		Posix.sync();
		this.cfinal_path=null;
		return BACKUP_RETVAL.OK;
	}

	public BACKUP_RETVAL start_backup(out int64 last_backup_time) {
	
		if (this.cfinal_path!=null) {
			this.callback.show_message("Already started a backup\n");
			return BACKUP_RETVAL.ALREADY_STARTED;
		}
	
		string dirname;
		var directory = File.new_for_path(this.backup_path);
		
		var timestamp=time_t();
		var ctime = GLib.Time.local(timestamp);

		var tmppath="%04d_%02d_%02d_%02d:%02d:%02d_%ld".printf(1900+ctime.year,ctime.month+1,ctime.day,ctime.hour,ctime.minute,ctime.second,timestamp);
		this.cbackup_path=Path.build_filename(this.backup_path,"B"+tmppath);
		this.cfinal_path=tmppath;
		
		string tmp_directory="";
		string tmp_date="";
		string last_date="";

		try {
			var myenum = directory.enumerate_children(FILE_ATTRIBUTE_STANDARD_NAME, 0, null);
			FileInfo file_info;
		
			while ((file_info = myenum.next_file (null)) != null) {
				
				// If the directory starts with 'B', it's a temporary directory from an
		 		// unfinished backup, so remove it
				
				dirname=file_info.get_name();
				if (dirname[0]=='B') {
					Process.spawn_command_line_sync("rm -rf "+Path.build_filename(this.backup_path,dirname));
				} else {
					tmp_date=dirname.substring(20);
					if (tmp_directory=="") {
				
						/* If this is the first path we read, just store it as-is. */
				
						tmp_directory=dirname;
						last_date=tmp_date;
						last_backup_time = int64.parse(tmp_date);
					} else {
				
						/* If not, compare it with the current one, and, if is newer, replace it.
				 		* We use the time from the epoch to avoid problems when a backup is done
				 		* just during the winter or summer time change */

						if (last_date.collate(tmp_date)<0) {
							tmp_directory=dirname;
							last_date=tmp_date;
							last_backup_time = int64.parse(tmp_date);
						}
					}
				}
			}
		} catch (Error e) {
			// The main directory doesn't exist, so we create it
			try {
				this.last_backup=null;
				last_backup_time=0;
				directory.make_directory_with_parents(null);
			} catch (Error e) {
				return BACKUP_RETVAL.NOT_AVAILABLE; // Error: can't create the base directory
			}
		}

		this.last_backup=Path.build_filename(this.backup_path,tmp_directory);
		
		var directory2 = File.new_for_path(this.cbackup_path);
		try {
			directory2.make_directory_with_parents(null);
		} catch (Error e) {
			this.callback.show_message("Can't create the folder for this backup. Aborting backup.\n");
			return BACKUP_RETVAL.NOT_WRITABLE; // can't create the folder for the current backup
		}
		
		return BACKUP_RETVAL.OK;
	}

	public BACKUP_RETVAL copy_file(string path) {
	
		try {
			this.callback.backup_file(path);
			File.new_for_path(Path.build_filename(path)).copy(File.new_for_path(Path.build_filename(this.cbackup_path,path)),FileCopyFlags.OVERWRITE,null,null);
		} catch (Error e) {
			this.callback.error_copy_file(path,Path.build_filename(this.cbackup_path,path));
			return BACKUP_RETVAL.CANT_COPY;
		}
		return BACKUP_RETVAL.OK;	
	}
	
	public BACKUP_RETVAL link_file(string path) {
		
		//GLib.stdout.printf("Linkando %s a %s\n",Path.build_filename(this.last_backup,path),Path.build_filename(this.cbackup_path,path));
		
		if ((link(Path.build_filename(this.last_backup,path),Path.build_filename(this.cbackup_path,path)))!=0) {
			return BACKUP_RETVAL.CANT_LINK;
		}
		return BACKUP_RETVAL.OK;
	}

	public BACKUP_RETVAL create_folder(string path) {
	
		try {
			var dir2 = File.new_for_path(Path.build_filename(this.cbackup_path,path));
			dir2.make_directory_with_parents(null);
		} catch (Error e) {
			this.callback.error_create_directory(path);
			return BACKUP_RETVAL.CANT_CREATE_FOLDER;
		}
	
		return BACKUP_RETVAL.OK;
	
	}

	public BACKUP_RETVAL abort_backup() {
		if (this.cfinal_path==null) {
			return BACKUP_RETVAL.NO_STARTED;
		}
	
		this.cfinal_path=null;
		return BACKUP_RETVAL.OK;
	}

}