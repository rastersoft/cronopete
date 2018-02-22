/*
 Copyright 2018 (C) Raster Software Vigo (Sergio Costas)

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

namespace cronopete {

	public class backup_rsync : backup_base {

		// contains all the folders that must be backed up, and the exclusions for each one
		private Gee.List<folder_container?>? folders;
		// the disk monitor object to manage the disks
		private VolumeMonitor monitor;
		// the current disk path (or null if the drive is not available)
		private string? drive_path;
		// the last backup path if there is one, or null if there are no previous backups
		private string? last_backup;
		// the current backup name
		private string? current_backup;
		// contains the base regexp to identify a backup folder
		private string regex_backup = "[0-9][0-9][0-9][0-9]_[0-9][0-9]_[0-9][0-9]_[0-9][0-9]:[0-9][0-9]:[0-9][0-9]_[0-9]+";
		// contains the type of delete we are doing, to now what do call at the end
		private int deleting_mode;
		// contains the last backup time
		private time_t last_backup_time;
		// contains the current backup time
		private time_t current_backup_time;
		// the PID for the currently running child, to abort a backup
		private Pid current_child_pid;
		// if an abort call has been issued
		private bool aborting;

		public backup_rsync() {
			this.current_child_pid = -1;
			this.aborting = false;
			this.folders = null;
			this.last_backup = null;
			this.current_backup = null;
			this.deleting_mode = -1;
			this.monitor = VolumeMonitor.get();
			this.last_backup_time = 0;
			this.monitor.mount_added.connect_after(this.refresh_connect);
			this.monitor.mount_removed.connect_after(this.refresh_connect);
			this.refresh_connect_in();
		}

		public override time_t get_last_backup() {
			if (this.last_backup_time == 0) {
				time_t v1, v2;
				// get the value
				this.get_backup_list(out v1, out v2);
			}
			return this.last_backup_time;
		}

		public override bool get_backup_data(out string? id, out time_t oldest, out time_t newest, out uint64 total_space, out uint64 free_space, out string? icon) {

			id = cronopete_settings.get_string("backup-uid");
			icon = "drive-harddisk";
			oldest = 0;
			this.last_backup_time = 0;
			newest = 0;
			total_space = 0;
			free_space = 0;
			if (this.drive_path != null) {
				this.get_backup_list(out oldest, out newest);
				try {
					if (this.drive_path != null) {
						var file = File.new_for_path(this.drive_path);
						var info = file.query_filesystem_info(FileAttribute.FILESYSTEM_SIZE + "," + FileAttribute.FILESYSTEM_FREE, null);
						total_space = info.get_attribute_uint64(FileAttribute.FILESYSTEM_SIZE);
						free_space = info.get_attribute_uint64(FileAttribute.FILESYSTEM_FREE);
					}
				} catch (Error e) {
				}
				return true;
			} else {
				return false;
			}
		}

		private bool create_base_folder() {
			var main_folder = File.new_for_path(this.drive_path);
			if (false == main_folder.query_exists()) {
				try {
					main_folder.make_directory_with_parents();
				} catch (Error e) {
					this.send_error(_("Can't create the base folders to do backups. Aborting backup"));
					this.current_status = backup_current_status.IDLE;
					return false; // Error: can't create the base directory
				}
			}
			return true;
		}

		public override Gee.List<backup_element>? get_backup_list(out time_t oldest, out time_t newest) {

			oldest = 0;
			newest = 0;
			if (this.drive_path == null) {
				return null;
			}
			Gee.List<backup_element> folder_list = new Gee.ArrayList<backup_element>();
			if (!this.create_base_folder()) {
				return null;
			}
			var main_folder = File.new_for_path(this.drive_path);
			try {
				GLib.Regex regexBackups = new GLib.Regex(this.regex_backup);
				var folder_content = main_folder.enumerate_children(FileAttribute.STANDARD_NAME, 0, null);

				FileInfo file_info;
				time_t now = time_t();
				// Try to find the last directory, based in the origin's date of creation
				while ((file_info = folder_content.next_file (null)) != null) {

					// If the directory starts with 'B', it's a temporary directory from an
					// unfinished backup, or one being removed, so don't append it

					var dirname = file_info.get_name();
					if (! regexBackups.match(dirname)) {
						continue;
					}
					if (dirname.length < 21) {
						continue;
					}
					var date_value = dirname.substring(20);
					if (date_value == null) {
						continue;
					}
					time_t backup_time = (time_t) uint64.parse(dirname.substring(20));
					// Also never append backups "from the future"
					if ((backup_time <= now) && (backup_time != 0)) {
						if ((oldest == 0) || (backup_time < oldest)) {
							oldest = backup_time;
						}
						if ((newest == 0) || (backup_time > newest)) {
							newest = backup_time;
							this.last_backup_time = newest;
						}
						folder_list.add(new rsync_element(backup_time, this.drive_path, file_info));
					}
				}
			} catch (Error e) {
				return null; // Error: can't read the backups list
			}
			return folder_list;
		}

		public override bool storage_is_available() {
			return (this.drive_path != null);
		}

		public override void abort_backup() {
			if (this.aborting) {
				return;
			}
			this.aborting = true;
			if (this.current_child_pid != -1) {
				Posix.kill(this.current_child_pid,Posix.SIGTERM);
				this.current_child_pid = -1;
			}
		}

		public override bool do_backup() {

			if (this.current_status != backup_current_status.IDLE) {
				return false;
			}

			this.send_message(_("Starting backup"));
			if (!this.create_base_folder()) {
				return false;
			}
			this.folders = new Gee.ArrayList<folder_container?>();
			string[] folder_list = this.cronopete_settings.get_strv("backup-folders");
			string[] exclude_list = this.cronopete_settings.get_strv("exclude-folders");
			foreach(var folder in folder_list) {
				var container = folder_container(folder, exclude_list, this.cronopete_settings.get_boolean("skip-hiden-at-home"));
				if (container.valid) {
					this.folders.add(container);
				}
			}
			time_t oldest;
			time_t newest;
			var backups = this.get_backup_list(out oldest, out newest);
			if (backups == null) {
				return false;
			}
			rsync_element last_backup_element = null;
			foreach(var backup in backups) {
				var backup2 = backup as rsync_element;
				if (last_backup_element == null) {
					last_backup_element = backup2;
				} else {
					if (backup2.utc_time > last_backup_element.utc_time) {
						last_backup_element = backup2;
					}
				}
			}
			if (last_backup_element == null) {
				this.last_backup = null;
			} else {
				this.last_backup = last_backup_element.full_path;
			}
			this.current_backup_time = time_t();
			this.current_backup = this.date_to_folder_name(this.current_backup_time);
			this.current_status = backup_current_status.RUNNING;
			this.deleting_mode = 0;
			this.aborting = false;
			// delete aborted backups first
			this.delete_backup_folders("B");
			return true;
		}

		private string date_to_folder_name(time_t t) {
			var ctime = GLib.Time.local(t);
			return "%04d_%02d_%02d_%02d:%02d:%02d_%ld".printf(1900 + ctime.year, ctime.month + 1, ctime.day, ctime.hour, ctime.minute, ctime.second, t);
		}

		/**
		 * Manages the next command to run after deleting an old backup
		 */
		private void ended_deleting_old_backups() {
			if (this.aborting) {
				this.end_abort();
				return;
			}
			switch(this.deleting_mode) {
				case 0: // we are deleting aborted backups
				case 1: // we are freeing disk space because we ran out of it
					this.deleting_mode = -1;
					this.do_backup_folder();
					break;
				case 2: // we are deleting old backups
					this.send_message(_("Backup done"));
					this.deleting_mode = -1;
					this.current_status = backup_current_status.IDLE;
					break;
			}
		}

		/**
		 * Sets everything as needed after an abort
		 */
		private void end_abort() {
			this.current_child_pid = -1;
			this.aborting = false;
			this.deleting_mode = -1;
			this.current_status = backup_current_status.IDLE;
			this.send_message(_("Backup aborted"));
		}

		/**
		 * This method deletes any backup with a name that starts with 'B' or 'C'
		 * because that's an aborted backup
		 */
		private void delete_backup_folders(string prefix) {

			var main_folder = File.new_for_path(this.drive_path);
			// find the next folder to delete
			string? to_delete = null;
			try {
				var folder_regexp = new GLib.Regex(prefix + this.regex_backup);
				var folder_content = main_folder.enumerate_children(FileAttribute.STANDARD_NAME, 0, null);

				FileInfo file_info;
				while ((file_info = folder_content.next_file (null)) != null) {

					// If the directory starts with 'B', it's a temporary directory from an
					// unfinished backup, or one being removed, so don't append it

					var dirname = file_info.get_name();
					if (!folder_regexp.match(dirname)) {
						continue;
					}
					to_delete = dirname;
					break;
				}
			} catch(Error e) {
				to_delete = null;
			}

			if (to_delete == null) {
				this.ended_deleting_old_backups();
				return;
			}

			Pid child_pid;
			string[] command = {"bash", "-c", "rm -rf " + Path.build_filename(this.drive_path, to_delete)};
			string[] env = Environ.get();
			this.debug_command(command);
			try {
				GLib.Process.spawn_async("/",command,env,SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,null,out child_pid);
			} catch (GLib.SpawnError error) {
				this.send_error(_("Failed to delete aborted backups: " + error.message));
				this.ended_deleting_old_backups();
				return;
			}
			this.current_child_pid = child_pid;
			ChildWatch.add (child_pid, (pid, status) => {
				Process.close_pid (pid);
				this.current_child_pid = -1;
				this.delete_backup_folders(prefix);
			});
		}

		/**
		 * This method backs up one folder
		 */
		private void do_backup_folder() {

			Pid child_pid;
			int standard_output;

			if (this.folders.size == 0) {
				this.do_first_sync();
				return;
			}
			var folder = this.folders.get(0);
			this.send_message(_("Backing up folder %s").printf(folder.folder));
			/* The backup is done to a temporary folder called like the final one, but preppended with a 'B' letter
			 * This way, if there is an big error (like if the computer hangs, or the electric suply fails), it will
			 * be easily identified as an incomplete backup and won't be used
			 */

			string out_folder = Path.build_filename(this.drive_path, "B" + this.current_backup, folder.folder);
			var out_folder_f = File.new_for_path(out_folder);
			try {
				out_folder_f.make_directory_with_parents();
			} catch(Error e) {
			}
			string[] command = {"rsync", "-aXv"};
			if (this.last_backup != null) {
				command += "--link-dest";
				command += Path.build_filename(this.last_backup, folder.folder);
			}
			foreach(var exclude in folder.exclude) {
				command += "--exclude";
				command += exclude;
				this.send_message(_("Excluding folder %s").printf(Path.build_filename(folder.folder, exclude)));
			}
			command += folder.folder;
			command += out_folder;
			string[] env = Environ.get();
			this.debug_command(command);
			try {
				GLib.Process.spawn_async_with_pipes("/",command,env,SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,null,out child_pid, null, out standard_output, null);
			} catch (GLib.SpawnError error) {
				this.send_error(_("Failed to launch rsync for '%s'. Aborting backup").printf(folder.folder));
				this.current_status = backup_current_status.IDLE;
				return;
			}
			this.current_child_pid = child_pid;
			ChildWatch.add (child_pid, (pid, status) => {
				Process.close_pid (pid);
				this.current_child_pid = -1;
				if (this.aborting) {
					this.end_abort();
					return;
				}
				if (status != 0) {
					if (status == 11) {
						// if there is no free disk space, delete the oldest backup and try again
						this.deleting_mode = 1;
						this.delete_old_backups(true);
						return;
					}
					this.send_warning(_("There was a problem when backing up the folder '%s'").printf(folder.folder));
				}
				this.folders.remove_at(0); // next folder
				this.do_backup_folder();
			});
			IOChannel output = new IOChannel.unix_new (standard_output);
			output.add_watch (IOCondition.IN | IOCondition.HUP, (channel, condition) => {
				if (condition == IOCondition.HUP) {
					return false;
				}
				try {
					string line;
					channel.read_line (out line, null, null);
					var line2 = line.strip();
					this.send_file_backed_up(Path.build_filename(folder.folder, line2));
				} catch (IOChannelError e) {
					return false;
				} catch (ConvertError e) {
					return false;
				}
				return true;
			});
		}

		/**
		 * When the backup is done, do a sync to ensure that the data is physically stored in the disk
		 */
		private void do_first_sync() {
			Pid child_pid;
			string[] command = {"sync"};
			string[] env = Environ.get();
			this.send_message(_("Syncing disk"));
			this.debug_command(command);
			this.current_status = backup_current_status.SYNCING;
			try {
				GLib.Process.spawn_async("/",command,env,SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,null,out child_pid);
			} catch (GLib.SpawnError error) {
				this.send_warning(_("Failed to launch sync command"));
				this.do_second_sync();
				return;
			}
			ChildWatch.add (child_pid, (pid, status) => {
				Process.close_pid (pid);
				if (this.aborting) {
					this.end_abort();
					return;
				}
				this.do_second_sync();
			});
		}

		/**
		 * After the data has been physically stored, rename the directory
		 * And when the directory has been renamed to its final name, sync again and finish the backup
		 */
		private void do_second_sync() {
			var current_folder = File.new_for_path(Path.build_filename(this.drive_path, "B" + this.current_backup));
			try {
				current_folder.set_display_name(this.current_backup);
			} catch (GLib.Error e) {
				this.send_warning(_("Failed to rename backup folder. Aborting backup"));
				this.current_status = backup_current_status.CLEANING;
				this.deleting_mode = 2;
				this.delete_old_backups(false);
				return;
			}
			Pid child_pid;
			string[] command = {"sync"};
			string[] env = Environ.get();
			this.debug_command(command);
			try {
				GLib.Process.spawn_async("/",command,env,SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,null,out child_pid);
			} catch (GLib.SpawnError error) {
				this.send_warning(_("Failed to launch final sync command"));
				this.current_status = backup_current_status.IDLE;
				return;
			}
			ChildWatch.add (child_pid, (pid, status) => {
				Process.close_pid (pid);
				if (this.aborting) {
					this.end_abort();
					return;
				}
				this.send_message(_("Disk synced, cleaning old backups"));
				this.current_status = backup_current_status.CLEANING;
				this.deleting_mode = 2;
				this.delete_old_backups(false);
			});
		}

		/**
		 * Deletes old backups, ensuring that all the backups in the last 24 hours are kept,
		 * also one daily backup for the last mont, and one backup each week for the rest of
		 * the time.
		 *
		 * @param free_space If true, if no backup is deleted, the last backup will be deleted
		 * to make space for the current backup
		 */
		public void delete_old_backups(bool free_space) {

			var backups = this.eval_backups_to_delete(free_space);

			if (backups == null) {
				this.ended_deleting_old_backups();
				return;
			}

			bool found_backup_to_delete = false;
			foreach(var backup_tmp in backups) {
				if (backup_tmp.keep) {
					continue;
				}
				found_backup_to_delete = true;
				var backup = backup_tmp as rsync_element;
				this.send_message(_("Deleting old backup %s").printf(backup.path));
				File remove_folder = File.new_for_path(backup.full_path);
				// First rename every backup that must be deleted, by preppending a 'C' letter
				// This allows to mark them fast as "not usable" to avoid the recovery utility to list them
				try {
					remove_folder.set_display_name("C" + backup.path);
				} catch (GLib.Error e) {
					this.send_warning(_("Failed to delete old backup %s: %s").printf(backup.path, e.message));
				}
			}
			// and now we delete those folders
			if (found_backup_to_delete) {
				this.delete_backup_folders("C");
			} else {
				this.ended_deleting_old_backups();
			}
		}


		private void debug_command(string[] command_list) {
			string debug_msg = "Launching command: ";
			foreach(var c in command_list) {
				debug_msg += c + " ";
			}
			this.send_debug(debug_msg);
		}

		private void refresh_connect(Mount mount) {
			this.refresh_connect_in();
		}

		private void refresh_connect_in() {

			var volumes = this.monitor.get_volumes();
			var drive_uuid = cronopete_settings.get_string("backup-uid");

			foreach (Volume v in volumes) {
				if ((drive_uuid != "") && (drive_uuid == v.get_identifier("uuid"))) {
					var mnt = v.get_mount();
					if (!(mnt is Mount)) {
						this.last_backup_time = 0;
						// the drive is not mounted!!!!!!
						if (this.drive_path != null) {
							this.is_available_changed(false);
							this.drive_path = null;
						}
						if (cronopete_settings.get_boolean("enabled")) {
							v.mount.begin(GLib.MountMountFlags.NONE, null); // if backups are enabled, mount it
						}
					} else {
						if (this.drive_path == null) {
							this.last_backup_time = 0;
							this.is_available_changed(true);
							this.drive_path = Path.build_filename(mnt.get_root().get_path(), "cronopete", Environment.get_user_name());
						}
					}
					return;
				}
			}
			// the backup disk isn't connected
			this.last_backup_time = 0;
			if (this.drive_path != null) {
				this.drive_path = null;
				this.is_available_changed(false);
			}
		}
	}

	private struct folder_container {
		public string folder;
		public string[] exclude;
		public bool valid;

		public folder_container(string folder, string[] exclude_list, bool skip_hidden_at_home) {
			this.valid = true;
			if (!folder.has_suffix("/")) {
				this.folder = folder + "/";
			} else {
				this.folder = folder;
			}
			this.exclude = {};
			foreach(var x in exclude_list) {
				if (!x.has_suffix("/")) {
					x = x + "/";
				}
				if (x == this.folder) {
					valid = false;
					break;
				}
				if (x.has_prefix(this.folder)) {
					// "-1" to include the path separator before
					this.exclude += x.substring(this.folder.length - 1);
				}
			}
			// If this folder is the home folder, check if the hidden files/folders must be copied or not
			var home_folder = Path.build_filename("/home", Environment.get_user_name()) + "/";
			if ((this.folder == home_folder) && (skip_hidden_at_home)) {
				this.exclude += "/.*";
			}
		}
	}

	public class rsync_element : backup_element {

		private FileInfo file_info;
		public string path;
		public string full_path;

		public rsync_element(time_t t, string path, FileInfo f) {
			this.set_common_data(t);
			this.file_info = f;
			this.path = f.get_name();
			this.full_path = Path.build_filename(path, this.path);
		}
	}
}
