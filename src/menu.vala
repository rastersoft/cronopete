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

class c_main_menu : GLib.Object {

    private weak TextBuffer log;
    private string basepath;
    private Window main_w;
    private Builder builder;
    private Notebook tabs;
    private cp_callback parent;
    private Image active;
    private Label Lvid;
    private Label Loldest;
    private Label Lnewest;
    private Label Lnext;
    private Label Lspace;
    private Label text_status;
    private Image img;
    private Gtk.ToggleButton show_in_bar_ch;
    private TextMark mark;
    private TextView log_view;
    private string last_status;
    private Switch my_widget;

    public bool is_visible;
    private GLib.Settings cronopete_settings;
    private IOChannel io_read;
    private IOChannel io_write;

    public bool switch_enabler {
        get {
            return this.parent.active;
        }

        set {
            this.my_widget.active=value;
            if (this.is_visible==false) {
                this.parent.active=value;
            }
        }
    }

    public c_main_menu(string path, cp_callback p,GLib.Settings q) {

        this.parent = p;
        this.basepath=path;
        this.cronopete_settings = q;

        this.builder = new Builder();
        this.builder.add_from_file(Path.build_filename(this.basepath,"main.ui"));

        this.main_w = (Window) this.builder.get_object("window1");

        this.log = (TextBuffer) this.builder.get_object("textbuffer1");
        this.log_view = (TextView) this.builder.get_object("textview1");
        this.tabs = (Notebook) this.builder.get_object("notebook1");
        this.active = (Image) this.builder.get_object("is_active");
        this.Lvid = (Label) this.builder.get_object("label_volume");
        this.Loldest = (Label) this.builder.get_object("label_oldest_backup");
        this.Lnewest = (Label) this.builder.get_object("label_newest_backup");
        this.Lnext = (Label) this.builder.get_object("label_next_backup");
        this.Lspace = (Label) this.builder.get_object("label_free_space");
        var status_alignment = (Gtk.Alignment) this.builder.get_object("status_frame");
        this.text_status = new fixed_label("",300);
        status_alignment.add (this.text_status);
        this.text_status.ellipsize = Pango.EllipsizeMode.MIDDLE;
        this.img = (Image) this.builder.get_object("image_disk");
        this.show_in_bar_ch = (Gtk.ToggleButton) this.builder.get_object("show_in_bar");

        this.show_in_bar_ch.set_active(this.parent.show_in_bar);

        var cnt = (VBox) this.builder.get_object("vbox_switch");

        this.my_widget = (Gtk.Switch) this.builder.get_object("switch_main");
        this.my_widget.notify_property("active");

        this.is_visible = false;
        this.builder.connect_signals(this);
        this.cronopete_settings.bind("enabled",this.my_widget,"active",GLib.SettingsBindFlags.DEFAULT);
        this.cronopete_settings.bind("visible",this.show_in_bar_ch,"active",GLib.SettingsBindFlags.DEFAULT);
        
        int[] fd = new int[2]; // file descriptor
        int ret;

        // setup a pipe
        ret = Posix.pipe(fd);
        if(ret == -1) {
            print("Creating pipe failed: %s\n", strerror(errno));
        } else {

            // setup iochannels
            io_read  = new IOChannel.unix_new(fd[0]);
            io_write = new IOChannel.unix_new(fd[1]);

            if((io_read == null) || (io_write == null)) {
                print("Cannot create new IOChannel!\n");
            }

            // The watch calls the gio_in function, if there data is available for 
            // reading without locking
            if(!(io_read.add_watch(IOCondition.IN | IOCondition.HUP, insert_text_log) != 0)) {
                print("Cannot add watch on IOChannel!\n");
            }
        }
    }
    public void set_status(string msg) {

        /* This string shows the current status of Cronopete. It could be
            Status: idle, or Status: copying file... */
        this.last_status=_("Status: %s").printf(msg);
        if (this.is_visible) {
            this.text_status.set_label(this.last_status);
        }
    }

    public void insert_log(string msg,bool reset) {

        if (this.is_visible) {
            if (reset) {
                TextIter iter;
                this.log.set_text(msg,-1);
                this.log.get_end_iter(out iter);
                this.mark = this.log.create_mark("end", iter, false);
                this.log_view.scroll_to_mark(this.mark, 0.05, true, 0.0, 1.0);
            } else {
                // From another thread, use the pipe
                size_t len;
                this.io_write.write_chars((char[])msg,out len);
            }
        }
    }

