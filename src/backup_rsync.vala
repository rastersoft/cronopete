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
		private folder_container[] folders;
		// the disk monitor object to manage the disks
		private VolumeMonitor monitor;
		// the current disk path (or null if the drive is not available)
		private string? drive_path;

		public backup_rsync() {
			this.monitor = VolumeMonitor.get();
			this.monitor.mount_added.connect_after(this.refresh_connect);
			this.monitor.mount_removed.connect_after(this.refresh_connect);
			this.refresh_connect_in();
		}

		public override backup_element[]? get_backup_list() {

			if (this.drive_path == null) {
				return null;
			}

			backup_element[] folder_list = {};
			var main_folder = File.new_for_path(this.drive_path);
			if (false == main_folder.query_exists()) {
				try {
					main_folder.make_directory_with_parents();
				} catch (Error e) {
					return null; // Error: can't create the base directory
				}
			}

			try {
				var folder_content = main_folder.enumerate_children(FileAttribute.STANDARD_NAME, 0, null);

				FileInfo file_info;
				time_t now = time_t();
				// Try to find the last directory, based in the origin's date of creation
				while ((file_info = folder_content.next_file (null)) != null) {

					// If the directory starts with 'B', it's a temporary directory from an
					// unfinished backup, or one being removed, so don't append it

					var dirname = file_info.get_name();
					if (dirname[0] != 'B') {
						var backup_time = long.parse(dirname.substring(20));
						// Also never append backups "from the future"
						if ((backup_time <= now) && (backup_time != 0)) {
							folder_list += new backup_element(backup_time);
						}
					}
				}
			} catch (Error e) {
				print("Error in main folder backup: %s".printf(main_folder.get_uri()));
				return null; // Error: can't read the backups list
			}
			return folder_list;
		}

		public override bool storage_is_available() {
			return (this.drive_path != null);
		}

		public override void do_backup() {
			string[] folder_list = this.cronopete_settings.get_strv("backup-folders");
			string[] exclude_list = this.cronopete_settings.get_strv("exclude-folders");
			foreach(var folder in folder_list) {
				var container = folder_container(folder, exclude_list);
				if (container.valid) {
					folders += container;
				}
			}
			foreach(var folder in this.folders) {
				
			}
		}

		private void refresh_connect(Mount mount) {
			this.refresh_connect_in();
		}

		private void refresh_connect_in() {

			var volumes = this.monitor.get_volumes();
			var drive_uuid = cronopete_settings.get_string("backup-uid");
			this.drive_path = null;

			foreach (Volume v in volumes) {
				if ((drive_uuid != "") && (drive_uuid == v.get_identifier("uuid"))) {
					var mnt = v.get_mount();
					if (!(mnt is Mount)) {
						// the drive is not mounted!!!!!!
						if (cronopete_settings.get_boolean("enabled")) {
							this.is_available(false);
							v.mount.begin(GLib.MountMountFlags.NONE, null); // if backups are enabled, mount it
						}
					} else {
						this.is_available(true);
						this.drive_path = Path.build_filename(mnt.get_root().get_path(), "cronopete", Environment.get_user_name());
					}
					break;
				}
			}
		}
	}

	private struct folder_container {
		public string folder;
		public string[] exclude;
		public bool valid;

		public folder_container(string folder, string[] exclude_list) {
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
					this.exclude += x.substring(this.folder.length);
				}
			}
		}
	}
}
