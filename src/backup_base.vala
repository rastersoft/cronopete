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

public enum backup_current_status {IDLE, RUNNING}

public abstract class backup_base : GLib.Object {

	/**
	 * This signal is emitted every time the availability of the
	 * storage changes
	 */
	public signal void is_available_changed(bool available);

	/**
	 * This signal is emitted every time the status of the backup
	 * changes
	 */
	 public signal void current_status_changed(backup_current_status status);

	protected GLib.Settings cronopete_settings;
	protected backup_current_status _current_status;

	public backup_current_status current_status {
		get {
			return this._current_status;
		}
		set {
			this._current_status = value;
			this.current_status_changed(value);
		}
	}

	/**
	 * Creates a new backup.
	 * @return TRUE if the backup started fine; FALSE if there was an error
	 */
	public abstract bool do_backup();

	/**
	 * Returns a list of all complete backups available in the storage
	 * @return a list of backup elements, or null if the list couldn't be created
	 */
	public abstract Gee.List<backup_element>? get_backup_list();
	/**
	 * Returns wether the storage is available or not (e.g. a hard disk is connected to the PC,
	 * a remote server is available using networking...)
	 * @return TRUE if it is available; FALSE if it is not
	 */
	public abstract bool storage_is_available();

	public backup_base() {
		this.cronopete_settings = new GLib.Settings("org.rastersoft.cronopete");
	}

}

public abstract class backup_element : GLib.Object {
	public time_t utc_time;
	public GLib.Time local_time;

	protected void set_common_data(time_t t) {
		this.utc_time = t;
		this.local_time = GLib.Time.local(t);
	}
}
