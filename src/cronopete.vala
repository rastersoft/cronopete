/*
 Copyright 2011-14 (C) Raster Software Vigo (Sergio Costas)

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
using Gtk;
using Gdk;
using Cairo;
using Gsl;

// project version=3.17.0

#if !NO_APPINDICATOR
using AppIndicator;
#endif
 
enum SystemStatus { IDLE, BACKING_UP, ABORTING, ENDED }
enum BackupStatus { STOPPED, ALLFINE, WARNING, ERROR }

cp_callback callback_object;

class cp_callback : GLib.Object, callbacks {

#if !NO_APPINDICATOR
    private Indicator appindicator;
#else
    private StatusIcon trayicon;
#endif
    private SystemStatus backup_running;
    private BackupStatus current_status;
    private double angle;
    private int size;
    private unowned Thread <void *> b_thread;
    private uint main_timer;
    private uint refresh_timer;
    private StringBuilder messages;
    private string basepath;
    private Gtk.Menu? menuSystem;
    private Gtk.MenuItem? menuDate;
    private Gtk.MenuItem menuBUnow;
    private Gtk.MenuItem menuSBUnow;
    private Gtk.MenuItem menuEnter;

    private string last_backup;
    private nanockup? basedir;
    private c_main_menu main_menu;
    private bool backup_pending;
    private bool backup_forced;
    private time_t next_backup;
    private uint cur_period;
    private bool tooltip_changed;
    private string tooltip_value;
    private uint iconpos;
    private Gtk.Window main_w2;

    public restore_iface restore_w;

    //private bool configuration_read;
    private bool _active;
    private backends? backend;
    public bool active {
        get {
            return this._active;
        }

        set {
            this._active=value;
            this.repaint(this.size);
            this.status_tooltip();
            if (this._active) {
                // Idle is the status of Cronopete when is doing nothing
                if (this.backup_pending) {
                    this.timer_f();
                }
            }
        }
    }
    private GLib.Settings cronopete_settings;

    private bool _show_in_bar;
    public bool show_in_bar {
        get {
            return this._show_in_bar;
        }

        set {
            this._show_in_bar=value;
#if !NO_APPINDICATOR
            if (this._show_in_bar) {
                this.appindicator.set_status(IndicatorStatus.ACTIVE);
            } else {
                this.appindicator.set_status(IndicatorStatus.PASSIVE);
            }
#else
            this.trayicon.set_visible(this._show_in_bar);
#endif

        }
    }

    private bool update_path;
    private string i_backup_path;

    public string backup_path {

        get {
            return this.i_backup_path;
        }

        set {
            this.i_backup_path=value;
            this.backend=new usbhd_backend(value,this.cronopete_settings.get_string("backup-uid"));
            this.cronopete_settings.set_string("backup-uid",this.backend.get_uuid);
            this.cronopete_settings.set_string("backup-path",this.backend.get_path);
            this.backend.status.connect(this.refresh_status);
            this.refresh_status(null);
        }
    }

    public void refresh_status(usbhd_backend? b) {

        this.repaint(this.size);
        this.status_tooltip();
        this.main_menu.refresh_backup_data();
#if !NO_APPINDICATOR
        this.menuSystem_popup();
#endif
        if ((this._active) && (this.backend.available) && (this.backup_pending)) {
            this.timer_f();
        }
    }

    public void check_welcome() {
        if(this.cronopete_settings.get_boolean("show-welcome")==false) {
            return;
        }
        var w = new Builder();

        w.add_from_file(GLib.Path.build_filename(this.basepath,"welcome.ui"));

        var welcome_w = (Dialog)w.get_object("dialog1");

        welcome_w.show();
        var retval=welcome_w.run();
        welcome_w.hide();
        welcome_w.destroy();
        switch(retval) {
        case 1: // ask me later
        break;
        case 2: // configure now
            this.cronopete_settings.set_boolean("show-welcome",false);
            this.main_clicked();
        break;
        case 3: // don't ask again
            this.cronopete_settings.set_boolean("show-welcome",false);
        break;
        }
    }

    public cp_callback(string path) {

        this.menuSystem=null;
        this.update_path=true;
        this.messages = new StringBuilder("");
        this.backup_running = SystemStatus.IDLE;
        this.current_status = BackupStatus.STOPPED;
        this.angle = 0.0;
        this.size = 0;
        this.refresh_timer = 0;
        this.backup_pending=false;
        this.backup_forced=false;
        this.tooltip_value="";
        this.cronopete_settings = new GLib.Settings("org.rastersoft.cronopete");
        var retval=this.read_configuration();

        this.backend=new usbhd_backend(this.cronopete_settings.get_string("backup-path"),this.cronopete_settings.get_string("backup-uid"));
        this.backend.status.connect(this.refresh_status);
        this.fill_last_backup();

        this.basepath=path;

        this.basedir = null;
        this.main_menu = new c_main_menu(this.basepath,this,this.cronopete_settings);
#if !NO_APPINDICATOR
        this.appindicator = new Indicator("Cronopete","cronopete_arrow_1_green",IndicatorCategory.APPLICATION_STATUS);
        if (this._show_in_bar) {
            this.appindicator.set_status(IndicatorStatus.ACTIVE);
        } else {
            this.appindicator.set_status(IndicatorStatus.PASSIVE);
        }
        this.menuSystem_popup();
#else
        this.trayicon = new StatusIcon();
        this.trayicon.size_changed.connect(this.repaint);
        this.trayicon.set_visible(true);
        this.trayicon.popup_menu.connect(this.menuSystem_popup);
        this.trayicon.activate.connect(this.menuSystem_popup);
#endif
        this.refresh_status(null);
        this.set_tooltip (_("Idle"));

        // wait five minutes after being launched before doing the backup
        int init_delay=300;
        this.cur_period=init_delay;
        this.next_backup=init_delay+time_t();
        init_delay*=1000;
        this.main_timer=GLib.Timeout.add(init_delay,this.timer_f);
        this.cronopete_settings.bind("enabled",this,"active",GLib.SettingsBindFlags.DEFAULT);
        this.cronopete_settings.bind("visible",this,"show_in_bar",GLib.SettingsBindFlags.DEFAULT);
        this.cronopete_settings.bind("backup-path",this,"backup_path",GLib.SettingsBindFlags.DEFAULT);

        if (retval==0) {
            var builder = new Builder();
            builder.add_from_file(GLib.Path.build_filename(this.basepath,"config_exported.ui"));

            this.main_w2 = (Gtk.Window) builder.get_object("window1");
            var btn = (Button)builder.get_object("button1");
            btn.clicked.connect(this.destroy_exported);
            this.main_w2.show();
        }
    }

    public void destroy_exported(Button d) {
        this.main_w2.destroy();
    }

    private void fill_last_backup() {

        if (this.backend==null) {
            this.last_backup=_("Latest backup: %s").printf(_("Not defined"));
            return;
        }

        var backups = this.backend.get_backup_list();
        if (backups==null) {
            this.last_backup=_("Latest backup: %s").printf(_("None"));
            return;
        }

        time_t lastb=0;
        foreach (time_t t in backups) {
            if (t>lastb) {
                lastb=t;
            }
        }
        if (lastb==0) {
            this.last_backup=_("Latest backup: %s").printf(_("None"));
            return;
        }
        var lb = new DateTime.from_unix_local(lastb);
        this.last_backup = _("Latest backup: %s").printf(lb.format("%x %X"));
    }

    public void set_tooltip(string? message, bool backup_thread=false) {

        if (backup_thread) {
            // this function can be called both from the main thread and the backup thread, so is mandatory to take precautions
            lock (this.tooltip_value) {
                if (message==null) {
                    this.tooltip_value="";
                } else {
                    this.tooltip_value=message.dup();
                }
                this.tooltip_changed=true;
            }
        } else {
            lock (this.tooltip_value) {
                if (message==null) {
#if NO_APPINDICATOR
                    this.trayicon.set_tooltip_text (this.tooltip_value);
#endif
                    this.main_menu.set_status(this.tooltip_value);
                    this.tooltip_changed=false;
                } else {
#if NO_APPINDICATOR
                    this.trayicon.set_tooltip_text (message);
#endif
                    this.main_menu.set_status(message);
                }
            }
        }
    }

    public bool timer_f() {

        if (this.tooltip_changed) {
                this.set_tooltip(null);
        }

        if (this.backup_running==SystemStatus.IDLE) {
            uint new_period=this.cronopete_settings.get_uint("backup-period");
            if (this.cur_period!=new_period) {
                this.cur_period=new_period;
                if (this.main_timer!=0) {
                    Source.remove(this.main_timer);
                }
                this.main_timer=GLib.Timeout.add(this.cur_period*1000,this.timer_f);
            }

            this.next_backup=this.cur_period+time_t();

            if (((this._active==false)||(this.backend.available==false))&&(this.backup_forced==false)) {
                this.backup_pending=true;
                return true;
            }

            this.backup_pending=false;

            this.backup_running=SystemStatus.BACKING_UP;
            b_thread=Thread.create <void *>(this.do_backup, false);
            if (this.refresh_timer!=0) {
                Source.remove(this.refresh_timer);
            }
            this.refresh_timer=GLib.Timeout.add(500,this.timer_f);
#if !NO_APPINDICATOR
            this.menuSystem_popup();
#endif

        } else if (this.backup_running==SystemStatus.ENDED) {
            this.backup_forced=false;
            this.backup_running=SystemStatus.IDLE;
            if ((this.current_status==BackupStatus.ALLFINE)||(this.current_status==BackupStatus.WARNING)) {
                this.fill_last_backup();
                this.set_tooltip(_("Idle"));
            }
            if (this.current_status==BackupStatus.ALLFINE) {
                this.current_status=BackupStatus.STOPPED;
            }

            if (this.refresh_timer!=0) {
                Source.remove(this.refresh_timer);
                this.refresh_timer=0;
            }
#if !NO_APPINDICATOR
            this.menuSystem_popup();
#endif
        }

        this.repaint(this.size);
        this.angle-=0.50;
        this.angle%=120.0*Gsl.MathConst.M_PI;
        this.iconpos++;

        if (this.backup_running==SystemStatus.ABORTING) {
            return false;
        } else {
            return true;
        }
    }

    private void status_tooltip() {
        if (this.backend.available==false) {
            this.set_tooltip(_("Storage not available"));
        } else {
            if (this._active) {
                this.set_tooltip(_("Idle"));
            } else {
                this.set_tooltip(_("Backup disabled"));
            }
        }
    }


    /* Paints the animated icon in the panel */
    public bool repaint(int size) {

        string icon_name="cronopete-arrow-";

        switch(this.iconpos) {
        default:
            icon_name+="1";
            this.iconpos=0;
        break;
        case 1:
            icon_name+="2";
        break;
        case 2:
            icon_name+="3";
        break;
        case 3:
            icon_name+="4";
        break;
        }
        icon_name+="-";
        if (this.backend.available==false) {
            icon_name+="red"; // There's no disk connected
        } else {
            if ((this._active)||(this.backup_forced)) {
                switch (this.current_status) {
                case BackupStatus.STOPPED:
                    icon_name+="white"; // Idle
                break;
                case BackupStatus.ALLFINE:
                    icon_name+="green"; // Doing backup; everything fine
                break;
                case BackupStatus.WARNING:
                    icon_name+="yellow";
                break;
                case BackupStatus.ERROR:
                    icon_name+="red";
                break;
                }
            } else {
                icon_name+="orange";
            }
        }

#if !NO_APPINDICATOR
        this.appindicator.set_icon_full(icon_name,"Cronopete, the backup utility");
#else
        this.trayicon.set_from_icon_name(icon_name);
#endif

        return true;
    }

    private void menuSystem_popup() {

#if !NO_APPINDICATOR
        if(this.menuSystem==null)
#endif
        {
            this.menuSystem = new Gtk.Menu();
            this.menuDate = new Gtk.MenuItem();

            menuDate.sensitive=false;
            menuSystem.append(menuDate);

            menuBUnow = new Gtk.MenuItem.with_label(_("Back Up Now"));
            menuBUnow.activate.connect(backup_now);
            this.menuSystem.append(menuBUnow);
            menuSBUnow = new Gtk.MenuItem.with_label(_("Stop Backing Up"));
            menuSBUnow.activate.connect(stop_backup);
            this.menuSystem.append(menuSBUnow);

            menuEnter = new Gtk.MenuItem.with_label(_("Restore files"));
            menuEnter.activate.connect(enter_clicked);
            menuSystem.append(menuEnter);


            var menuBar = new Gtk.SeparatorMenuItem();
            menuSystem.append(menuBar);

            var menuMain = new Gtk.MenuItem.with_label(_("Configure backup policies"));
            menuMain.activate.connect(main_clicked);
            menuSystem.append(menuMain);

            menuSystem.show_all();
#if !NO_APPINDICATOR
            this.appindicator.set_menu(this.menuSystem);
#endif

        }

        this.fill_last_backup();
        this.menuDate.set_label(this.last_backup);
        if (this.backend.available) {
            var list = this.backend.get_backup_list ();
            if ((list==null)||(list.size<=0)) {
                menuEnter.sensitive=false;
            } else {
                menuEnter.sensitive=true;
            }
        } else {
            menuEnter.sensitive=false;
        }
        if (this.backup_running==SystemStatus.IDLE) {
            menuBUnow.show();
            menuSBUnow.hide();
        } else {
            menuSBUnow.show();
            menuBUnow.hide();
        }
        menuBUnow.sensitive=this.backend.available;
        menuSBUnow.sensitive=this.backend.available;

#if NO_APPINDICATOR
        this.menuSystem.popup(null,null,this.trayicon.position_menu,2,Gtk.get_current_event_time());
#endif
    }

    public void backup_now() {

        if (this.backup_running==SystemStatus.IDLE) {
            if (this.refresh_timer>0) {
                Source.remove(this.refresh_timer);
            }
            if (this.main_timer>0) {
                Source.remove(this.main_timer);
                this.main_timer=GLib.Timeout.add(3600000,this.timer_f);
            }
            if (this._active==false) {
                this.backup_forced=true;
            }
            this.timer_f();
        }
    }

    public void stop_backup() {

        if ((this.backup_running==SystemStatus.BACKING_UP)&&(this.basedir!=null)) {
            this.backup_forced=false;
            this.basedir.abort_backup();
        }
    }

    public void enter_clicked() {

        if (this.backend.available) {
            var list = this.backend.get_backup_list ();
            if ((list==null)||(list.size<=0)) {
                return;
            }
            this.restore_w=new restore_iface(this.backend,this.basepath,this.cronopete_settings);
        }
    }

    public void main_clicked() {

        if ((this.current_status==BackupStatus.WARNING)||(this.current_status==BackupStatus.ERROR)) {
            this.main_menu.show_main(true,this.messages.str);
        } else {
            this.main_menu.show_main(false,this.messages.str);
        }
    }

    public void backup_folder(string dirpath) {

        var msg = _("Backing up folder %s\n").printf(dirpath);
        this.set_tooltip(msg,true);
        //this.show_message(msg);
    }

    public void backup_file(string filepath) {
        //GLib.stdout.printf("Backing up file %s\n",filepath);
    }

    public void backup_link_file(string filepath) {
        //GLib.stdout.printf("Linking file %s\n",filepath);
    }

    public void warning_link_file(string o_filepath) {
        //GLib.stdout.printf("Can't link file %s to %s\n",o_filepath,d_filepath);
    }

    public void error_copy_file(string filepath) {
        this.current_status=BackupStatus.WARNING;
        this.show_message(_("Can't copy file %s\n").printf(filepath));
    }

    public void error_access_directory(string dirpath) {
        this.current_status=BackupStatus.WARNING;
        this.show_message(_("Can't access directory %s\n").printf(dirpath));
    }

    public void error_create_directory(string dirpath) {
        this.current_status=BackupStatus.WARNING;
        this.show_message(_("Can't create directory %s\n").printf(dirpath));
    }

    public void excluding_folder(string dirpath) {
        //GLib.stdout.printf("Excluding folder %s\n",dirpath);
    }

    public void show_message(string msg) {

        this.messages.append(msg);
        this.main_menu.insert_log(msg,false);
    }

    private void* do_backup() {

        int retval;

        this.basedir = new nanockup(this,this.backend);

        this.messages = new StringBuilder(_("Starting backup\n"));
        this.main_menu.insert_log(this.messages.str,true);

        this.current_status=BackupStatus.ALLFINE;

        string[] folders=this.cronopete_settings.get_strv("backup-folders");
        if (folders.length==0) {
            folders={};
            folders+=GLib.Environment.get_home_dir();
        }

        basedir.set_config( folders,
                            this.cronopete_settings.get_strv("exclude-folders"),
                            this.cronopete_settings.get_boolean("skip-hiden-at-home"));

        this.set_tooltip(_("Erasing old backups"));
        this.basedir.delete_old_backups();

        retval=basedir.do_backup();
        this.backup_running=SystemStatus.ENDED;
        switch (retval) {
        case 0:
        break;
        case -1:
            this.current_status=BackupStatus.WARNING;
        break;
        case -6:
            this.set_tooltip (_("Backup aborted"));
            this.current_status=BackupStatus.ERROR;
        break;
        case -7:
            this.set_tooltip (_("Can't do backup; disk is too small"));
            this.current_status=BackupStatus.ERROR;
        break;
        default:
            this.set_tooltip (_("Can't do backup"));
            this.current_status=BackupStatus.ERROR;
        break;
        }
        this.basedir=null;
        return null;
    }

    private int read_configuration() {

        /****************************************************************************************
         * This function will read the configuration from the file ~/.cronopete.cfg             *
         * and migrate it to GSettings
         ****************************************************************************************/

        /*this.origin_path_list = new Gee.ArrayList<string>();
        this.exclude_path_list = new Gee.ArrayList<string>();
        this.backup_path = "";
        this.skip_hiden_at_home = true;
        this._active = false;
        this._show_in_bar=true;
        this.new_period=3600;*/

        FileInputStream file_read;

        string home=Environment.get_home_dir();
        var config_file = File.new_for_path (GLib.Path.build_filename(home,".cronopete.cfg"));

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

        string[] origin_path_list ={};
        string[] exclude_path_list = {};
        string backup_path2 = "";
        bool skip_hiden_at_home = true;
        uint new_period=3600;

        bool failed=false;
        bool is_activated=false;

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
                origin_path_list+=(line.substring(14).strip());
                continue;
            }

            if (line.has_prefix("exclude_directory ")) {
                exclude_path_list+=(line.substring(18).strip());
                continue;
            }

            if (line.has_prefix("backup_directory ")) {
                backup_path2=line.substring(17).strip();
                continue;
            }

            if (line=="backup_hiden_at_home") {
                skip_hiden_at_home=false;
                continue;
            }

            if (line.has_prefix("backup_period ")) {
                new_period=int.parse(line.substring(14).strip());
                continue;
            }

            if (line=="active") {
                is_activated=true;
                continue;
            }
            if (line=="no_show_in_bar") {
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
            GLib.stderr.printf(_("Invalid parameter in config file %s (line %d)\n"),config_file.get_path(),line_counter);
            return line_counter;
        }

        this.cronopete_settings.set_string("backup-path",backup_path2);
        if (origin_path_list.length==0) {
            origin_path_list+=Environment.get_home_dir();
        }
        this.cronopete_settings.set_strv("backup-folders",origin_path_list);
        this.cronopete_settings.set_strv("exclude-folders",exclude_path_list);
        this.cronopete_settings.set_boolean("skip-hiden-at-home",skip_hiden_at_home);
        this.cronopete_settings.set_uint("backup-period",new_period);
        this.cronopete_settings.set_boolean("enabled",is_activated);
        in_stream=null;
        file_read=null;
        config_file.delete();

        return 0;
    }

    public void get_backup_data(out string id, out time_t oldest, out time_t newest, out time_t next, out uint64 total_space, out uint64 free_space) {


        this.fill_last_backup();

        this.backend.get_free_space(out total_space,out free_space);

        id = this.backend.get_backup_id();

        oldest=0;
        newest=0;
        next=0;

        var list_backup = this.backend.get_backup_list();
        if (list_backup == null) {
            oldest=0;
            newest=0;
            next=0;
            return;
        }

        if (list_backup==null) {
            return;
        }

        foreach(time_t v in list_backup) {
            if ((oldest==0) || (oldest>v)) {
                oldest=v;
            }
            if ((newest==0) || (newest<v)) {
                newest=v;
            }
        }
        if (this._active) {
            next=this.next_backup;
        } else {
            next=0;
        }
    }

}

