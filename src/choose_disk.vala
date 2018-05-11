/*
 * Copyright 2011-2018 (C) Raster Software Vigo (Sergio Costas)
 *
 * This file is part of Cronopete
 *
 * Cronopete is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * Cronopete is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>. */

using GLib;
using Gtk;
using Gdk;
using Posix;
using UDisks;


public class c_format : GLib.Object {
	private Gtk.Window parent_window;
	private udisk2_cronopete udisk2;

	public signal void format_ended(int status);

	public c_format(Gtk.Window parent) {
		this.parent_window = parent;
		this.udisk2        = new udisk2_cronopete();
	}

	private void show_error(string msg) {
		GLib.stdout.printf("Error: %s\n", msg);

		var builder = new Builder();
		try {
			builder.add_from_file(Path.build_filename(Constants.PKGDATADIR, "format_error.ui"));
		} catch (GLib.Error e) {
			print("Can't show the ERROR window: %s\n".printf(e.message));
			return;
		}
		var label = (Label) builder.get_object("msg_error");
		label.set_label(msg);
		var w = (Dialog) builder.get_object("error_dialog");
		w.set_transient_for(this.parent_window);
		w.show_all();
		w.run();
		w.hide();
		w.destroy();
	}

	private async string ? do_format(string disk_device) {
		string ? final_uuid = null;
		ObjectPath ? disk   = null;

		Filesystem_if filesystem = this.udisk2.get_filesystem_if(disk_device);
		var           hash       = new GLib.HashTable<string, Variant>(str_hash, str_equal);
		try {
			yield filesystem.Unmount(hash);
		} catch (GLib.Error e) {
			this.show_error(_("Failed to unmount the disk. Aborting format operation."));
			return final_uuid;
		}

		var builder2 = new Builder();
		try {
			builder2.add_from_file(Path.build_filename(Constants.PKGDATADIR, "formatting.ui"));
		} catch (GLib.Error e) {
			print("Failed to create the FORMATTING window\n");
		}
		var format_window = (Dialog) builder2.get_object("formatting");
		format_window.set_transient_for(this.parent_window);
		format_window.show_all();

		var boolvariant  = new GLib.Variant.boolean(true);
		var boolvariant2 = new GLib.Variant.boolean(true);
		var boolvariant3 = new GLib.Variant.boolean(true);
		hash = new GLib.HashTable<string, Variant>(str_hash, str_equal);
		hash.insert("take-ownership", boolvariant);
		hash.insert("update-partition-type", boolvariant2);
		hash.insert("erase", boolvariant3);

		Block_if block = this.udisk2.get_block_if(disk_device);

		try {
			yield block.Format("ext4", hash);
		} catch (GLib.Error e) {
			this.show_error(_("Failed to format the disk (maybe it is needing too much time). Please, try again."));
			format_window.hide();
			format_window.destroy();
			format_window = null;
			return final_uuid;
		}
		format_window.hide();
		format_window.destroy();
		format_window = null;

		filesystem = this.udisk2.get_filesystem_if(disk_device);
		hash = new GLib.HashTable<string, Variant>(str_hash, str_equal);
		string mount_path;
		try {
			yield filesystem.Mount(hash, out mount_path);
		} catch (GLib.Error e) {
			this.show_error(_("Failed to mount again the disk. Aborting the format operation."));
			return final_uuid;
		}

		block = this.udisk2.get_block_if(disk_device);
		final_uuid = block.IdUUID;
		return final_uuid;
	}

	public string ? run(string disk_device) {
		string ? new_uuid = null;
		string message;
		var    builder = new Builder();

		try {
			builder.add_from_file(Path.build_filename(Constants.PKGDATADIR, "format_force.ui"));
		} catch (GLib.Error e) {
			return null;
		}
		message = _("The selected drive must be formated to be used for backups.\n\nTo do it, click the <i>Format disk</i> button.\n\n<b>All the data in the drive will be erased</b>");
		builder.connect_signals(this);

		var label = (Label) builder.get_object("label_text");
		label.set_label(message);

		var window = (Dialog) builder.get_object("dialog_format");
		window.set_transient_for(this.parent_window);

		window.show_all();
		var rv = window.run();
		window.destroy();
		// format
		var loop = new GLib.MainLoop();
		if (rv == 1) {
			this.do_format.begin(disk_device, (obj, res) => {
				new_uuid = this.do_format.end(res);
				loop.quit();
			});
			loop.run();
		}
		return new_uuid;
	}
}


public class c_choose_disk : GLib.Object {
	/**
	 * Shows a Dialog for choosing the disk drive where to do the backups
	 */

