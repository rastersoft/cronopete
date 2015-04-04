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
using Posix;
using Gee;

interface callbacks : GLib.Object {

    public abstract void backup_folder(string foldername);
    public abstract void backup_file(string filename);
    public abstract void backup_link_file(string filename);
    public abstract void warning_link_file(string filename);
    public abstract void error_copy_file(string filename);
    public abstract void error_access_directory(string directory);
    public abstract void error_create_directory(string directory);
    public abstract void excluding_folder(string dirpath);
    public abstract void show_message(string msg);

}

enum BACKUP_RETVAL { OK, CANT_COPY, CANT_LINK, NO_STARTED, CANT_CREATE_FOLDER, ALREADY_STARTED,
    NOT_AVAILABLE, NOT_WRITABLE, NO_SPC, CANT_CREATE_BASE, NOT_EXISTS, IN_PROCCESS, ERROR, ABORTED }

interface backends : GLib.Object {

    public abstract string? get_backup_id();
    public abstract Gee.List<time_t?>? get_backup_list();
    public abstract bool delete_backup(time_t backup_date);
    public abstract BACKUP_RETVAL start_backup(out int64 last_backup_time);
    public abstract BACKUP_RETVAL end_backup();
    public abstract BACKUP_RETVAL create_folder(string path, time_t mod_time);
    public abstract BACKUP_RETVAL copy_file(string path, time_t mod_time);
    public abstract BACKUP_RETVAL link_file(string path, time_t mod_time);
    public abstract BACKUP_RETVAL set_modtime(string path, time_t mod_time);
    public abstract BACKUP_RETVAL abort_backup();
    public abstract bool get_free_space(out uint64 total_space, out uint64 free_space);

    public abstract bool available {get;}
    public abstract string? get_uuid {get;}
    public abstract string? get_path {get;}
    public signal void status(usbhd_backend b);

    public abstract bool get_filelist(string current_path, time_t backup, out Gee.List<file_info ?> files, out string date);

    public abstract async BACKUP_RETVAL restore_file(string filename,time_t backup, string output_filename,FileProgressCallback? cb);
    public abstract void lock_delete_backup(bool lock_in);

    public signal void restore_ended(backends b, string file_ended, BACKUP_RETVAL status);
}

class path_node:Object {

    // Only the NEXT pointer uses reference count. That way we can
    // slightly improve performance and avoid circular lists

    public path_node? next;
    public weak path_node? prev;
    public string path;
    public time_t modified_time;

