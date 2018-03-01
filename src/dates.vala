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
	string date_to_string(time_t datetime) {
		if (datetime == 0) {
			/* "Not available" refers to a backup (e.g. when the disk is not connected) */
			return _("Not available");
		}

		var last_backup = GLib.Time.local(datetime);
		var now         = time_t();
		var today       = GLib.Time.local(now);
		// 60 * 60 * 24 = 86400 seconds / day
		var yesterday   = GLib.Time.local(now - 86400);
		var tomorrow    = GLib.Time.local(now + 86400);

		if ((last_backup.day == today.day) && (last_backup.month == today.month) && (last_backup.year == today.year)) {
			// %R is a backup's time
			return last_backup.format(_("today at %R"));
		}
		if ((last_backup.day == yesterday.day) && (last_backup.month == yesterday.month) && (last_backup.year == yesterday.year)) {
			// %R is a backup's time
			return last_backup.format(_("yesterday at %R"));
		}
		if ((last_backup.day == tomorrow.day) && (last_backup.month == tomorrow.month) && (last_backup.year == tomorrow.year)) {
			// %R is a backup's time
			return last_backup.format(_("tomorrow at %R"));
		} else {
			// %x is a backup's date, and %R a backup's time
			return last_backup.format("%x at %R");
		}
	}
}