    private bool insert_text_log(IOChannel gio, IOCondition condition) {
        IOStatus ret;
        string msg;
        size_t len;

        if((condition & IOCondition.HUP) == IOCondition.HUP) {
            print("Read end of pipe died!\n");
        }

        try {
            ret = gio.read_line(out msg, out len, null);
        }
        catch(IOChannelError e) {
            print("Error reading: %s\n", e.message);
        }
        catch(ConvertError e) {
            print("Error reading: %s\n", e.message);
        }
        TextIter iter;
        this.log.insert_at_cursor(msg,(int)len);
        this.log.get_end_iter(out iter);
        this.mark = this.log.create_mark("end", iter, false);
        this.log_view.scroll_to_mark(this.mark, 0.05, true, 0.0, 1.0);
        return true;
    }

    private string parse_date(time_t val) {

        string retval;

        if (val==0) {
            // This is returned as the date for the first, last... backup when it doesn't exists (eg: last backup: none)
            retval=_("None");
        } else {
            var date = new DateTime.from_unix_local(val);


            time_t current = time_t();
            if ((current-val)<86400) {
                retval = date.format("%X").dup();
            } else {
                retval = date.format("%x").dup();
            }
        }

        return retval;
    }

    public void show_main(bool show_log, string log) {

        this.refresh_backup_data();

        this.log.set_text(log,-1);
        this.cronopete_settings.set_boolean("show-welcome",false);
        this.main_w.show_all();
        this.main_w.present();

        this.tabs.set_current_page(0);

        this.my_widget.active=this.parent.active;

        TextIter iter;
        this.log.get_end_iter(out iter);
        this.mark = this.log.create_mark("end", iter, false);
        this.log_view.scroll_to_mark(this.mark, 0.05, true, 0.0, 1.0);
        this.text_status.set_label(this.last_status);
        this.is_visible = true;

    }

    public void refresh_backup_data() {

        string? volume_id;
        time_t oldest;
        time_t newest;
        time_t next;
        uint64 total_space;
        uint64 free_space;

        this.parent.get_backup_data(out volume_id, out oldest, out newest, out next, out total_space, out free_space);

        if (volume_id==null) {
            // This text means that the user still has not selected a hard disk where to do the backups
            this.Lvid.set_text(_("Not defined"));
        } else {
            this.Lvid.set_text(volume_id);
        }
        this.Loldest.set_text(this.parse_date(oldest));
        this.Lnewest.set_text(this.parse_date(newest));
        this.Lnext.set_text(this.parse_date(next));
        /* This string specifies the available and total disk space in back up drive. Example: 43 GB of 160 GB */
        this.Lspace.set_text(_("%lld GB of %lld GB").printf((free_space+900000000)/1073741824,(total_space+900000000)/1073741824));

    }

    [CCode (instance_pos = -1)]
    public void cronopete_options_callback(Button source) {

        var tmp = new c_options(this.main_w,this.basepath,this.parent);
        this.refresh_backup_data();
        tmp = null;

    }

    [CCode (instance_pos = -1)]
    public bool on_destroy_event(Gtk.Widget o) {

        this.main_w.hide();
        this.is_visible = false;
        return true;
    }

    [CCode (instance_pos = -1)]
    public bool on_delete_event(Gtk.Widget source, Gdk.Event e) {

        this.is_visible = false;
        this.main_w.hide();
        return true;

    }

    [CCode (instance_pos = -1)]
    public void cronopete_change_disk_callback(Button source) {

        bool not_configured;

        if (this.cronopete_settings.get_string("backup-uid") == "") {
            not_configured=true;
        } else {
            not_configured=false;
        }
        var tmp = new c_choose_disk(this.main_w,this.basepath);
        var new_uuid = tmp.run(this.cronopete_settings);
        this.refresh_backup_data();
        print("Nuevo uuid: %s\n".printf(new_uuid));
        if (new_uuid != null) {
            this.parent.backup_uid = new_uuid;
        }
        if ((new_uuid != "") && (new_uuid != null) && (not_configured==true) && (this.parent.active==false)) {
            this.parent.active=true;
            this.my_widget.active=true;
        }
    }

    [CCode (instance_pos = -1)]
    public void cronopete_about_clicked(Button source) {

        var w = new Builder();

        w.add_from_file(GLib.Path.build_filename(this.basepath,"about.ui"));

        var about_w = (AboutDialog)w.get_object("aboutdialog1");
        about_w.set_transient_for(this.main_w);

        about_w.set_version(Constants.VERSION);
        about_w.show();
        about_w.run();
        about_w.hide();
        about_w.destroy();
    }

}