void on_bus_aquired (DBusConnection conn) {
    try {
        conn.register_object ("/com/rastersoft/cronopete", new DetectServer ());
    } catch (IOError e) {
        GLib.stderr.printf ("Could not register service\n");
    }
}

int main(string[] args) {

    // try to connect to the bus

    nice(19); // Minimum priority
    string basepath=Constants.PKGDATADIR;

    Intl.bindtextdomain(Constants.GETTEXT_PACKAGE, GLib.Path.build_filename(Constants.DATADIR,"locale"));

    //Intl.setlocale (LocaleCategory.ALL, "");
    Intl.textdomain("cronopete");
    Intl.bind_textdomain_codeset("cronopete", "UTF-8" );

    Gtk.init(ref args);

    callback_object = new cp_callback(basepath);
    Bus.own_name (BusType.SESSION, "com.rastersoft.cronopete", BusNameOwnerFlags.NONE, on_bus_aquired, () => {}, () => {
        GLib.stderr.printf ("Cronopete is already running\n");
        Posix.exit(1);
    });

    callback_object.check_welcome();
    Gtk.main();

    return 0;
}

[DBus (name = "com.rastersoft.cronopete")]
public class DetectServer : GLib.Object {

    public int do_ping(int v) {
        return (v+1);
    }

    public void do_backup() {
        callback_object.backup_now();
    }

    public void stop_backup() {
        callback_object.stop_backup();
    }

    public void show_preferences() {
        callback_object.main_clicked ();
    }

    public void restore_files() {
        callback_object.enter_clicked ();
    }
}
