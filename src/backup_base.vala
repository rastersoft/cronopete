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

public abstract class backup_base : GLib.Object {

	public signal void is_available(bool available);

	protected GLib.Settings cronopete_settings;

	public abstract void do_backup();
	public abstract backup_element[] get_backup_list();
	public abstract bool storage_is_available();

	public backup_base() {
		this.cronopete_settings = new GLib.Settings("org.rastersoft.cronopete");
	}

}

public class backup_element : GLib.Object {
	
}
