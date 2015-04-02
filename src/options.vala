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
using Gtk;
using Gdk;

class c_options : GLib.Object {

    private cp_callback parent;
    private string basepath;
    private Builder builder;
    private Dialog main_w;
    private TreeView backup_view;
    private TreeView exclude_view;
    private CheckButton b_hiden;
    private SpinButton w_period;
    ListStore backup_listmodel;
    ListStore exclude_listmodel;
    private Gee.List<string> backup_folders;
    private Gee.List<string> exclude_folders;
    private Gee.List<string> tmp_backup_folders;
    private Gee.List<string> tmp_exclude_folders;
    private bool backup_hiden_at_home;
    private uint period;

    private GLib.Settings cronopete_settings;

    public c_options(string path, cp_callback p) {

        int retval;

        this.parent = p;
        this.basepath=path;
        this.builder = new Builder();
        this.builder.add_from_file(Path.build_filename(this.basepath,"options.ui"));

        this.main_w = (Dialog) this.builder.get_object("options");
        this.builder.connect_signals(this);

        this.backup_view = (TreeView) this.builder.get_object("backup_folders");
        this.exclude_view = (TreeView) this.builder.get_object("exclude_folders");
        this.b_hiden = (CheckButton) this.builder.get_object("backup_root_hiden");
        this.w_period = (SpinButton) this.builder.get_object("backup_period");
        this.b_hiden.label=_("Backup hidden files and folders in %s").printf(Environment.get_home_dir());

        this.cronopete_settings = new GLib.Settings("org.rastersoft.cronopete");

        this.w_period.set_value((float)((this.cronopete_settings.get_uint("backup-period"))/3600));

        this.tmp_backup_folders = new Gee.ArrayList<string>();
        string[] folder_list=this.cronopete_settings.get_strv("backup-folders");
        if (folder_list.length==0) {
            folder_list={};
            folder_list+=GLib.Environment.get_home_dir();
        }
        foreach (string s in folder_list) {
            this.tmp_backup_folders.add(s);
        }

        this.tmp_exclude_folders = new Gee.ArrayList<string>();
        foreach (string s in this.cronopete_settings.get_strv("exclude-folders")) {
            this.tmp_exclude_folders.add(s);
        }

        this.backup_listmodel = new ListStore (1, typeof (string));
        this.backup_view.set_model(this.backup_listmodel);
        this.backup_view.insert_column_with_attributes (-1, "Folders to backup", new CellRendererText (), "text", 0);

        this.exclude_listmodel = new ListStore (1, typeof (string));
        this.exclude_view.set_model(this.exclude_listmodel);
        this.exclude_view.insert_column_with_attributes (-1, "Folders to exclude", new CellRendererText (), "text", 0);

        this.fill_backup_list(false);
        this.fill_exclude_list(false);
        if (this.cronopete_settings.get_boolean("skip-hiden-at-home")) {
            this.b_hiden.active=false;
        } else {
            this.b_hiden.active=true;
        }

        this.main_w.show_all();
        retval=this.main_w.run();
        this.main_w.hide();
        this.main_w.destroy();
        if (retval==-6) {
            if (this.b_hiden.active) {
                this.cronopete_settings.set_boolean("skip-hiden-at-home",false);
            } else {
                this.cronopete_settings.set_boolean("skip-hiden-at-home",true);
            }
            this.cronopete_settings.set_uint("backup-period",3600*((uint)this.w_period.get_value_as_int()));
            string[] bfold={};
            foreach(string v in this.tmp_backup_folders) {
                bfold+=v;
            }
            string[] efold={};
            foreach(string v in this.tmp_exclude_folders) {
                efold+=v;
            }
            this.cronopete_settings.set_strv("backup-folders",bfold);
            this.cronopete_settings.set_strv("exclude-folders",efold);
        }
    }

    private void fill_backup_list(bool erase) {

        if (erase) {
            this.backup_listmodel.clear();
        }
        this.tmp_backup_folders.sort();
        foreach (string s in this.tmp_backup_folders) {

            TreeIter iter;

            this.backup_listmodel.append (out iter);
            this.backup_listmodel.set (iter,0,s);
        }
    }

    private void fill_exclude_list(bool erase) {

        if (erase) {
            this.exclude_listmodel.clear();
        }
        this.tmp_exclude_folders.sort();
        foreach (string s in this.tmp_exclude_folders) {

            TreeIter iter;

            this.exclude_listmodel.append (out iter);
            this.exclude_listmodel.set (iter,0,s);
        }
    }

    [CCode (instance_pos = -1)]
    public void on_remove_backup_clicked(Gtk.Button w) {

        var selected = this.backup_view.get_selection();
        if (selected.count_selected_rows()!=0) {
            TreeModel model;
            TreeIter iter;
            selected.get_selected(out model, out iter);
            GLib.Value val;
            model.get_value(iter,0,out val);
            var path = val.dup_string();
            this.tmp_backup_folders.remove(path);
            this.fill_backup_list(true);
        }
    }

    [CCode (instance_pos = -1)]
    public void on_remove_exclude_clicked(Gtk.Button w) {

        var selected = this.exclude_view.get_selection();
        if (selected.count_selected_rows()!=0) {
            TreeModel model;
            TreeIter iter;
            selected.get_selected(out model, out iter);
            GLib.Value val;
            model.get_value(iter,0,out val);
            var path = val.dup_string();
            this.tmp_exclude_folders.remove(path);
            this.fill_exclude_list(true);
        }
    }

    [CCode (instance_pos = -1)]
    public void on_add_backup_clicked(Gtk.Button w) {

        int retval;
        var tmp_builder = new Builder();
        tmp_builder.add_from_file(Path.build_filename(this.basepath,"folder_selector.ui"));
        var selector = (FileChooserDialog) tmp_builder.get_object("folder_selector");
        selector.show_all();
        retval = selector.run();
        if (retval==-6) {
                var files = selector.get_filenames();
            foreach (var file_uri in files) {
                if (file_uri!=null) {
                if (file_uri.has_prefix("file://")) {
                    file_uri = file_uri.substring(7,-1);
                }
                if (false==this.tmp_backup_folders.contains(file_uri)) {
                    this.tmp_backup_folders.add(file_uri);
                }
                this.fill_backup_list(true);
                }
            }
        }
        selector.hide();
        selector.destroy();

    }

    [CCode (instance_pos = -1)]
    public void on_add_exclude_clicked(Gtk.Button w) {

        int retval;

        var tmp_builder = new Builder();
        tmp_builder.add_from_file(Path.build_filename(this.basepath,"folder_selector.ui"));
        var selector = (FileChooserDialog) tmp_builder.get_object("folder_selector");
        selector.show_all();
        retval = selector.run();
        if (retval==-6) {
            var files = selector.get_filenames();
            foreach (var file_uri in files) {
                if (file_uri!=null) {
                    if (file_uri.has_prefix("file://")) {
                        file_uri = file_uri.substring(7,-1);
                    }
                    if (false==this.tmp_exclude_folders.contains(file_uri)) {
                        this.tmp_exclude_folders.add(file_uri);
                    }
                    this.fill_exclude_list(true);
                }
            }
        }
        selector.hide();
        selector.destroy();
    }
}
