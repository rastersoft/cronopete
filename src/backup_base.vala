/*
 * Copyright 2018 (C) Raster Software Vigo (Sergio Costas)
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

namespace cronopete {
/**
 * These are the possible statuses:
 * IDLE: no action is being performed
 * RUNNING: a backup is being made
 * SYNCING: the backup has been done and the system is syncing the disks
 * CLEANING: the system is removing old backups
 */

public enum backup_current_status { IDLE, RUNNING, SYNCING, CLEANING }

public abstract class backup_base : GLib.Object {
    /**
     * This signal is emitted every time the availability of the
     * storage changes
     */
    public signal void is_available_changed(bool available);

    /**
     * This signal is emitted every time the status of the backup
     * changes.
     */
    public signal void current_status_changed(backup_current_status status);

    /**
     * This signal is emitted every time a message must be sent to
     * the parent.
     */
    public signal void send_message(string message);

    /**
     * This signal is emitted every time a warning message must be sent to
     * the parent.
     */
    public signal void send_warning(string warning_msg);

    /**
     * This signal is emitted every time an error message must be sent to
     * the parent.
     */
    public signal void send_error(string error_msg);

    /**
     * This signal is emitted every time a debug message must be sent to
     * the parent.
     */
    public signal void send_debug(string debug_msg);

    /**
     * This signal is emitted every time a new file is being backed up, or an action is being done
     */
    public signal void send_current_action(string full_path);

    /**
     * Allows to get or set the current status
     */
    public backup_current_status current_status {
        get {
            return this._current_status;
        }
        set {
            this._current_status = value;
            this.current_status_changed(value);
            if (current_status == backup_current_status.IDLE) {
                this.send_current_action(_("Ready"));
            }
        }
    }

    protected GLib.Settings cronopete_settings;
    protected backup_current_status _current_status;

    /**
     * Returns the time of the last backup
     * @return the UTC instant of the last backup
     */
    public abstract time_t get_last_backup();

    /**
     * Creates a new backup.
     * @param folder_list A list with all the folders to backup
     * @param exclude_list A list with the folders to exclude from the backup
     * @param skip_hidden_at_home If TRUE, and the HOME directory is to be backed up, the hidden folders
     * in the HOME will be excluded. If FALSE, they will be backed up.
     * @return TRUE if the backup started fine; FALSE if there was an error
     */
    public abstract bool do_backup(string[] folder_list, string[] exclude_list, bool skip_hidden_at_home);

    /**
     * Aborts the current backup, and ensures that the half-made backup
     * is not a problem
     */
    public abstract void abort_backup();

    /**
     * Returns a list of all complete backups available in the storage
     * @param oldest A variable where to store the oldest backup available in the device
     * @param newest A variable where to store the newest backup available in the device
     * @return a list of backup elements, or null if the list couldn't be created
     */
    public abstract Gee.List<backup_element> ? get_backup_list(out time_t oldest, out time_t newest);

    /**
     * Returns wether the storage is available or not (e.g. a hard disk is connected to the PC,
     * a remote server is available using networking...)
     * @return TRUE if it is available; FALSE if it is not
     */
    public abstract bool storage_is_available();

    /**
     * Allows to obtain data about the storage device
     * @param id An ID for this device. For a hard disk, the UUID is a good id.
     * @param oldest The UTC time for the oldest backup available
     * @param newest The UTC time for the newest backup available
     * @param next The UTC time when the next backup will be made
     * @param total_space The total disk size in bytes, or 0 if unknown
     * @param free_space The free space in the disk, or 0 if unknown
     * @param icon An icon name to represent this backup devide, or null for no icon
     * @return TRUE if the storage is available; FALSE if not
     */
    public abstract bool get_backup_data(out string ? id, out time_t oldest, out time_t newest, out uint64 total_space, out uint64 free_space, out string ? icon);


    /**
     * Shows and runs a Dialog to configure the disk where to do the backups
     * @param main_window The main window, to make any new window its sibling
     * @return TRUE if the disk has been chosen; FALSE if the disk has not been changed
     */
    public abstract bool configure_backup_device(Gtk.Window main_window);

