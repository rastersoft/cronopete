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
using Gee;
using Gtk;
using Gdk;

namespace FilelistIcons {

	struct FileInfo {
	
		string name;
		bool isdir;
		TimeVal mod_time;
		int64 size;
	
	}


	class IconBrowser : Frame {

		private VBox main_container;
		private HBox buttons_path;
		private ListStore path_model;
		private IconView path_view;
		private ScrolledWindow scroll;
		private Label main_title;
		private string current_path;
		private Gee.List<ToggleButton> path_list;
		private EventBox background_eb;
		private time_t current_backup;
		private backends backend;
	
		public IconBrowser(backends p_backend,string p_current_path) {
	
			this.backend=p_backend;
			this.current_path=p_current_path;
		
			this.main_container=new VBox(false,2);
			
			this.main_title=new Label("");
			this.main_container.pack_start(this.main_title,false,true,0);
			
			this.buttons_path=new HBox(false,0);
			this.buttons_path.homogeneous=false;
			this.main_container.pack_start(this.buttons_path,false,false,0);
		
			this.scroll = new ScrolledWindow(null,null);
			this.main_container.pack_start(this.scroll,true,true,0);
			this.scroll.hscrollbar_policy=PolicyType.AUTOMATIC;
			this.scroll.vscrollbar_policy=PolicyType.AUTOMATIC;

			/* path_model stores the data for each file/folder:
				 - file name (string)
				 - icon (string)
				 - is_folder (boolean)
			*/
			this.path_model=new ListStore(3,typeof(string),typeof(Pixbuf),typeof(bool));
			this.path_view=new IconView.with_model(this.path_model);
			this.path_view.columns=-1;
			this.path_view.set_pixbuf_column(1);
			this.path_view.set_text_column(0);
			this.path_view.selection_mode=SelectionMode.MULTIPLE;
			this.path_view.button_press_event.connect(this.selection_made);
			this.path_view.orientation=Orientation.VERTICAL;
			this.scroll.add_with_viewport(this.path_view);
			this.background_eb = new EventBox();
			this.background_eb.add(this.main_container);
			this.add(this.background_eb);

			this.path_view.item_width=175;
		
			this.path_list=new Gee.ArrayList<ToggleButton>();
		
			this.refresh_icons();
			this.refresh_path_list();
		
		}

		public void set_backup_time(time_t backup) {
			
			this.current_backup=backup;
			this.refresh_icons();
			
		}

		public bool selection_made(EventButton event) {
	
			if (event.type==EventType.2BUTTON_PRESS) {
		
				Gee.ArrayList<string> files;
				Gee.ArrayList<string> folders;
		
				get_selected_items(out files,out folders);
			
				if ((files.size!=0)||(folders.size!=1)) {
					return false;
				}
			
				var newfolder=folders.get(0);
			
				this.current_path=Path.build_filename(this.current_path,newfolder);
				this.refresh_icons();
				this.refresh_path_list();
				this.set_scroll_top();
			
			}
			return false;
		}

		public void get_selected_items(out Gee.ArrayList<string> files_selected, out Gee.ArrayList<string> folders_selected) {
	
			var selection = this.path_view.get_selected_items();
			TreeIter iter;
			var model = this.path_view.model;
			GLib.Value path;
			GLib.Value isfolder;

			files_selected = new Gee.ArrayList<string>();
			folders_selected = new Gee.ArrayList<string>();
	
			foreach (var v in selection) {

				model.get_iter(out iter,v);
				model.get_value(iter,2,out isfolder);
				model.get_value(iter,0,out path);
				if (isfolder.get_boolean()==true) {
					folders_selected.add(path.get_string());
				} else {
					files_selected.add(path.get_string());
				}
			}
		}

		private void refresh_path_list() {
	
			foreach (ToggleButton b in this.path_list) {
				b.destroy();
			}

			var btn = new ToggleButton.with_label("/");
			btn.show();
			btn.released.connect(this.change_path);
			this.buttons_path.pack_start(btn,false,false,0);
			this.path_list.add(btn);
		
			var elements=this.current_path.split("/");
			foreach (string s in elements) {
				if (s=="") {
					continue;
				}
				btn = new ToggleButton.with_label(s);
				btn.show();
				btn.released.connect(this.change_path);
				this.buttons_path.pack_start(btn,false,false,0);
				this.path_list.add(btn);
			}
		
			btn.active=true;
			btn.has_focus=true;
	
		}
	
		private void set_scroll_top() {
	
			this.scroll.hadjustment.value=this.scroll.hadjustment.lower;
			this.scroll.vadjustment.value=this.scroll.vadjustment.lower;
	
		}

		public void change_path(Widget btn) {
	
			string fpath="";
			bool found;
	
			found = false;
			foreach (ToggleButton b in this.path_list) {
		
				if (!found) {
					fpath = Path.build_filename(fpath,b.label);
				}
				if (b!=btn) {
					b.active=false;
				} else {
					found=true;
				}
			}
			this.current_path=fpath;
			this.refresh_icons();
			this.set_scroll_top();
		}

		public static int mysort_files(FileInfo? a, FileInfo? b) {
		
			if (a.name>b.name) {
				return 1;
			}
		
			if (a.name<b.name) {
				return -1;
			}
			return 0;
		}

		private void refresh_icons() {
	
			TreeIter iter;
			Gee.List<FileInfo?> files;
			string title;
	
			this.path_model.clear();
			
			if (false==this.backend.get_filelist(this.current_path,this.current_backup, out files, out title)) {
				return;
			}
			
			this.main_title.label=title;
			
			files.sort(mysort_files);
		
			var pbuf = this.path_view.render_icon(Stock.DIRECTORY,IconSize.DIALOG,"");
		
			foreach (FileInfo f in files) {

				if (f.isdir) {
					this.path_model.append (out iter);
					this.path_model.set (iter,0,f.name);
					this.path_model.set (iter,1,pbuf);
					this.path_model.set (iter,2,true);
				}

			}

			pbuf = this.path_view.render_icon(Stock.FILE,IconSize.DIALOG,"");

			foreach (FileInfo f in files) {
			
				if (f.isdir) {
					continue;
				}

				this.path_model.append (out iter);
				this.path_model.set (iter,0,f.name);
				this.path_model.set (iter,1,pbuf);
				this.path_model.set (iter,2,false);

			}

		}

	}
}
