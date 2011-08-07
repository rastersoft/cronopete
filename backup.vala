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

interface callbacks : GLib.Object {
	
	public abstract void backup_folder(string foldername);
	public abstract void backup_file(string filename);
	public abstract void backup_link_file(string filename);
	public abstract void warning_link_file(string o_filename, string d_filename);
	public abstract void error_copy_file(string o_filename, string d_filename);
	public abstract void error_access_directory(string directory);
	public abstract void error_create_directory(string directory);
	public abstract void excluding_folder(string dirpath);
	public abstract void show_message(string msg);

}

enum BACKUP_RETVAL { OK, CANT_COPY, CANT_LINK, NO_DISK_SPACE, NO_STARTED, CANT_CREATE_FOLDER, ALREADY_STARTED,
	NOT_AVAILABLE, NOT_WRITABLE, NO_SPC, ERROR }

interface backends : GLib.Object {

	public abstract string? get_backup_id();
	public abstract Gee.List<time_t?>? get_backup_list();
	public abstract bool delete_backup(time_t backup_date);
	public abstract BACKUP_RETVAL start_backup(out int64 last_backup_time);
	public abstract BACKUP_RETVAL end_backup();
	public abstract BACKUP_RETVAL create_folder(string path);
	public abstract BACKUP_RETVAL copy_file(string path);
	public abstract BACKUP_RETVAL link_file(string path);
	public abstract BACKUP_RETVAL abort_backup();
}

class path_node:Object {

	// Only the NEXT pointer uses reference count. That way we can
	// slightly improve performance and avoid circular lists
	
	public path_node? next;
	public weak path_node? prev;
	public string path;

	public path_node(string path) {
		this.path=path;
		this.prev=null;
		this.next=null;
	}
	
	~path_node() {
		this.remove();
	}
	
	public void remove() {
		if (this.prev!=null) {
			this.prev.next=this.next;
		}
		if (this.next!=null) {
			this.next.prev=this.prev;
		}
		this.next=null;
		this.prev=null;
	}
	
	public void add(path_node node) {
		this.next=node.next;
		node.next=this;
		this.prev=node;
		if (this.next!=null) {
			this.next.prev=this;
		}
	}
}

class path_list:Object {

	// This is a double-linked list class. I use this instead of
	// GLib.list or Gee's ones to ensure that it allows to add elements
	// to the list while iterating over it

	private path_node? first;
	private weak path_node? last;
	private weak path_node? iterator;
	
	public path_list() {
	
		this.first=null;
		this.last=null;
		this.iterator=null;
	}
	
	~path_list() {
	
		path_node? next;
		
		while(this.last!=null) {

			// Freeing the first node will cause its reference count to be
			// 0, forcing to free its next node, and so on, calling unref()
			// recursively. This can do the stack to grow too much, so we
			// free them starting from the last node.
			 
			next=this.last;
			this.last=this.last.prev;
			next.remove();
		}
		next=null;
		this.first=null;
	}
	
	public void start_iterator() {
	
		// Call this method to start an iteration over the list
		
		this.iterator=null;
	}
	
	public string? next_iterator() {
		
		// This method returns the next element in the list
		
		if (this.iterator==this.last) {
			return null;
		}		

		if (this.iterator==null) {
			this.iterator=this.first;
		} else{
			this.iterator=this.iterator.next;
		}
		
		return this.iterator.path;
	}
	
	public void add(string path) {
	
		// Adds a node at the end of the list
	
		path_node new_node=new path_node(path);
		
		if (this.first==null) {
			this.first=new_node;
			this.last=this.first;
			this.iterator=this.first;
		} else {
			new_node.add(this.last);
		}
		this.last=new_node;
	}
}

class nanockup:Object {

	// This is the backup class itself

	// Base directory where we will do the backup
	private string backup_path;
	
	// Temporal backup directory (starting with 'B')
	private string temporal_path;
	
	// Final backup directory (the same than the temporal, but without
	// the 'B' letter)
	private string final_path;
	
	// Directory with the last backup done (to link files from)
	private string last_path;
	
	// Contains the time (in seconds from EPOCH) of the last backup
	private int64 last_backup_time;
	
	// If TRUE, means that hidden files and folders won't be backed up
	private bool skip_hiden;

