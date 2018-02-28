/*
 * Copyright 2011-2018 (C) Raster Software Vigo (Sergio Costas)
 *
 * This file is part of Cronopete
 *
 * Nanockup is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * Nanockup is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>. */

using GLib;
using Gee;
using Gtk;
using Gdk;
using Cairo;

namespace cronopete {
public class restore_iface : Gtk.Window {
    private backup_base backend;
    Gee.List<backup_element> ? backup_list;

    private RestoreCanvas restore_canvas;
    private Gtk.Label current_date;
    private Gtk.SizeGroup sizegroup;
    private int screen_w;
    private int screen_h;

    private GLib.Settings cronopete_settings;

    public static int mysort_64(backup_element ? a, backup_element ? b) {
        if (a.utc_time < b.utc_time) {
            return 1;
        }
        if (a.utc_time > b.utc_time) {
            return -1;
        }
        return 0;
    }

    public restore_iface(backup_base current_backend) {
        Object(type: Gtk.WindowType.TOPLEVEL);

        this.cronopete_settings = new GLib.Settings("org.rastersoft.cronopete");

        this.backend = current_backend;
        time_t oldest, newest;
        this.backup_list = this.backend.get_backup_list(out oldest, out newest);
        this.backup_list.sort(mysort_64);

        // Create the RESTORE button
        var pic1   = new Gtk.Image.from_icon_name("document-revert", Gtk.IconSize.DND);
        var label1 = new Label("<span size=\"xx-large\">" + _("Restore files") + "</span>");
        label1.use_markup = true;
        var container1 = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        container1.halign = Gtk.Align.CENTER;
        container1.pack_start(pic1, false, false, 0);
        container1.pack_start(label1, false, false, 0);
        var restore_button = new Gtk.Button();
        restore_button.add(container1);
        restore_button.clicked.connect(this.do_restore);

        // Create the EXIT button
        var pic2   = new Gtk.Image.from_icon_name("application-exit", Gtk.IconSize.DND);
        var label2 = new Label("<span size=\"xx-large\">" + _("Exit") + "</span>");
        label2.use_markup = true;
        var container2 = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        container2.halign = Gtk.Align.CENTER;
        container2.pack_start(pic2, false, false, 0);
        container2.pack_start(label2, false, false, 0);
        var quit_button = new Gtk.Button();
        quit_button.add(container2);
        quit_button.clicked.connect(this.exit_restore);

        // Make a sizegroup to make both buttons have the same width
        this.sizegroup = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
        sizegroup.add_widget(restore_button);
        sizegroup.add_widget(quit_button);

        // current_date is a label that will contain the current date and time
        // of the backup being displayed
        this.current_date            = new Label("<span size=\"xx-large\"> </span>");
        this.current_date.use_markup = true;

        // button_box will contain the buttons and the current date
        var button_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        button_box.pack_start(restore_button, false, false, 0);
        button_box.pack_start(this.current_date, true, true, 0);
        button_box.pack_start(quit_button, false, false, 0);

        // main_box will contain all the widgets
        var main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        main_box.pack_start(button_box, false, true, 0);
        main_box.pack_start(restore_canvas, true, true, 0);

        this.add(main_box);
        this.size_allocate.connect(this.size_changed);
        this.draw.connect(this.do_draw);
        this.fullscreen();
        this.show_all();
    }

    private void size_changed(Allocation allocation) {
        if ((this.screen_w != allocation.width) || (this.screen_h != allocation.height)) {
            this.screen_w = allocation.width;
            this.screen_h = allocation.height;
        }
    }

    private bool do_draw(Context cr) {
        print("Repinto\n");
        return false;
    }

    private void do_restore() {
    }

    private void exit_restore() {
        this.hide();
        this.destroy();
    }

    private bool on_scroll(Gtk.Widget widget, Gdk.EventScroll event) {
        return false;
    }
    private bool on_click(Gtk.Widget widget, Gdk.EventButton event) {
        return false;
    }
    private bool on_key_press(Gtk.Widget widget, Gdk.EventKey event) {
        return false;
    }
    private bool on_key_release(Gtk.Widget widget, Gdk.EventKey event) {
        return false;
    }
}
}
