cfg_cronopete = configuration_data()
cfg_cronopete.set('DATADIR', join_paths(get_option('prefix'),get_option('datadir')))
cfg_cronopete.set('PKGDATADIR', join_paths(get_option('prefix'),get_option('datadir'),'cronopete'))
cfg_cronopete.set('GETTEXT_PACKAGE', 'cronopete')
cfg_cronopete.set('RELEASE_NAME', 'cronopete')
cfg_cronopete.set('PREFIX', get_option('prefix'))
cfg_cronopete.set('VERSION', '4.0.1')
cfg_cronopete.set('TESTSRCDIR', meson.source_root())

cfgfile_3 = configure_file(input: 'Config.vala.base',output: 'Config.vala',configuration: cfg_cronopete)

cronopete_deps = [gtk_3_0_dep]
if ( not NO_APPINDICATOR )
cronopete_deps += [appindicator3_0_1_dep]
endif
cronopete_deps += [cairo_dep]
cronopete_deps += [gdk_3_0_dep]
cronopete_deps += [gdk_pixbuf_2_0_dep]
cronopete_deps += [gee_0_8_dep]
cronopete_deps += [gio_2_0_dep]
cronopete_deps += [glib_2_0_dep]
cronopete_deps += [gobject_2_0_dep]
cronopete_deps += [gsl_dep]
cronopete_deps += [pango_dep]
cronopete_deps += [pangocairo_dep]
cronopete_deps += [udisks2_dep]
cronopete_sources = [cfgfile_3]
cronopete_sources += ['backup_base.vala']
cronopete_sources += ['backup_folder.vala']
cronopete_sources += ['backup_rsync.vala']
cronopete_sources += ['choose_disk.vala']
cronopete_sources += ['cronopete.vala']
cronopete_sources += ['fixedlabel.vala']
cronopete_sources += ['helpers.vala']
cronopete_sources += ['icons_widget.vala']
cronopete_sources += ['menu.vala']
cronopete_sources += ['options.vala']
cronopete_sources += ['restore.vala']
cronopete_sources += ['restore_canvas.vala']
cronopete_vala_args = ['--pkg','posix']
cronopete_vala_args += ['--target-glib', '2.32']
cronopete_c_args = []
if NO_APPINDICATOR
  cronopete_vala_args += ['-D', 'NO_APPINDICATOR']
  cronopete_c_args += ['-DNO_APPINDICATOR']
endif

executable('cronopete',cronopete_sources,dependencies: cronopete_deps,vala_args: cronopete_vala_args,c_args: cronopete_c_args,install: true)