	// Contains the paths to backup
	private path_list origin_path_list;
	
	// Contains a list of directory paths which must NOT be backed up
	private HashSet<string> exclude_path_list;
	
	// Contains the paths where not to backup hidden files or folders (if skip_hiden_folders is FALSE)
	private HashSet<string> exclude_path_hiden_list;

	public ulong time_used {get; set;}
	
	private callbacks callback;
	private backends backend;
	
	private bool abort;
	
	public void abort_backup() {
	
		this.abort = true;
		
	}

	public nanockup(callbacks to_callback,backends to_backend) {
	
		this.origin_path_list=new path_list();
		this.exclude_path_list=new HashSet<string>(str_hash,str_equal);
		this.exclude_path_hiden_list=new HashSet<string>(str_hash,str_equal);
		this.callback=to_callback;
		this.backend=to_backend;
		
		// by default, don't backup hidden files or folders
		this.skip_hiden=true;
		this.last_backup_time=0;
		this.backup_path="";
		this.temporal_path="";
		this.final_path="";
		this.last_path="";
		this.abort = false;

	}

	public static int mysort_64(time_t? a, time_t? b) {

		if(a>b) {
			return 1;
		}
		if(a<b) {
			return -1;
		}
		return 0;
	}
	
	public void delete_old_backups() {
	
		var lbacks=this.backend.get_backup_list();
		if (lbacks==null) {
			return;
		}

		lbacks.sort((CompareFunc)mysort_64);
		
		var ctime=time_t();
		
		var day_limit=ctime-86400; // 24 hour period for hourly backups
		var week_limit=ctime-2678400; // 1 month (31 days) period for daily backups
		
		time_t divider=0;
		
		foreach (time_t v in lbacks) {
			if (v>day_limit) { // keep all backups for a day
				continue;
			}
			if (v>week_limit) {
				if ((v/86400)!=divider) { // keep a daily backup for the last month
					divider=v/86400;
				} else {
					this.backend.delete_backup(v);
				}
				continue;
			}
			if ((v/604800)!=divider) { // keep a weekly backup for backups older than a month
				divider=v/604800;
			} else {
				this.backend.delete_backup(v);
			}
		}
	}
	
	public void set_config(string b_path,Gee.List<string> origin_path,Gee.List<string> exclude_path,Gee.List<string> exclude_path_hiden, bool skip_h) {

		this.origin_path_list=new path_list();
		this.exclude_path_list=new HashSet<string>(str_hash,str_equal);
		this.exclude_path_hiden_list=new HashSet<string>(str_hash,str_equal);
	
		this.backup_path = b_path;
		foreach (string tmp in origin_path) {
			this.origin_path_list.add(tmp);
		}
		foreach (string tmp in exclude_path) {
			this.exclude_path_list.add(tmp);
		}
		foreach (string tmp in exclude_path_hiden) {
			this.exclude_path_hiden_list.add(tmp);
		}
		this.skip_hiden=skip_h;
	}
	
	public int do_backup() {
	
		/******************************************************************************************************
		 * Does the backup process itself.                                                                    *
		 * Returns:                                                                                           *
		 *     0: successful                                                                                  *
		 *    -1: partial success;                                                                            *
		 *        this.fail_dir contains directories that couldn't be backed up, and                          *
		 *        this.fail_files contains files that couldn't be backed up                                   *
		 *    -2: the class hasn't been configured yet                                                        *
		 *    -3: the destination directory doesn't exists and can't be created                               *
		 *    -4: can't create the folder for the current backup                                              *
		 *    -5: can't rename the temporal backup folder to its definitive name                              *
		 *    -6: backup aborted                                                                              *
		 ******************************************************************************************************/
	
		int retval,tmp;
		string? directory=null;
		
		this.abort=false;
		
		var rv=this.backend.start_backup(out this.last_backup_time);
		
		if (rv!=BACKUP_RETVAL.OK) {
			return -3;
		}
		
		if (this.backup_path=="") { // system not configured
			this.callback.show_message("User didn't specified a directory where to store the backups. Aborting backup.\n"); 
			return -2; // the class isn't configured (don't know where to store the backups)
		}
		
		var timestamp=time_t();
		
		retval=0;

		// backup all the directories
		this.origin_path_list.start_iterator();
		while (null!=(directory=this.origin_path_list.next_iterator())) {
			if (this.abort) {
				this.callback.show_message(_("Backup aborted\n"));
				this.backend.abort_backup();
				return -6;
			}
			this.callback.backup_folder(directory);
			tmp=this.copy_dir(directory);
			if (0!=tmp) {
				retval=-1;
			}
		}

		if (this.backend.end_backup()==BACKUP_RETVAL.ERROR) {
			this.callback.show_message("Can't rename the temporal backup to its definitive name. Aborting backup.\n");
			return -5;
		}
	
		var timestamp2=time_t();			
		this.time_used=(ulong)timestamp2-timestamp;
		this.callback.show_message("Backup done. Needed %ld seconds.\n".printf((long)this.time_used));
		return retval;
	}
	

