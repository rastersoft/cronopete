/*
 Copyright 2011-2018 (C) Raster Software Vigo (Sergio Costas)

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
using Gtk;
using Gdk;
using Posix;
using UDisks;

[DBus (name = "org.freedesktop.DBus.ObjectManager")]
interface UDisk2_if : GLib.Object {
    public abstract void GetManagedObjects(out GLib.HashTable<ObjectPath,GLib.HashTable<string,GLib.HashTable<string,Variant>>> path) throws IOError;
}

[DBus (timeout = 10000000, name = "org.freedesktop.DBus.Introspectable")]
interface Introspectable_if : GLib.Object {
    public abstract async void Introspect(out string xml_data) throws IOError;
}

[DBus (timeout = 1000000, name = "org.freedesktop.UDisks2.Block")]
interface Block_if : GLib.Object {

    public abstract string IdLabel { owned get; }
    public abstract string IdUUID { owned get; }

    public abstract async void Format(string type,GLib.HashTable<string,Variant> options) throws IOError;
}

[DBus (timeout = 10000000, name = "org.freedesktop.UDisks2.Filesystem")]
interface Filesystem_if : GLib.Object {
    public abstract async void Mount(GLib.HashTable<string,Variant> options, out string mount_path) throws IOError;
    public abstract async void Unmount(GLib.HashTable<string,Variant> options) throws IOError;
}

public class c_format : GLib.Object {

    private string uipath;
    private Gtk.Window parent_window;

    public signal void format_ended(int status);

    public c_format(Gtk.Window parent) {

        this.parent_window = parent;
    }

    private void show_error(string msg) {

        GLib.stdout.printf("Error: %s\n",msg);

        var builder=new Builder();
        builder.add_from_file(Path.build_filename(this.uipath,"format_error.ui"));
        var label = (Label) builder.get_object("msg_error");
        label.set_label(msg);
        var w = (Dialog) builder.get_object("error_dialog");
        w.set_transient_for(this.parent_window);
        w.show_all();
        w.run();
        w.hide();
        w.destroy();

    }

    private async string? do_format(string disk_uuid) {

        string? final_uuid = null;

        GLib.HashTable<ObjectPath,GLib.HashTable<string,GLib.HashTable<string,Variant>>> objects;
        UDisk2_if udisk = Bus.get_proxy_sync<UDisk2_if> (BusType.SYSTEM, "org.freedesktop.UDisks2","/org/freedesktop/UDisks2");
        udisk.GetManagedObjects(out objects);

        ObjectPath? disk = null;
        Block_if? block = null;

        foreach(var o in objects.get_keys()) {
            Introspectable_if intro = Bus.get_proxy_sync<Introspectable_if> (BusType.SYSTEM, "org.freedesktop.UDisks2",o);
            string data;
            yield intro.Introspect(out data);
            // check if it has the Block and Filesystem interfaces
            if (data.contains("org.freedesktop.UDisks2.Block") && data.contains("org.freedesktop.UDisks2.Filesystem")) {
                block = Bus.get_proxy_sync<Block_if> (BusType.SYSTEM, "org.freedesktop.UDisks2",o);
                if (block.IdUUID == disk_uuid) {
                    disk = o;
                    break;
                }
            }
        }

        if (disk == null) { // Failed to find the disk!!!!!!
            this.show_error(_("Failed to find the disk!!!!!"));
            return final_uuid;
        }

        var filesystem = Bus.get_proxy_sync<Filesystem_if> (BusType.SYSTEM, "org.freedesktop.UDisks2",disk);
        var hash = new GLib.HashTable<string,Variant>(str_hash,str_equal);
        try {
            yield filesystem.Unmount(hash);
        } catch (GLib.Error e) {
            this.show_error(_("Failed to unmount the disk. Aborting format operation."));
            return final_uuid;
        }

        var builder2 = new Builder();
        builder2.add_from_file(Path.build_filename(this.uipath,"formatting.ui"));
        var format_window = (Dialog) builder2.get_object("formatting");
        format_window.set_transient_for(this.parent_window);
        format_window.show_all();

        var boolvariant  = new GLib.Variant.boolean(true);
        var boolvariant2 = new GLib.Variant.boolean(true);
        var boolvariant3 = new GLib.Variant.boolean(true);
        hash = new GLib.HashTable<string,Variant>(str_hash,str_equal);
        hash.insert("take-ownership",boolvariant);
        hash.insert("update-partition-type",boolvariant2);
        hash.insert("erase",boolvariant3);

        try {
            yield block.Format("ext4",hash);
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

        hash = new GLib.HashTable<string,Variant>(str_hash,str_equal);
        string mount_path;
        try {
            yield filesystem.Mount(hash,out mount_path);
        } catch (GLib.Error e) {
            this.show_error(_("Failed to mount again the disk. Aborting the format operation."));
            return final_uuid;
        }

        final_uuid = block.IdUUID;
        return final_uuid;
    }

    public string? run(string path,string disk_uuid) {

        this.uipath=path;
        string? new_uuid = null;
        string message;
        var builder = new Builder();

        builder.add_from_file(Path.build_filename(path,"format_force.ui"));
        message = _("The selected drive must be formated to be used for backups.\n\nTo do it, click the <i>Format disk</i> button.\n\n<b>All the data in the drive will be erased</b>");
        builder.connect_signals(this);

        var label = (Label) builder.get_object("label_text");
        label.set_label(message);

        var window = (Dialog) builder.get_object("dialog_format");
        window.set_transient_for(this.parent_window);

        window.show_all();
        var rv=window.run();
        window.destroy();
        if (rv==1) { // format
            this.do_format.begin(disk_uuid, (obj,res) => {
                new_uuid = this.do_format.end(res);
                Gtk.main_quit();
            });
            Gtk.main();
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
    private VolumeMonitor monitor;
    private TreeView disk_list;
    private Gtk.Window parent_window;
    private string basepath;
    private Dialog choose_w;
    private GLib.Settings cronopete_settings;

    private Gtk.CheckButton show_all;

    private void show_all_toggled() {
        /**
         * Called when the user selects or unselects the "Show all disks" toggle
         */
        this.refresh_list();
    }

    public c_choose_disk(Gtk.Window parent) {
        this.parent_window = parent;
    }

    public string? run(GLib.Settings c_settings) {

        this.cronopete_settings = c_settings;
        this.builder = new Builder();
        this.builder.add_from_file(Path.build_filename(Constants.PKGDATADIR, "chooser.ui"));
        this.builder.connect_signals(this);

        this.choose_w = (Dialog) this.builder.get_object("disk_chooser");
        this.choose_w.set_transient_for(this.parent_window);

        this.disk_list = (TreeView) this.builder.get_object("disk_list");
        this.ok_button = (Button) this.builder.get_object("ok_button");

        this.show_all = (Gtk.CheckButton) this.builder.get_object("show_all_disks");
        this.cronopete_settings.bind("all-drives", this.show_all, "active", GLib.SettingsBindFlags.DEFAULT);
        this.show_all.toggled.connect(this.show_all_toggled);

        this.disk_listmodel = new Gtk.ListStore (6, typeof(Icon), typeof (string), typeof (string), typeof (string), typeof (string), typeof (string));
        this.disk_list.set_model(this.disk_listmodel);
        var crpb = new CellRendererPixbuf();
        crpb.stock_size = IconSize.DIALOG;
        this.disk_list.insert_column_with_attributes (-1, "", crpb , "gicon", 0);
        this.disk_list.insert_column_with_attributes (-1, "", new CellRendererText (), "text", 1);
        this.disk_list.insert_column_with_attributes (-1, "", new CellRendererText (), "text", 2);
        this.disk_list.insert_column_with_attributes (-1, "", new CellRendererText (), "text", 3);

        this.monitor = VolumeMonitor.get();
        this.monitor.mount_added.connect_after(this.refresh_list);
        this.monitor.mount_removed.connect_after(this.refresh_list);
        this.refresh_list();
        this.set_ok();

        this.choose_w.show();

        string? final_disk_uuid = null;

        while (true) {
            var r = this.choose_w.run ();

            if (r != -5) {
                break;
            }

            var selected = this.disk_list.get_selection();
            if (selected.count_selected_rows()!=0) {

                TreeModel model;
                TreeIter iter;
                GLib.Value spath;
                GLib.Value stype;
                GLib.Value suid;

                selected.get_selected(out model, out iter);
                model.get_value(iter, 4, out spath);
                model.get_value(iter, 5, out suid);
                model.get_value(iter, 2, out stype);
                var fstype = stype.get_string().dup();
                var final_path = spath.get_string().dup();
                var final_uid = suid.get_string().dup();

                // EXT4 is the recomended filesystem for cronopete
                if ((fstype == "reiserfs") || (fstype.has_prefix("btrfs")) || (fstype.has_prefix("ext4"))) {
                    var backup_path = Path.build_filename(final_path, "cronopete");
                    var directory2 = File.new_for_path(backup_path);
                    // if the media doesn't have the folder "cronopete", try to create it
                    if (!directory2.query_exists()) {
                        try {
                            // if it's possible to create it, go ahead
                            directory2.make_directory_with_parents();
                            final_disk_uuid = final_uid;
                            retval = Posix.chmod(backup_path, 0x01FF); // everybody can read and write
                            if (retval == 0) {
                                break;
                            }
                        } catch (IOError e) {
                            // if not, the media is not writable by this user, so propose to format it
                        }
                    } else {
                        final_disk_uuid = final_uid;
                        var retval = Posix.chmod(backup_path, 0x01FF); // everybody can read and write
                        if (retval == 0) {
                            break;
                        }
                        break;
                    }
                }
                this.choose_w.hide();

                var w = new c_format(this.parent_window);
                final_disk_uuid = w.run(this.basepath,final_uid);
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
        if (selected.count_selected_rows()!=0) {
            this.ok_button.sensitive=true;
        } else {
            this.ok_button.sensitive=false;
        }
    }

    private bool check_is_external(string uid) {

        if (this.refresh_list.get_active()) {
            return (true);
        }

        try {
            var client = new UDisks.Client.sync();
            var blocks = client.get_block_for_uuid(uid);
            foreach (var o in blocks) {
                var drive = client.get_drive_for_block(o);
                if (drive != null) {
                    if (drive.removable || drive.media_removable) {
                        return true;
                    } else {
                        return false;
                    }
                }
            }
        } catch (IOError e) {
            GLib.stdout.printf(e.message);
        }
        return (true);
    }

    private void refresh_list() {

        TreeIter iter;
        Mount mnt;
        File root;
        string path;
        string bpath;
        string ssize;
        string fsystem;
        string uid;
        bool first;

        var volumes = this.monitor.get_volumes();

        this.disk_listmodel.clear();
        first = true;

        foreach (Volume v in volumes) {

            mnt=v.get_mount();
            if ((mnt is Mount)==false) {
                continue;
            }

            root=mnt.get_root();
            FileInfo info = null;
            fsystem = null;
            uint64 size = 0;
            try {
                info = root.query_filesystem_info("filesystem::type,filesystem::size",null);
                fsystem = info.get_attribute_string("filesystem::type");
                size = info.get_attribute_uint64("filesystem::size");
            } catch (GLib.Error e) {
                fsystem = null;
                print ("Failed to get filesystem data");
            }
            uid = v.get_identifier("uuid");

            if (fsystem=="isofs") {
                continue;
            }

            if (fsystem==null) {
                fsystem=_("Unknown FS");
            }

            path = root.get_path();
            if (false==this.check_is_external(uid)) {
                continue;
            }

            bpath = root.get_basename();

            this.disk_listmodel.append (out iter);

            var tmp = new ThemedIcon.from_names(v.get_icon().to_string().split(" "));

            this.disk_listmodel.set (iter,0,tmp);
            this.disk_listmodel.set (iter,1,bpath);
            this.disk_listmodel.set (iter,2,fsystem);
            if (size == 0) {
                ssize = _("Unknown size");
            } else if (size >= 1000000000) {
                ssize = "%lld GB".printf((size+500000000)/1000000000);
            } else if (size >= 1000000) {
                ssize = "%lld MB".printf((size+500000)/1000000);
            } else if (size >= 1000) {
                ssize = "%lld KB".printf((size+500)/1000);
            } else {
                ssize = "%lld B".printf(size);
            }

            this.disk_listmodel.set (iter,3,ssize);
            this.disk_listmodel.set (iter,4,path);
            this.disk_listmodel.set (iter,5,uid);
            if (first) {
                this.disk_list.get_selection().select_iter(iter);
                first = false;
            }
        }
        this.set_ok();
    }

    [CCode (instance_pos = -1)]
    public bool on_press_event(Gtk.Widget w , Gdk.Event v) {

        this.set_ok();
        return false;
    }

}
