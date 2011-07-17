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

namespace nsnanockup {

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
		
		private bool made_copy;

		public nanockup(callbacks to_callback) {
		
			this.origin_path_list=new path_list();
			this.exclude_path_list=new HashSet<string>(str_hash,str_equal);
			this.exclude_path_hiden_list=new HashSet<string>(str_hash,str_equal);
			this.callback=to_callback;
			
			// by default, don't backup hidden files or folders
			this.skip_hiden=true;
			this.last_backup_time=0;
			this.backup_path="";
			this.temporal_path="";
			this.final_path="";
			this.last_path="";

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
			 ******************************************************************************************************/
		
			int retval,tmp;
			string? directory=null;
			
			this.made_copy=false;
			
			if (this.backup_path=="") { // system not configured
				this.callback.show_message("User didn't specified a directory where to store the backups. Aborting backup.\n"); 
				return -2; // the class isn't configured (don't know where to store the backups)
			}

			if (0!=this.GetBaseDir(this.backup_path)) {
				this.callback.show_message("The backup directory %s doesn't exists and can't be created. Aborting backup.\n".printf(this.backup_path));
				return -3; // the base backup folder doesn't exists and can't create it
			}
			
			if (0!=this.SetNewDir()) {
				this.callback.show_message("Can't create the folder for this backup. Aborting backup.\n");
				return -4; // can't create the folder for the current backup
			}
			
			var timestamp=time_t();
			
			retval=0;

			// backup all the directories
			this.origin_path_list.start_iterator();
			while (null!=(directory=this.origin_path_list.next_iterator())) {
				this.callback.backup_folder(directory);
				tmp=this.copy_dir(directory);
				if (0!=tmp) {
					retval=-1;
				}
			}

			this.callback.show_message("Syncing disk\n");

			// sync the disk to ensure that all the data has been commited
			Posix.sync();
			
			if (this.made_copy) {
			
				// rename the directory from Bxxxxx to xxxxx to confirm the backup
				var directory2 = File.new_for_path(this.temporal_path);
				try {
					directory2.set_display_name(this.final_path,null);
				} catch {
					this.callback.show_message("Can't rename the temporal backup to its definitive name. Aborting backup.\n");
					return -5;
				}
			
				// and sync again the disk to confirm the new name
				Posix.sync();
			} else {
				this.callback.show_message("No modified files since last backup.\n");
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
			 *****************************************************************************************************/
		
			FileInfo info_file;
			TimeVal result;
			FileEnumerator enumerator;
			string full_path;
			string initial_path;
			FileType typeinfo;
			int verror,retval;

			initial_path=first_path;
			var directory = File.new_for_path(initial_path);
			
			retval=0;
			
			try {
				var dir2 = File.new_for_path(Path.build_filename(this.temporal_path,first_path));
				dir2.make_directory_with_parents(null);
			} catch (Error e) {
				this.callback.error_create_directory(Path.build_filename(this.temporal_path,first_path));
				return -1;
			}
			
			try {
				 enumerator = directory.enumerate_children(FILE_ATTRIBUTE_TIME_MODIFIED+","+FILE_ATTRIBUTE_STANDARD_NAME+","+FILE_ATTRIBUTE_STANDARD_TYPE,FileQueryInfoFlags.NOFOLLOW_SYMLINKS,null);
			} catch (Error e) {
				this.callback.error_access_directory(initial_path);
				return -1;
			}

			while ((info_file = enumerator.next_file(null)) != null) {

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
					// If the modification time is before the last backup time, just link; if not, copy to the directory
					info_file.get_modification_time(out result);
					if (result.tv_sec < ((long)this.last_backup_time)) {
						this.callback.backup_link_file(Path.build_filename(this.last_path,full_path));
						//GLib.stdout.printf("Linking %s to %s\n",Path.build_filename(this.last_path,full_path),Path.build_filename(this.temporal_path,full_path));
						verror=link(Path.build_filename(this.last_path,full_path),Path.build_filename(this.temporal_path,full_path));
						if (verror!=0) {
							this.callback.warning_link_file(Path.build_filename(this.last_path,full_path),Path.build_filename(this.temporal_path,full_path));
						}
					} else {
						verror=1; // assign a false error to force a copy
					}
					// If the file modification time is bigger than the last backup time, or the link failed, we must copy the file
					if (verror!=0) {
						try {
							this.made_copy=true;
							this.callback.backup_file(full_path);
							//GLib.stdout.printf("Copying %s to %s\n",full_path,Path.build_filename(this.temporal_path,full_path));
							File.new_for_path(Path.build_filename(full_path)).copy(File.new_for_path(Path.build_filename(this.temporal_path,full_path)),FileCopyFlags.OVERWRITE,null,null);
						} catch (Error e) {
							this.callback.error_copy_file(full_path,Path.build_filename(this.temporal_path,full_path));
							retval=-2; // failed to copy a file.
						}
					}
				}
			}
			return (retval);
		}


