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

	struct file_info {
		string name;
		GLib.ThemedIcon icon;
		bool isdir;
		TimeVal mod_time;
		int64 size;
	}

	struct bookmark_str {
		string name;
		string icon;
	}

	enum e_sort_by {NAME, TYPE, DATE, SIZE}
	
	class IconBrowser : Frame {

		private VBox main_container;
		private HBox buttons_path;
		private ScrolledWindow buttons_scroll;
		private ListStore path_model;
		private IconView path_view;
		private ScrolledWindow scroll;
		private Gtk.TreeView path_view2;
		private ScrolledWindow scroll2;
		
		private string current_path;
		private Gee.List<Button> path_list;
		private EventBox background_eb;
		private time_t current_backup;
		private backends backend;
		private uint timer_refresh;
		private Menu menu;
		private Gee.List<bookmark_str ?> bookmarks;
		private Gtk.TreeView bookmark_view;
		private ListStore bookmark_model;
		private Gtk.Button btn_prev;
		private Gtk.Button btn_next;

		private e_sort_by sort_by;
		private bool reverse_sort;
		private bool show_hiden;
		private bool view_as_icons;

		private Gtk.Paned paned;

		public IconBrowser(backends p_backend,string p_current_path) {
	
			this.backend=p_backend;
			this.current_path=p_current_path;
		
			this.main_container=new VBox(false,0);
			this.timer_refresh=0;
			
			this.show_hiden=false;
			this.view_as_icons=true;
			this.sort_by=e_sort_by.NAME;

			this.buttons_scroll=new Gtk.ScrolledWindow(null,null);
			this.buttons_scroll.hscrollbar_policy=PolicyType.NEVER;
			this.buttons_scroll.vscrollbar_policy=PolicyType.NEVER;
			this.buttons_path=new HBox(false,0);
			this.buttons_path.homogeneous=false;
			this.buttons_scroll.add_with_viewport(this.buttons_path);

			var buttons_container = new HBox(false,0);
			this.btn_prev=new Button();
			var pic1 = new Gtk.Image.from_icon_name("back",IconSize.SMALL_TOOLBAR);
			this.btn_prev.add(pic1);
			this.btn_next=new Button();
			var pic2 = new Gtk.Image.from_icon_name("forward",IconSize.SMALL_TOOLBAR);
			this.btn_next.add(pic2);
			this.btn_prev.clicked.connect(this.path_prev);
			this.btn_next.clicked.connect(this.path_next);
			buttons_container.pack_start(this.btn_prev,false,false,0);
			buttons_container.pack_start(this.buttons_scroll,false,false,0);
			buttons_container.pack_start(this.btn_next,false,false,0);
			this.main_container.pack_start(buttons_container,false,false,0);

			this.paned = new HPaned();
			var container2 = new Gtk.HBox(false,0);
			var scroll2= new ScrolledWindow(null,null);
			scroll2.hscrollbar_policy=PolicyType.NEVER;
			this.bookmark_model=new ListStore(3,typeof(GLib.Icon),typeof(string),typeof(string));
			this.bookmark_view=new Gtk.TreeView.with_model(this.bookmark_model);
			var crpb = new CellRendererPixbuf();
			crpb.stock_size = IconSize.SMALL_TOOLBAR;
			this.bookmark_view.insert_column_with_attributes (-1, "", crpb , "gicon", 0);
			this.bookmark_view.insert_column_with_attributes (-1, "", new CellRendererText (), "text", 1);
			this.bookmark_view.enable_grid_lines=TreeViewGridLines.NONE;
			this.bookmark_view.headers_visible=false;
			this.read_bookmarks();
			this.bookmark_view.cursor_changed.connect(this.bookmark_selected);

			scroll2.add(this.bookmark_view);
			scroll2.vscrollbar_policy=PolicyType.AUTOMATIC;
			this.paned.add1(scroll2);
			this.paned.add2(container2);
			
			this.scroll = new ScrolledWindow(null,null);
			this.scroll.hscrollbar_policy=PolicyType.AUTOMATIC;
			this.scroll.vscrollbar_policy=PolicyType.AUTOMATIC;
			container2.pack_start(this.scroll,true,true,0);

			this.scroll2 = new ScrolledWindow(null,null);
			this.scroll2.hscrollbar_policy=PolicyType.AUTOMATIC;
			this.scroll2.vscrollbar_policy=PolicyType.AUTOMATIC;
			container2.pack_start(this.scroll2,true,true,0);
			
			this.main_container.pack_start(this.paned,true,true,0);
			
			/* path_model stores the data for each file/folder:
				 - file name (string)
				 - icon (string)
				 - is_folder (boolean)
			*/
			this.path_model=new ListStore(6,typeof(string),typeof(Gdk.Pixbuf),typeof(bool),typeof(Gdk.Pixbuf),typeof(string),typeof(string));
			this.path_view=new IconView.with_model(this.path_model);
			this.path_view.add_events (Gdk.EventMask.BUTTON_PRESS_MASK);
			this.path_view.button_press_event.connect(this.on_click);
			this.path_view.columns=-1;
			this.path_view.set_pixbuf_column(1);
			this.path_view.set_text_column(0);
			this.path_view.selection_mode=SelectionMode.MULTIPLE;
			this.path_view.button_press_event.connect(this.selection_made);
			this.path_view.orientation=Orientation.VERTICAL;
			this.scroll.add_with_viewport(this.path_view);

			// View for list
			this.path_view2=new Gtk.TreeView.with_model(this.path_model);
			this.path_view2.add_events (Gdk.EventMask.BUTTON_PRESS_MASK);
			this.path_view2.button_press_event.connect(this.on_click);
			var crpb2 = new CellRendererPixbuf();
			crpb2.stock_size = IconSize.SMALL_TOOLBAR;
			this.path_view2.insert_column_with_attributes (-1, "", crpb2 , "gicon", 3);
			this.path_view2.insert_column_with_attributes (-1, _("Name"), new CellRendererText (), "text", 0);
			var renderdate = new CellRendererText();
			renderdate.xalign=1;
			this.path_view2.insert_column_with_attributes (-1, _("Size"), renderdate, "text", 4);
			this.path_view2.insert_column_with_attributes (-1, _("Modification date"), new CellRendererText (), "text", 5);
			this.path_view2.get_selection().set_mode(SelectionMode.MULTIPLE);
			var column=this.path_view2.get_column(1);
			column.resizable=true;
			
			this.path_view2.button_press_event.connect(this.selection_made);
			this.scroll2.add_with_viewport(this.path_view2);
			
			this.background_eb = new EventBox();
			this.background_eb.add(this.main_container);
			this.add(this.background_eb);

			this.path_view.item_width=175;
		
			this.path_list=new Gee.ArrayList<ToggleButton>();
			
			this.refresh_icons();
			this.refresh_path_list();
			this.show.connect_after(this.refresh_path_list);
		
		}

		private bool read_bookmarks() {

			TreeIter iter;

			this.bookmarks = new Gee.ArrayList<bookmark_str ?>();

			string home=Environment.get_home_dir();

			bookmark_str val = bookmark_str();
			val.name=home.dup();
			val.icon="user-home folder-home";
			this.bookmarks.add(val);
			
			var config_file = File.new_for_path (GLib.Path.build_filename(home,".config","user-dirs.dirs"));
			
			if (config_file.query_exists (null)) {
				try {
					var file_read=config_file.read(null);
					var in_stream = new DataInputStream (file_read);
					string line;
					string folder;
					string type;
					int pos;
					int len;

					while ((line = in_stream.read_line (null, null)) != null) {
						if (line.has_prefix("XDG_")) {
							pos=line.index_of_char('_',4);
							type=line.substring(4,pos-4);
							pos=line.index_of_char('=');
							folder=line.substring(pos+1);
							len=folder.length;
							if ((folder[0]=='"')&&(len>=2)) {
								folder=folder.substring(1,len-2);
							}
							if (folder.has_prefix("$HOME")) {
								folder=GLib.Path.build_filename(home,folder.substring(6));
							}
							val = bookmark_str();
							val.name = folder.dup();
							switch (type) {
							case "DESKTOP":
								val.icon="user-desktop";
							break;
							case "DOWNLOAD":
								val.icon="user-download folder-download folder-downloads";
							break;
							case "TEMPLATES":
								val.icon="user-templates folder-templates";
							break;
							case "PUBLICSHARE":
								val.icon="user-publicshare folder-publicshare";
							break;
							case "DOCUMENTS":
								val.icon="user-documents folder-documents";
							break;
							case "MUSIC":
								val.icon="user-music folder-music";
							break;
							case "PICTURES":
								val.icon="user-pictures folder-pictures";
							break;
							case "VIDEOS":
								val.icon="user-videos folder-videos";
							break;
							default:
								val.icon="folder";
							break;
							}
							this.bookmarks.add(val);
						}
					}
				} catch {
				}
			}

			config_file = File.new_for_path (GLib.Path.build_filename(home,".gtk-bookmarks"));
			
			if (config_file.query_exists (null)) {
				try {
					var file_read=config_file.read(null);
					var in_stream = new DataInputStream (file_read);
					string line;
					string folder;
					while ((line = in_stream.read_line (null, null)) != null) {
						if (line.has_prefix("file://")) {
							folder=line.substring(7);
						    val = bookmark_str();
							val.name = folder.dup();
							val.icon=Gtk.Stock.DIRECTORY;
							this.bookmarks.add(val);
						}
					}
				} catch {
				}
			}
			string icons;
			foreach(var folder in this.bookmarks) {
				icons="%s folder".printf(folder.icon);
				var tmp = new ThemedIcon.from_names(icons.split(" "));
				this.bookmark_model.append (out iter);
				this.bookmark_model.set(iter,0,tmp);
				this.bookmark_model.set(iter,1,GLib.Path.get_basename(folder.name));
				this.bookmark_model.set(iter,2,folder.name);

			}
			
			return true;
		}

		private void bookmark_selected() {

			var selected = this.bookmark_view.get_selection();
			if (selected.count_selected_rows()!=0) {
				TreeModel model;
				TreeIter iter;
				selected.get_selected(out model, out iter);
				GLib.Value spath;
				model.get_value(iter,2,out spath);
				var final_path = spath.get_string();
				this.current_path=final_path;
				this.refresh_icons();
				this.refresh_path_list();
				this.set_scroll_top();
			}
		}
		
		private bool on_click(Gdk.EventButton event) {

			if (event.button!=3) {
				return false;
			}
			this.menu=new Menu();
			
			var item1 = new CheckMenuItem.with_label(_("Show hiden files"));
			item1.active=this.show_hiden;
			item1.activate.connect(this.toggle_show_hide);
			this.menu.append(item1);

			var item2 = new SeparatorMenuItem();
			this.menu.append(item2);

			var item3 = new CheckMenuItem.with_label(_("Reverse order"));
			item3.active=this.reverse_sort;
			item3.activate.connect(this.toggle_reverse_sort);
			this.menu.append(item3);

			var item4 = new SeparatorMenuItem();
			this.menu.append(item4);

			var item5 = new CheckMenuItem.with_label(_("Sort by name"));
			item5.activate.connect(this.set_sort_by_name);
			this.menu.append(item5);

			var item6 = new CheckMenuItem.with_label(_("Sort by type"));
			item6.activate.connect(this.set_sort_by_type);
			this.menu.append(item6);

			var item7 = new CheckMenuItem.with_label(_("Sort by size"));
			item7.activate.connect(this.set_sort_by_size);
			this.menu.append(item7);

			var item8 = new CheckMenuItem.with_label(_("Sort by date"));
			item8.activate.connect(this.set_sort_by_date);
			this.menu.append(item8);

			switch(this.sort_by) {
			case e_sort_by.NAME:
				item5.active=true;
			break;
			case e_sort_by.TYPE:
				item6.active=true;
			break;
			case e_sort_by.SIZE:
				item7.active=true;
			break;
			case e_sort_by.DATE:
				item8.active=true;
			break;
			}

			var item9 = new SeparatorMenuItem();
			this.menu.append(item9);

			var item10 = new CheckMenuItem.with_label(_("View as icons"));
			item10.activate.connect(this.set_view_as_icons);
			this.menu.append(item10);

			var item11 = new CheckMenuItem.with_label(_("View as list"));
			item11.activate.connect(this.set_view_as_list);
			this.menu.append(item11);

			if (this.view_as_icons) {
				item10.active=true;
			} else {
				item11.active=true;
			}
			
			this.menu.show_all();
			this.menu.popup(null,null,null,2,Gtk.get_current_event_time());
			return true;
		}

		private void set_view_as_icons() {
			this.view_as_icons=true;
			this.refresh_icons ();
			this.refresh_path_list ();
		}

		private void set_view_as_list() {
			this.view_as_icons=false;
			this.refresh_icons ();
			this.refresh_path_list ();
		}
		
		private void set_sort_by_name() {
			this.sort_by=e_sort_by.NAME;
			this.refresh_icons ();
		}

		private void set_sort_by_type() {
			this.sort_by=e_sort_by.TYPE;
			this.refresh_icons ();
		}

		private void set_sort_by_size() {
			this.sort_by=e_sort_by.SIZE;
			this.refresh_icons ();
		}

		private void set_sort_by_date() {
			this.sort_by=e_sort_by.DATE;
			this.refresh_icons ();
		}
		
		private void toggle_show_hide() {
			this.show_hiden = this.show_hiden ? false : true;
			this.refresh_icons ();
		}

		private void toggle_reverse_sort() {
			this.reverse_sort = this.reverse_sort ? false : true;
			this.refresh_icons ();
		}
		
		public void set_backup_time(time_t backup) {
			
			this.current_backup=backup;
			this.path_model.clear();
			if (this.timer_refresh!=0) {
				Source.remove(this.timer_refresh);
			}
			this.timer_refresh=Timeout.add(100,this.timer_f);
		}

		public bool timer_f() {

			this.refresh_icons();
			return false;
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

			GLib.List<TreePath> selection;
			TreeModel model;
			
			if (this.view_as_icons) {
				selection = this.path_view.get_selected_items();
				model = this.path_view.model;
			} else {
				selection = this.path_view2.get_selection().get_selected_rows(out model);
			}

			TreeIter iter;
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

		public string get_current_path() {
			
			return (this.current_path);
			
		}

		private void refresh_path_list() {

			if (this.view_as_icons) {
				this.scroll.show();
				this.scroll2.hide();
			} else {
				this.scroll2.show();
				this.scroll.hide();
			}

			foreach (Button b in this.path_list) {
				b.destroy();
			}

			var btn = new Button.with_label("/");
			btn.show();
			btn.clicked.connect(this.change_path);
			this.buttons_path.pack_start(btn,false,false,0);
			this.path_list.add(btn);

			var elements=this.current_path.split("/");
			foreach (string s in elements) {
				if (s=="") {
					continue;
				}
				btn = new Button.with_label(s);
				btn.show();
				btn.clicked.connect(this.change_path);
				btn.focus_on_click=true;
				this.buttons_path.pack_start(btn,false,false,0);
				this.path_list.add(btn);
			}
			this.buttons_path.show_all();
			btn.has_focus=true;

			Gtk.Requisition req;
			this.buttons_path.size_request(out req);
			Gtk.Requisition req2;
			this.size_request(out req2);
			if (req.width>=req2.width) {
				this.btn_prev.show();
				this.btn_next.show();
				Gtk.Requisition req3;
				this.btn_prev.size_request(out req3);
				var newwidth = req2.width-2*req3.width-10;
				if (newwidth>0) {
					this.buttons_scroll.width_request=newwidth;
					this.buttons_scroll.hadjustment.upper=req.width-newwidth;
					this.buttons_scroll.hadjustment.value=req.width-newwidth;
				}
			} else {
				this.buttons_scroll.width_request=req2.width;
				this.btn_prev.hide();
				this.btn_next.hide();
			}
		}

		private void path_prev() {

			var v=this.buttons_scroll.hadjustment.value;
			v-=30;
			this.buttons_scroll.hadjustment.value=v;

		}

		private void path_next() {
			var v=this.buttons_scroll.hadjustment.value;
			v+=30;
			Gtk.Requisition req;
			this.buttons_path.size_request(out req);
			Gtk.Requisition req2;
			this.buttons_scroll.size_request(out req2);
			var max = req.width-req2.width;
			if (v>max) {
				v=max;
			}
			this.buttons_scroll.hadjustment.value=v;
		}
		
		private void set_scroll_top() {
	
			this.scroll.hadjustment.value=this.scroll.hadjustment.lower;
			this.scroll.vadjustment.value=this.scroll.vadjustment.lower;
			this.scroll2.hadjustment.value=this.scroll.hadjustment.lower;
			this.scroll2.vadjustment.value=this.scroll.vadjustment.lower;
	
		}

		public void change_path(Widget btn) {
	
			string fpath="";
			bool found;
	
			found = false;

			Button btn2=(Button)btn;
			
			foreach (Button b in this.path_list) {
		
				if (!found) {
					fpath = Path.build_filename(fpath,b.label);
				} else {
					b.destroy();
				}
				if (b==btn2) {
					found=true;
				}
			}
			this.current_path=fpath;
			this.refresh_icons();
			this.set_scroll_top();
		}

		public static int mysort_files_byname(file_info? a, file_info? b) {

			return mysort_files(a,b,false,e_sort_by.NAME);
		}
		public static int mysort_files_byname_r(file_info? a, file_info? b) {

			return mysort_files(a,b,true,e_sort_by.NAME);
		}
		public static int mysort_files_bydate(file_info? a, file_info? b) {

			return mysort_files(a,b,false,e_sort_by.DATE);
		}
		public static int mysort_files_bydate_r(file_info? a, file_info? b) {

			return mysort_files(a,b,true,e_sort_by.DATE);
		}
		public static int mysort_files_bysize(file_info? a, file_info? b) {

			return mysort_files(a,b,false,e_sort_by.SIZE);
		}
		public static int mysort_files_bysize_r(file_info? a, file_info? b) {
			
			return mysort_files(a,b,true,e_sort_by.SIZE);
		}
		public static int mysort_files_bytype(file_info? a, file_info? b) {

			return mysort_files(a,b,false,e_sort_by.TYPE);
		}
		public static int mysort_files_bytype_r(file_info? a, file_info? b) {

			return mysort_files(a,b,true,e_sort_by.TYPE);
		}
		
		public static int mysort_files(file_info? a, file_info? b, bool reverse, e_sort_by mode) {

			// Folders always first
			if (a.isdir && (!b.isdir)) {
				return -1;
			}
			if ((!a.isdir) && b.isdir) {
				return 1;
			}

			if (mode==e_sort_by.DATE) {
				if (a.mod_time.tv_sec>b.mod_time.tv_sec) {
					if (reverse) {
						return -1;
					} else {
						return 1;
					}
				}
				if (a.mod_time.tv_sec<b.mod_time.tv_sec) {
					if (reverse) {
						return 1;
					} else {
						return -1;
					}
				}
			}

			if (mode==e_sort_by.SIZE) {
				if (a.size>b.size) {
					if (reverse) {
						return -1;
					} else {
						return 1;
					}
				}
				if (a.size<b.size) {
					if (reverse) {
						return 1;
					} else {
						return -1;
					}
				}
			}

			if ((mode==e_sort_by.TYPE)&&(!a.isdir)) {
				var posa=a.name.last_index_of_char('.');
				var posb=b.name.last_index_of_char('.');

				if ((posa*posb)<0) { // one has extension, the other not
					if (posa<0) { // files without extension go first
						if (reverse) {
							return 1;
						} else {
							return -1;
						}
					} else {
						if (reverse) {
							return -1;
						} else {
							return 1;
						}
					}
				}
				
				int r1;
				if (posa>=0) {
					var exta=a.name.substring(posa);
					var extb=b.name.substring(posb);
					exta=exta.casefold();
					extb=extb.casefold();
					if (reverse) {
						r1=extb.collate(exta);
					} else {
						r1=exta.collate(extb);
					}
					if (r1!=0) {
						return (r1);
					}
				}
			}

			// If both names are equal in the desired comparison mode, then sort by name
			
			string name1;
			string name2;
			
			if (a.name[0]=='.') {
				name1=a.name.substring(1);
			} else {
				name1=a.name.dup();
			}
			if (b.name[0]=='.') {
				name2=b.name.substring(1);
			} else {
				name2=b.name.dup();
			}
			
			name1=name1.casefold();
			name2=name2.casefold();
			if (reverse) {
				return name2.collate(name1);
			} else {
				return name1.collate(name2);
			}
		}

		private void refresh_icons() {
	
			TreeIter iter;
			Gee.List<file_info?> files;
			string title;
	
			this.path_model.clear();
			
			if (false==this.backend.get_filelist(this.current_path,this.current_backup, out files, out title)) {
				return;
			}

			switch(this.sort_by) {
			case e_sort_by.NAME:
				if (this.reverse_sort) {
					files.sort(mysort_files_byname_r);
				} else {
					files.sort(mysort_files_byname);
				}
			break;
			case e_sort_by.TYPE:
				if (this.reverse_sort) {
					files.sort(mysort_files_bytype_r);
				} else {
					files.sort(mysort_files_bytype);
				}
			break;
			case e_sort_by.SIZE:
				if (this.reverse_sort) {
					files.sort(mysort_files_bysize_r);
				} else {
					files.sort(mysort_files_bysize);
				}
			break;
			case e_sort_by.DATE:
				if (this.reverse_sort) {
					files.sort(mysort_files_bydate_r);
				} else {
					files.sort(mysort_files_bydate);
				}
			break;
			}
		
			var theme = Gtk.IconTheme.get_default();

			Gdk.Pixbuf pbuf=null;
			Gdk.Pixbuf pbuf2=null;
			
			foreach (file_info f in files) {

				if ((this.show_hiden==false)&&(f.name[0]=='.')) {
					continue;
				}
				
				try {
					pbuf = theme.lookup_by_gicon(f.icon,48,0).load_icon();
					pbuf2= theme.lookup_by_gicon(f.icon,24,0).load_icon();
				} catch {
					if (f.isdir) {
						pbuf = this.path_view.render_icon(Stock.DIRECTORY,IconSize.DIALOG,"");
						pbuf2= this.path_view.render_icon(Stock.DIRECTORY,IconSize.SMALL_TOOLBAR,"");
					} else {
						pbuf = this.path_view.render_icon(Stock.FILE,IconSize.DIALOG,"");
						pbuf2= this.path_view.render_icon(Stock.FILE,IconSize.SMALL_TOOLBAR,"");
					}
				}
				
				this.path_model.append (out iter);
				this.path_model.set (iter,0,f.name);
				this.path_model.set (iter,1,pbuf);
				this.path_model.set (iter,2,f.isdir);
				this.path_model.set (iter,3,pbuf2);
				float fsize=(float)f.size;
				string fssize;
				if (fsize<1024.0) {
					fssize="%01.0f bytes".printf(fsize);
				} else if (fsize<1048576.0) {
					fssize="%01.1f KB".printf(fsize/1024.0);
				} else if (fsize<1073741824.0) {
					fssize="%01.1f MB".printf(fsize/1048576.0);
				} else {
					fssize="%01.1f GB".printf(fsize/1073741824.0);
				}
				this.path_model.set (iter,4,fssize);
				GLib.DateTime timeval = new GLib.DateTime.from_timeval_utc(f.mod_time);
				this.path_model.set (iter,5,timeval.format("%c"));
				
			}
		}

	}
}