	private Builder builder;
	Gtk.ListStore disk_listmodel;
	private Button ok_button;
	private TreeView disk_list;
	private Gtk.Window parent_window;
	private Dialog choose_w;
	private GLib.Settings cronopete_settings;

	private Gtk.CheckButton show_all_disks;

	private udisk2_cronopete udisk2;

	private void show_all_toggled() {
		/**
		 * Called when the user selects or unselects the "Show all disks" toggle
		 */
		this.refresh_list();
	}

	public c_choose_disk(Gtk.Window parent) {
		this.parent_window = parent;
		this.udisk2        = new udisk2_cronopete();
	}

	private bool create_folders(string backup_path) {
		var userpath   = Path.build_filename(backup_path, Environment.get_user_name());
		var userfolder = File.new_for_path(userpath);
		try {
			if (userfolder.query_exists() || userfolder.make_directory_with_parents()) {
				// only the user can read and write
				if (0 == Posix.chmod(userpath, 0x01C0)) {
					return true;
				}
			}
		} catch (GLib.Error e) {}
		return false;
	}

	public string ? run(GLib.Settings c_settings) {
		this.cronopete_settings = c_settings;
		this.builder            = new Builder();
		try {
			this.builder.add_from_file(Path.build_filename(Constants.PKGDATADIR, "chooser.ui"));
		} catch (GLib.Error e) {
			print("Failed to create the window for choosing the disk\n");
			return null;
		}
		this.builder.connect_signals(this);

		this.choose_w = (Dialog) this.builder.get_object("disk_chooser");
		this.choose_w.set_transient_for(this.parent_window);

		this.disk_list = (TreeView) this.builder.get_object("disk_list");
		this.ok_button = (Button) this.builder.get_object("ok_button");

		this.show_all_disks = (Gtk.CheckButton) this.builder.get_object("show_all_disks");
		this.cronopete_settings.bind("all-drives", this.show_all_disks, "active", GLib.SettingsBindFlags.DEFAULT);
		this.show_all_disks.toggled.connect(this.show_all_toggled);

		this.disk_listmodel = new Gtk.ListStore(7, typeof(Icon), typeof(string), typeof(string), typeof(string), typeof(string), typeof(string), typeof(string));
		this.disk_list.set_model(this.disk_listmodel);
		var crpb = new CellRendererPixbuf();
		crpb.stock_size = IconSize.DIALOG;
		this.disk_list.insert_column_with_attributes(-1, "", crpb, "gicon", 0);
		this.disk_list.insert_column_with_attributes(-1, "", new CellRendererText(), "text", 1);
		this.disk_list.insert_column_with_attributes(-1, "", new CellRendererText(), "text", 2);
		this.disk_list.insert_column_with_attributes(-1, "", new CellRendererText(), "text", 3);
		this.disk_list.insert_column_with_attributes(-1, "", new CellRendererText(), "text", 4);

		this.udisk2.InterfacesAdded.connect_after(this.refresh_list);
		this.udisk2.InterfacesRemoved.connect_after(this.refresh_list);

		this.refresh_list();
		this.set_ok();

		this.choose_w.show();

		string ? final_disk_uuid = null;

		while (true) {
			var r = this.choose_w.run();

			if (r != -5) {
				break;
			}

			var selected = this.disk_list.get_selection();
			if (selected.count_selected_rows() != 0) {
				TreeModel  model;
				TreeIter   iter;
				GLib.Value spath;
				GLib.Value stype;
				GLib.Value suid;
				GLib.Value device;

				selected.get_selected(out model, out iter);
				model.get_value(iter, 4, out spath);
				model.get_value(iter, 5, out suid);
				model.get_value(iter, 2, out stype);
				model.get_value(iter, 6, out device);
				var fstype       = stype.get_string().dup();
				var final_path   = spath.get_string().dup();
				var final_uid    = suid.get_string().dup();
				var final_device = device.get_string().dup();
				// EXT4 is the recomended filesystem for cronopete, but supports reiser, ext3 and btrfs for preformated disks
				if ((fstype == "reiserfs") || (fstype == "btrfs") || (fstype.has_prefix("ext3")) || (fstype.has_prefix("ext4"))) {
					var backup_path = Path.build_filename(final_path, "cronopete");
					var directory2  = File.new_for_path(backup_path);
					// if the media doesn't have the folder "cronopete", try to create it
					if (directory2.query_exists() == false) {
						try {
							// if it's possible to create it, go ahead
							if (directory2.make_directory_with_parents()) {
								// make that everybody can read and write
								if (0 == Posix.chmod(backup_path, 0x01FF)) {
									if (this.create_folders(backup_path)) {
										final_disk_uuid = final_uid;
										break;
									}
								}
							}
						} catch (GLib.Error e) {
							// if not, the media is not writable by this user, so propose to format it
						}
					} else {
						if (this.create_folders(backup_path)) {
							final_disk_uuid = final_uid;
							break;
						}
					}
				}
				this.choose_w.hide();
				var w = new c_format(this.parent_window);
				final_disk_uuid = w.run(final_device);
				if (final_disk_uuid != null) {
					break;
				}
				this.choose_w.show();
				continue;
			}
		}
		this.choose_w.hide();
		this.choose_w.destroy();
		return final_disk_uuid;
	}