		public int read_configuration(string? config_path) {
		
			/****************************************************************************************
			 * If CONFIG_PATH is null, will read the configuration from the file ~/.nanockup.cfg    *
			 * If not, it will use that file to get the configuration                               *
			 * Returns:                                                                             *
			 *   0: on success                                                                      *
			 *  -1: the config file doesn't exists                                                  *
			 *  -2: can't read the config file                                                      *
			 *  +N: parse error at line N in config file                                            *			 
			 ****************************************************************************************/
		
			File config_file;
			bool failed=false;
			FileInputStream file_read;
			
			if (config_path==null) {
				string home=Environment.get_home_dir();
				config_file = File.new_for_path (Path.build_filename(home,".nanockup.cfg"));
			} else {
				config_file = File.new_for_path (config_path);
			}
			
			if (!config_file.query_exists (null)) {
				return -1;
			}

			try {
				file_read=config_file.read(null);
			} catch {
				return -2;
			}
			var in_stream = new DataInputStream (file_read);
			string line;
			int line_counter=0;

			this.skip_hiden=true;
			while ((line = in_stream.read_line (null, null)) != null) {
				line_counter++;
				
				// ignore comments
				if (line[0]=='#') {
					continue;
				}
				
				// remove unwanted blank spaces
				line.strip();

				// ignore empty lines				
				if (line.length==0) {
					continue;
				}
				
				if (line.has_prefix("add_directory ")) {
					this.origin_path_list.add(line.substring(14).strip());
					continue;
				}
				
				if (line.has_prefix("exclude_directory ")) {
					this.exclude_path_list.add(line.substring(18).strip());
					continue;
				}
				
				if (line.has_prefix("exclude_directory_hiden ")) {
					this.exclude_path_hiden_list.add(line.substring(24).strip());
					continue;
				}
				
				if (line.has_prefix("backup_directory ")) {
					this.backup_path=line.substring(17).strip();
					continue;
				}
				
				if (line=="backup_hiden") {
					this.skip_hiden=false;
					continue;
				}
				failed=true;
				break;
			}

			try {
				in_stream.close(null);
			} catch {
			}
			try {
				file_read.close(null);
			} catch {
			}

			if (failed) {
				GLib.stderr.printf("Invalid parameter in config file %s (line %d)\n",config_file.get_path(),line_counter);
				return line_counter;
			}
			
			return 0;
		}


		int SetNewDir() {

			/*********************************************************************
			 * Creates the directory where nanockup will do the current backup    *
			 * Returns:                                                          *
			 *    0: if successful                                               *
			 *   -1: if fails                                                    *
			 *********************************************************************/
			
			var directory = File.new_for_path(this.temporal_path);
			try {
				directory.make_directory_with_parents(null);
			} catch (Error e) {
				return -1; // Error, can't create the final directory
			}
			return 0;
		}


