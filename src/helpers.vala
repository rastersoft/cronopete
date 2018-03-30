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
			// TRANSLATORS "Not available" refers to a backup (e.g. when the disk is not connected, the backups are not available)
			return _("Not available");
		}

		var last_backup = new GLib.DateTime.from_unix_local(datetime);
		var lb_day      = last_backup.get_day_of_month();
		var lb_month    = last_backup.get_month();
		var lb_year     = last_backup.get_year();
		var now         = time_t();
		var today       = new GLib.DateTime.from_unix_local(now);
		var yesterday   = new GLib.DateTime.from_unix_local(now - 86400);
		var tomorrow    = new GLib.DateTime.from_unix_local(now + 86400);
		// 60 * 60 * 24 = 86400 seconds / day

		if ((lb_day == today.get_day_of_month()) && (lb_month == today.get_month()) && (lb_year == today.get_year())) {
			/// TRANSLATORS This is used when showing the date of a backup done today. %R is the time when the backup was done
			return last_backup.format(_("today at %R"));
		}
		if ((lb_day == yesterday.get_day_of_month()) && (lb_month == yesterday.get_month()) && (lb_year == yesterday.get_year())) {
			/// TRANSLATORS This is used when showing the date of a backup done yesterday. %R is the time when the backup was done
			return last_backup.format(_("yesterday at %R"));
		}
		if ((lb_day == tomorrow.get_day_of_month()) && (lb_month == tomorrow.get_month()) && (lb_year == tomorrow.get_year())) {
			/// TRANSLATORS This is used when showing the date of a backup done tomorrow (just in case). %R is the time when the backup was done
			return last_backup.format(_("tomorrow at %R"));
		} else {
			/// TRANSLATORS This is used when showing the date of a backup not done today, yesterday nor tomorrow. You can use all the tags in strptime. Adjust the format to the one used in the corresponding country. %B is the month in text format, %e the day in numeric format, %Y is the year in four-digits format, %R is the hour and minute. Results in a text which is like "March 23, 2018 at 18:43". Example of translation for spanish: "%e de %B de %Y a las %R", which gives "23 de marzo de 2018 a las 18:43"
			return last_backup.format(_("%B %e, %Y at %R"));
		}
	}

	private struct folder_container {
		public string   folder;
		public string[] exclude;
		public bool     valid;

		public folder_container(string folder, string[] exclude_list, bool skip_hidden_at_home) {
			this.valid = true;
			if (!folder.has_suffix("/")) {
				this.folder = folder + "/";
			} else {
				this.folder = folder;
			}
			this.exclude = {};
			foreach (var x in exclude_list) {
				if (!x.has_suffix("/")) {
					x = x + "/";
				}
				if (x == this.folder) {
					valid = false;
					break;
				}
				if (x.has_prefix(this.folder)) {
					// "-1" to include the path separator before
					this.exclude += x.substring(this.folder.length - 1);
				}
			}
			// If this folder is the home folder, check if the hidden files/folders must be copied or not
			var home_folder = Path.build_filename("/home", Environment.get_user_name()) + "/";
			if ((this.folder == home_folder) && (skip_hidden_at_home)) {
				this.exclude += "/.*";
			}
		}
	}
}