	private void set_ok() {
		var selected = this.disk_list.get_selection();
		if (selected.count_selected_rows() != 0) {
			this.ok_button.sensitive = true;
		} else {
			this.ok_button.sensitive = false;
		}
	}

	private void refresh_list() {
		TreeIter iter;

		string ssize;
		bool   first;

		Gee.Map<ObjectPath, Drive_if>      drives      = new Gee.HashMap<ObjectPath, Drive_if>();
		Gee.Map<ObjectPath, Block_if>      blocks      = new Gee.HashMap<ObjectPath, Block_if>();
		Gee.Map<ObjectPath, Filesystem_if> filesystems = new Gee.HashMap<ObjectPath, Filesystem_if>();

		try {
			this.udisk2.get_drives(out drives, out blocks, out filesystems);
		} catch (GLib.IOError e) {
			print("IO error: %s\n".printf(e.message));
			return;
		} catch (GLib.DBusError e) {
			print("DBus error: %s\n".printf(e.message));
			return;
		}

		this.disk_listmodel.clear();
		first = true;

		string home_folder = Environment.get_home_dir();
		foreach (var disk_obj in blocks.keys) {
			var block        = blocks.get(disk_obj);
			var fs           = filesystems.get(disk_obj);
			var mount_points = fs.MountPoints.dup_bytestring_array();
			if (mount_points.length == 0) {
				// show only the ones already mounted
				continue;
			}

			// check if this partition is where the HOME folder is
			// or is the "/boot" partition
			bool forbiden_folder = false;
			foreach (var mp in mount_points) {
				if ((home_folder.has_prefix(mp)) || (mp.has_prefix("/boot"))) {
					forbiden_folder = true;
					break;
				}
			}

			if (forbiden_folder) {
				continue;
			}

			string path  = mount_points[0];
			var    drv   = block.Drive;
			var    drive = drives.get(drv);

			string fsystem = block.IdType;
			uint64 size    = block.Size;
			var    uid     = block.IdUUID;

			if ((fsystem == "iso9660") || (fsystem == "squashfs")) {
				continue;
			}

			if ((fsystem == null) || (fsystem == "")) {
				// TRANSLATORS this message says that the current File System (FS) in an external disk is unknown. It is shown when listing the external disks connected to the computer
				fsystem = _("Unknown FS");
			}

			if (this.show_all_disks.get_active() == false) {
				if (block.ReadOnly) {
					continue;
				}
				if (drive.Removable == false) {
					continue;
				}
			}

			var bpath = block.IdLabel;
			if (bpath == "") {
				bpath = uid;
			}

			this.disk_listmodel.append(out iter);

			string ? icon = block.HintIconName;
			if ((icon == null) || (icon == "")) {
				icon = "drive-harddisk";
			}

			var tmp = new ThemedIcon.from_names(icon.split(" "));

			this.disk_listmodel.set(iter, 0, tmp);
			this.disk_listmodel.set(iter, 1, bpath);
			this.disk_listmodel.set(iter, 2, fsystem);
			if (size == 0) {
				// TRANSLATORS Specifies that the size of an external disk is unknown
				ssize = _("Unknown size");
			} else if (size >= 1000000000) {
				ssize = "%lld GB".printf((size + 500000000) / 1000000000);
			} else if (size >= 1000000) {
				ssize = "%lld MB".printf((size + 500000) / 1000000);
			} else if (size >= 1000) {
				ssize = "%lld KB".printf((size + 500) / 1000);
			} else {
				ssize = "%lld B".printf(size);
			}

			this.disk_listmodel.set(iter, 3, ssize);
			this.disk_listmodel.set(iter, 4, path);
			this.disk_listmodel.set(iter, 5, uid);
			this.disk_listmodel.set(iter, 6, disk_obj);
			if (first) {
				this.disk_list.get_selection().select_iter(iter);
				first = false;
			}
		}
		this.set_ok();
	}

	[CCode(instance_pos = -1)]
	public bool on_press_event(Gtk.Widget origin, Gdk.Event event) {
		this.set_ok();
		return false;
	}
}