		int GetBaseDir(string mediapath) {

			/*******************************************************************************************************************
			 * Fills LAST_PATH with the directory containing the last backup (empty if this is the first backup),              *
			 * and creates the directory /DRIVE/FOR/BACKUPS/nanockup/USERNAME if it doesn't exists, to store all the backups    *
			 * Returns:                                                                                                        *
			 *    0: if successful                                                                                             *
			 *   -1: if directory DRIVE/FOR/BACKUPS/nanockup/USERNAME doesn't exists and can't create it                        *
			 *******************************************************************************************************************/

			string last_date="";
			string tmp_date="";
			string tmp_directory="";
			string dirname;
			string basepath=mediapath;
			
			long timestamp;
			string tmppath;
			
			// First, get the timestamp and fill some class properties

			timestamp=time_t();
			var ctime = GLib.Time.local(timestamp);

			tmppath="%04d_%02d_%02d_%02d:%02d:%02d_%ld".printf(1900+ctime.year,ctime.month+1,ctime.day,ctime.hour,ctime.minute,ctime.second,timestamp);
			this.backup_path=Path.build_filename(basepath,"nanockup",Environment.get_user_name());
			this.temporal_path=Path.build_filename(this.backup_path,"B"+tmppath);
			this.final_path=tmppath;
			
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
						tmp_date=dirname.substring(20);
						if (tmp_directory=="") {
					
							/* If this is the first path we read, just store it as-is. */
					
							tmp_directory=dirname;
							last_date=tmp_date;
						} else {
					
							/* If not, compare it with the current one, and, if is newer, replace it.
					 		* We use the time from the epoch to avoid problems when a backup is done
					 		* just during the winter or summer time change */

							if (last_date.collate(tmp_date)<0) {
								tmp_directory=dirname;
								last_date=tmp_date;
							}
						}
					}
				}
			} catch (Error e) {
		
				// The main directory doesn't exist, so we create it
				try {
					this.last_path="";
					directory.make_directory_with_parents(null);
				} catch (Error e) {
					return -1; // Error: can't create the base directory
				}
			}
			this.last_path=Path.build_filename(basepath,"nanockup",Environment.get_user_name(),tmp_directory);
			this.last_backup_time=int64.parse(last_date);
			return 0;
		}
		
		public int command_line(string[] args) {
		
			/*******************************************************************
			 * Processes the command line arguments to allow to use nanockup   *
			 * from command line or with alternative configuration files       *
			 * Returns:                                                        *
			 *  0 all OK                                                       *
			 *  1 user asked for version                                       *
			 *  2 user asked for help                                          *
			 * -1 if specified both a configuration file and more command line *
			 *    parameters                                                   *
			 * -2 not specified a file with the -a parameter                   *
			 * -3 not specifies a file with the -e parameter                   *
			 * -4 not specifies a file with the --exclude_hiden parameter      *
			 * -5 not specifies a file with the -c parameter                   *
			 * -6 incorrect configuration file with the -c parameter           *
			 * -7 unknown parameter                                            *
			 *******************************************************************/
		
			int counter;
			int size;
			bool config_file=false;
			bool cmd=false;
			
			counter=1;
			size=args.length;
			
			while (counter<size) {
				if ((args[counter]=="-a") || (args[counter]=="--add")) {
					if (config_file) {
						GLib.stderr.printf("Can't specify a configuration file and command line parameters. Aborting.\n");
						return -1; // can't specify a config file and command line parameters
					}
					cmd=true;
					if ((counter+1)==size) {
						GLib.stderr.printf("The parameter -a must be followed of a path. Aborting.\n");
						return -2; // there's no parameter for this command
					}
					this.origin_path_list.add(args[counter+1]);
					counter+=2;
					continue;
				}
				
				if ((args[counter]=="-e") || (args[counter]=="--exclude")) {
					if (config_file) {
						GLib.stderr.printf("Can't specify a configuration file and command line parameters. Aborting.\n");
						return -1; // can't specify a config file and command line parameters
					}
					cmd=true;
					if ((counter+1)==size) {
						GLib.stderr.printf("The parameter -e must be followed of a path. Aborting.\n");
						return -3; // there's no parameter for this command
					}
					this.exclude_path_list.add(args[counter+1]);
					counter+=2;
					continue;
				}
				
				if (args[counter]=="--exclude_hiden") {
					if (config_file) {
						GLib.stderr.printf("Can't specify a configuration file and command line parameters. Aborting.\n");
						return -1; // can't specify a config file and command line parameters
					}
					cmd=true;
					if ((counter+1)==size) {
						GLib.stderr.printf("The parameter --exclude_hiden must be followed of a path. Aborting.\n");
						return -4; // there's no parameter for this command
					}
					this.exclude_path_hiden_list.add(args[counter+1]);
					counter+=2;
					continue;
				}
				
				if ((args[counter]=="--hiden")) {
					if (config_file) {
						GLib.stderr.printf("Can't specify a configuration file and command line parameters. Aborting.\n");
						return -1; // can't specify a config file and command line parameters
					}
					cmd=true;
					this.skip_hiden=false;
					counter+=1;
					continue;
				}
				if ((args[counter]=="-h") || (args[counter]=="--help")) {
					return 2; // asked for help
				}
				
				if ((args[counter]=="-v") || (args[counter]=="--version")) {
					return 1;
				}
				
				if ((args[counter]=="-c") || (args[counter]=="--config")) {
					if (cmd) {
						GLib.stderr.printf("Can't specify a configuration file and command line parameters. Aborting.\n");
						return -1; // can't specify a config file and command line parameters
					}
					config_file=true;
					if ((counter+1)==size) {
						GLib.stderr.printf("The parameter -c must be followed of a file path and name. Aborting.\n");
						return -5; // there's no parameter for this command
					}
					if (0!=this.read_configuration(args[counter+1])) {
						return -6;
					}
					counter+=2;
					continue;
				}
				GLib.stderr.printf("Unknown parameter %s.\n",args[counter]);
				return -7;
			}
			return 0;
		}
	}
}