    /**
     * Returns a list with all the current backups, and will set the "keep" property as TRUE if
     * that backup must be kept, or will set it to FALSE if it must be deleted to reclaim its
     * disk space. The list will contain objects created with the backend's method "get_backup_list",
     * so it can contain extra data if the objects are children of backup_element.
     *
     * It follows these rules:
     * - keep all the backups made in the last 24 hours
     * - keep a daily backup made in the last month
     * - keep a weekly backup for every other cases
     *
     * @param free_space If TRUE, if there are no old backups marked to be deleted after following
     * the previous rules, it will delete the oldest backup (this is used when there is no free
     * space when doing a backup); if FALSE, it will only delete the backups that don't follow the
     * rules.
     *
     * @return A list of backup_elements with the "keep" property specifying if each backup must
     * be kept or must be deleted.
     */
    protected Gee.List<backup_element> ? eval_backups_to_delete(bool free_space, out bool forcing_deletion) {
        forcing_deletion = false;
        time_t oldest;
        time_t newest;
        var    backups = this.get_backup_list(out oldest, out newest);
        if (backups == null) {
            return null;
        }
        time_t now_t = time_t();

        /*
         *      // Test for the code
         * backups = new Gee.ArrayList<backup_element?>();
         * var rnd = new GLib.Rand();
         * for(int i=0;i<4000;i++) {
         *      var tiempo = (3600 * i) + rnd.int_range(0,500);
         *      var f = new FileInfo();
         *      f.set_name(this.date_to_folder_name(tiempo));
         *      backups.add(new rsync_element(tiempo,"",f));
         * }
         * now_t = 4000 * 3600;
         */

        // Some constants
        time_t day_duration   = 60 * 60 * 24;
        time_t week_duration  = day_duration * 7;
        time_t month_duration = day_duration * 30;                 // use 30-day months

        // time interval to keep all backups
        time_t day = now_t - day_duration;
        // time interval to keep a daily backup
        time_t month = now_t - month_duration;

        // temporary list where to store the backups to keep
        Gee.List<backup_element ?> to_keep = new Gee.ArrayList<backup_element ?>();
        foreach (var backup in backups) {
            backup.keep = false;
            if (backup.utc_time >= day) {
                // this backup belongs to the last 24 hours
                // so keep it unconditionally
                to_keep.add(backup);
                backup.keep = true;
                continue;
            }
            time_t duration;
            if (backup.utc_time >= month) {
                duration = day_duration;
            } else {
                duration = week_duration;
            }
            var interval = backup.utc_time / duration;
            backup_element ? found = null;
            // check if there is already a backup in that day/week
            foreach (var b in to_keep) {
                if (b.utc_time / duration == interval) {
                    found = b;
                    break;
                }
            }
            if (found == null) {
                // if in that day/week there are no backups, add this one
                to_keep.add(backup);
                backup.keep = true;
                continue;
            } else {
                int64 distance1 = ((backup.utc_time % duration) - (duration / 2));
                int64 distance2 = ((found.utc_time % duration) - (duration / 2));
                distance1 = distance1.abs();
                distance2 = distance2.abs();
                if (distance1 < distance2) {
                    // the new backup is nearer the center of the interval than the old one, so
                    // replace the old with the new
                    to_keep.remove(found);
                    to_keep.add(backup);
                    backup.keep = true;
                    found.keep  = false;
                }
            }
        }

        /* if there are no old backups to remove, and FREE_SPACE is TRUE,
         * we need to free space for the current backup
         */
        if (free_space) {
            bool there_are_to_remove = false;
            backup_element ? oldest_element = null;
            foreach (var b in backups) {
                if (b.keep == false) {
                    there_are_to_remove = true;
                }
                if (oldest_element == null) {
                    oldest_element = b;
                    continue;
                }
                if (b.utc_time < oldest_element.utc_time) {
                    oldest_element = b;
                }
            }

            /* If we need to free space, but no backups are being deleted when
             * using the backup keeping rules (all from last 24 hours, daily for
             * the last 15 days, weekely for the others), mark the oldest one for deletion
             */
            if ((there_are_to_remove == false) && (oldest_element != null)) {
                oldest_element.keep = false;
                forcing_deletion    = true;                      // specify that we are deleting the last one
            }
        }
        return backups;
    }

    public backup_base() {
        this.cronopete_settings = new GLib.Settings("org.rastersoft.cronopete2");
    }
}

public abstract class backup_element : GLib.Object {
    public time_t utc_time;
    public GLib.Time local_time;
    // used in eval_backups_to_delete to specify if this backup must be kept or
    // should be deleted to free space
    public bool keep;

    protected void set_common_data(time_t t) {
        this.utc_time   = t;
        this.local_time = GLib.Time.local(t);
        this.keep       = true;
    }
}

public int sort_backup_elements_older_to_newer(backup_element a, backup_element b) {
    if (a.utc_time < b.utc_time) {
        return -1;
    }
    if (a.utc_time > b.utc_time) {
        return 1;
    }
    return 0;
}

public int sort_backup_elements_newer_to_older(backup_element a, backup_element b) {
    if (a.utc_time < b.utc_time) {
        return 1;
    }
    if (a.utc_time > b.utc_time) {
        return -1;
    }
    return 0;
}
}