	int copy_dir(string first_path) {
	
		/*****************************************************************************************************
		 * This method takes the first directory in the list and copies the files in it to the destination   *
		 * adding the new directories found to the list too, in order to allow to, in a future, add          *
		 * support for using gamin library to track the modified files and backup only the ones that changed *
		 * Returns:                                                                                          *
		 *      0: if successful                                                                             *
		 *     -1: if there were errors during the backup of this folder                                     *
		 *     -2: if it was aborted                                                                         *
		 *****************************************************************************************************/
	
		FileInfo info_file;
		TimeVal result;
		FileEnumerator enumerator;
		string full_path;
		string initial_path;
		string filepath;
		FileType typeinfo;
		int verror,retval;

		initial_path=first_path;
		var directory = File.new_for_path(initial_path);
		
		retval=0;
		
		if ((this.backend.create_folder(first_path))==BACKUP_RETVAL.CANT_CREATE_FOLDER) {
			return -1;
		}
		
		try {
			 enumerator = directory.enumerate_children(FILE_ATTRIBUTE_TIME_MODIFIED+","+FILE_ATTRIBUTE_STANDARD_NAME+","+FILE_ATTRIBUTE_STANDARD_TYPE,FileQueryInfoFlags.NOFOLLOW_SYMLINKS,null);
		} catch (Error e) {
			this.callback.error_access_directory(initial_path);
			return -1;
		}

		while ((info_file = enumerator.next_file(null)) != null) {

			if (this.abort) {
				return -2;
			}

			full_path=Path.build_filename(first_path,info_file.get_name());
			typeinfo=info_file.get_file_type();
			
			// Add the directories to the list, to continue deep in the directory tree
			if (typeinfo==FileType.DIRECTORY) {
				// Don't backup hidden folders if the user doesn't want
				if ((info_file.get_name()[0]=='.') && ((this.skip_hiden) ||
						(this.exclude_path_hiden_list.contains(first_path)))) {
					this.callback.excluding_folder(full_path);
					continue;
				}

				if (this.exclude_path_list.contains(full_path)) {
					this.callback.excluding_folder(full_path);
					continue;
				}

				this.origin_path_list.add(full_path);
				continue;
			}
			
			if (typeinfo==FileType.REGULAR) {
				// Don't backup hidden files if the user doesn't want
				if ((info_file.get_name()[0]=='.') && ((this.skip_hiden)||(this.exclude_path_hiden_list.contains(first_path)))) {
					continue;
				}
				filepath=Path.build_filename(this.last_path,full_path);
				// If the modification time is before the last backup time, just link; if not, copy to the directory
				info_file.get_modification_time(out result);
				if (result.tv_sec < ((long)this.last_backup_time)) {
					this.callback.backup_link_file(filepath);
					if (BACKUP_RETVAL.CANT_LINK==this.backend.link_file(filepath)) {
						verror=-1;
					} else {
						verror=0;
					}
					if (verror!=0) {
						this.callback.warning_link_file(Path.build_filename(this.last_path,full_path),Path.build_filename(this.temporal_path,full_path));
					}
				} else {
					verror=1; // assign a false error to force a copy
				}
				// If the file modification time is bigger than the last backup time, or the link failed, we must copy the file
				if (verror!=0) {
					this.backend.copy_file(filepath);
				}
			}
		}
		return (retval);
	}

}