    public path_node(string path, time_t mtime) {
        this.path=path;
        this.modified_time=mtime;
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

    public string? next_iterator(out time_t mod_time) {

        // This method returns the next element in the list

        if (this.iterator==this.last) {
            mod_time=0;
            return null;
        }

        if (this.iterator==null) {
            this.iterator=this.first;
        } else{
            this.iterator=this.iterator.next;
        }

        mod_time=this.iterator.modified_time;
        return this.iterator.path;
    }

    public void add(string path, time_t mtime) {

        // Adds a node at the end of the list

        path_node new_node=new path_node(path,mtime);

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

    // Contains the time (in seconds from EPOCH) of the last backup
    private int64 last_backup_time;

    // Contains the paths to backup
    private path_list origin_path_list;

    // Contains the paths backed up, to set the modification time in folders
    private path_list done_backup;

    // Contains a list of directory paths which must NOT be backed up
    private Gee.HashSet<string> exclude_path_list;

    // If true, cronopete won't backup the hiden files or folders at the HOME directory
    private bool skip_hiden_at_HOME;

    public ulong time_used {get; set;}

    private callbacks callback;
    private backends backend;

    private bool abort;

    public void abort_backup() {

        this.abort = true;

    }

    public nanockup(callbacks to_callback,backends to_backend) {

        this.origin_path_list=new path_list();
        this.exclude_path_list =new Gee.HashSet<string>();
        this.callback=to_callback;
        this.backend=to_backend;

        // by default, don't backup hidden files or folders at HOME folder
        this.skip_hiden_at_HOME=true;
        this.last_backup_time=0;
        this.abort = false;

    }

    public static int mysort_64(time_t? a, time_t? b) {

        if(a>b) {
            return 1;
        }
        if(a<b) {
            return -1;
        }
        return 0;
    }

    public void delete_old_backups() {

        var lbacks=this.backend.get_backup_list();
        if (lbacks==null) {
            return;
        }

        lbacks.sort(mysort_64);

        var ctime=time_t();

        var day_limit=ctime-86400; // 24 hour period for hourly backups
        var week_limit=ctime-2678400; // 1 month (31 days) period for daily backups

        time_t divider=0;

        foreach (time_t v in lbacks) {
            if (v>day_limit) { // keep all backups for a day
                continue;
            }
            if (v>week_limit) {
                if ((v/86400)!=divider) { // keep a daily backup for the last month
                    divider=v/86400;
                } else {
                    this.backend.delete_backup(v);
                }
                continue;
            }
            if ((v/604800)!=divider) { // keep a weekly backup for backups older than a month
                divider=v/604800;
            } else {
                this.backend.delete_backup(v);
            }
        }
    }

    public void set_config(string[] origin_path,string[] exclude_path, bool skip_h_at_h) {

        this.origin_path_list=new path_list();
        this.exclude_path_list=new Gee.HashSet<string>();

        foreach (string tmp in origin_path) {
            this.callback.show_message(_("Backing up folder %s.\n").printf(tmp));
            this.origin_path_list.add(tmp,0);
        }
        foreach (string tmp in exclude_path) {
            this.callback.show_message(_("Excluding folder %s.\n").printf(tmp));
            this.exclude_path_list.add(tmp);
        }
        this.skip_hiden_at_HOME=skip_h_at_h;
        string homedir=GLib.Environment.get_home_dir();
        if (this.skip_hiden_at_HOME) {
            this.callback.show_message(_("Excluding hidden folders in %s.\n").printf(homedir));
        } else {
            this.callback.show_message(_("Backing up hidden folders in %s.\n").printf(homedir));
        }


        // Never back up the .gvfs folder
        string exclude_this_path=Path.build_filename(Environment.get_home_dir(),".gvfs");
        if (false==this.exclude_path_list.contains(exclude_this_path)) {
            this.exclude_path_list.add(exclude_this_path);
        }
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
         *    -6: backup aborted                                                                              *
         *    -7: there's not enought disk space to do just one backup                                        *
         ******************************************************************************************************/

        int retval,tmp;
        string? directory=null;
        time_t mod_time;

        this.abort=false;

        int do_loop=0;

        this.done_backup=new path_list();

        if (this.backend.get_backup_id()==null) { // system not configured
            this.callback.show_message("User didn't specified a device where to store the backups. Aborting backup.\n");
            return -2; // the class isn't configured (don't know where to store the backups)
        }

        this.free_bytes(1000000);
        while(do_loop<2) {
            var rv=this.backend.start_backup(out this.last_backup_time);
            switch (rv) {
                case BACKUP_RETVAL.NOT_WRITABLE:
                    this.callback.show_message(_("Can't create the folder for this backup. Aborting backup.\n"));
                    return -3;
                case BACKUP_RETVAL.CANT_CREATE_BASE:
                    this.callback.show_message(_("Can't create the base folders to do backups. Aborting backup.\n"));
                    return -3;
                case BACKUP_RETVAL.NOT_AVAILABLE:
                    this.callback.show_message(_("Backup device not available. Aborting backup.\n"));
                    return -3;
                case BACKUP_RETVAL.ALREADY_STARTED:
                    this.callback.show_message(_("Already started a backup.\n"));
                    return -3;
                case BACKUP_RETVAL.NO_SPC:
                    if ((do_loop!=0)||(false==this.free_bytes(1000000))) {
                        this.callback.show_message(_("Failed to free disk space to start a backup. Aborting backup.\n"));
                        return 3;
                    }
                    do_loop++;
                break;
                case BACKUP_RETVAL.OK:
                    do_loop=2;
                break;
            }
        }

        var timestamp=time_t();

        retval=0;

        // backup all the directories
        this.origin_path_list.start_iterator();
        while (null!=(directory=this.origin_path_list.next_iterator(out mod_time))) {
            if (this.abort) {
                this.callback.show_message(_("Backup aborted\n"));
                this.backend.abort_backup();
                if (retval==-7) {
                    return retval;
                } else {
                    return -6;
                }
            }
            this.callback.backup_folder(directory);
            tmp=this.copy_dir(directory,mod_time);
            switch (tmp) {
            case 0:
            break;
            case -3:
                this.callback.show_message(_("The disk is too small to hold a single backup.\nAdjust the list of backup and exclude folders.\n"));
                retval=-7;
            break;
            default:
                retval=-1;
            break;
            }
        }

        this.done_backup.start_iterator();
        while (null!=(directory=this.done_backup.next_iterator(out mod_time))) {
            this.backend.set_modtime(directory,mod_time);
        }

        this.callback.show_message(_("Syncing disk\n"));
        if (this.backend.end_backup()!=BACKUP_RETVAL.OK) {
            this.callback.show_message(_("Can't close the backup. Aborting.\n"));
            return -5;
        }

        var timestamp2=time_t();
        this.time_used=(ulong)timestamp2-timestamp;
        this.callback.show_message(_("Backup done. Needed %ld seconds.\n").printf((long)this.time_used));
        return retval;
    }


    int copy_dir(string first_path,time_t dirmod_time) {

        /*****************************************************************************************************
         * This method takes the first directory in the list and copies the files in it to the destination   *
         * adding the new directories found to the list too, in order to allow to, in a future, add          *
         * support for using gamin library to track the modified files and backup only the ones that changed *
         * Returns:                                                                                          *
         *      0: if successful                                                                             *
         *     -1: if there were errors during the backup of this folder                                     *
         *     -2: if it was aborted                                                                         *
         *     -3: if it can't free the needed space to complete a backup                                    *
         *****************************************************************************************************/

        FileInfo info_file;
        TimeVal mod_time;
        FileEnumerator enumerator;
        string full_path;
        string initial_path;
        FileType typeinfo;
        int verror,retval;
        BACKUP_RETVAL rv;

        initial_path=first_path;
        var directory = File.new_for_path(initial_path);

        retval=0;

        if ((this.backend.create_folder(first_path,dirmod_time))==BACKUP_RETVAL.CANT_CREATE_FOLDER) {
            this.callback.error_create_directory(first_path);
            return -1;
        }

        this.done_backup.add(first_path,dirmod_time);

        try {
             enumerator = directory.enumerate_children(FileAttribute.TIME_MODIFIED+","+FileAttribute.STANDARD_NAME+","+FileAttribute.STANDARD_TYPE+","+FileAttribute.STANDARD_SIZE,FileQueryInfoFlags.NOFOLLOW_SYMLINKS,null);
        } catch (Error e) {
            this.callback.error_access_directory(initial_path);
            return -1;
        }

        while ((info_file = enumerator.next_file(null)) != null) {

            if (this.abort) {
                if (retval==-3) {
                    return -3;
                } else {
                    return -2;
                }
            }

            full_path=Path.build_filename(first_path,info_file.get_name());
            typeinfo=info_file.get_file_type();

            mod_time=info_file.get_modification_time();

            // Add the directories to the list, to continue deep in the directory tree
            if (typeinfo==FileType.DIRECTORY) {
                // Don't backup hidden folders if the user doesn't want
                if ((info_file.get_name()[0]=='.') && (this.skip_hiden_at_HOME) &&
                        (first_path==Environment.get_home_dir())) {
                    this.callback.excluding_folder(full_path);
                    continue;
                }

                if (this.exclude_path_list.contains(full_path)) {
                    this.callback.excluding_folder(full_path);
                    continue;
                }

                this.origin_path_list.add(full_path,mod_time.tv_sec);
                continue;
            }

            if (typeinfo==FileType.REGULAR) {
                // Don't backup hidden files if the user doesn't want
                if ((info_file.get_name()[0]=='.') && (this.skip_hiden_at_HOME) && (first_path==Environment.get_home_dir())) {
                    continue;
                }

                // If the modification time is before the last backup time, just link; if not, copy to the directory
                if (mod_time.tv_sec < ((long)this.last_backup_time)) {
                    this.callback.backup_link_file(full_path);
                    rv = this.backend.link_file(full_path,mod_time.tv_sec);
                    switch (rv) {
                    case BACKUP_RETVAL.CANT_LINK:
                        verror=-1;
                    break;
                    case BACKUP_RETVAL.OK:
                        verror=0;
                    break;
                    case BACKUP_RETVAL.NO_SPC:
                        if (false==this.free_bytes(1000000)) {
                            verror=-3;
                        }
                        if (this.backend.link_file(full_path,mod_time.tv_sec)==BACKUP_RETVAL.OK) {
                            verror=0;
                        } else {
                            verror=1;
                        }
                    break;
                    default:
                        verror=1;
                    break;
                    }
                    if (verror!=0) {
                        this.callback.warning_link_file(Path.build_filename(full_path));
                    }
                } else {
                    verror=1; // assign a false error to force a copy
                }
                // If the file modification time is bigger than the last backup time, or the link failed, we must copy the file
                if (verror!=0) {
                    this.callback.backup_file(full_path);
                    rv = this.backend.copy_file(full_path,mod_time.tv_sec);
                    switch (rv) {
                    case BACKUP_RETVAL.CANT_COPY:
                        this.callback.error_copy_file(full_path);
                        retval=-1;
                    break;
                    case BACKUP_RETVAL.NO_SPC:
                        if (false==this.free_bytes(1000000+info_file.get_size())) {
                            retval=-3;
                        }
                        int rv2;
                        rv2 = this.backend.copy_file(full_path,mod_time.tv_sec);
                        if (rv2==BACKUP_RETVAL.NO_SPC) {
                            this.abort=true;
                            retval=-3;
                        } else if (rv2!=BACKUP_RETVAL.OK) {
                            retval=-1;
                        }
                    break;
                    }
                }
            }
        }
        return (retval);
    }

    public bool free_bytes(uint64 d_size) {

        uint64 c_size;
        uint64 t_size;

        if (false==this.backend.get_free_space(out t_size,out c_size)) {
            return false;
        }
        if (c_size>=d_size) {
            return true;
        }

        var blist = this.backend.get_backup_list();
        if (blist==null) {
            return false;
        }

        blist.sort(mysort_64);

        time_t entry;
        while(c_size<=d_size) {
            if (blist.size==0) {
                return false;
            }
            entry = blist.remove_at(0);
            GLib.stdout.printf("Need to free up to %lld; currently there are %lld bytes free; erasing backup %lld\n",d_size,c_size,entry);
            this.backend.delete_backup(entry);
            if (false==this.backend.get_free_space(out t_size,out c_size)) {
                return false;
            }
        }
        return true;
    }

}
