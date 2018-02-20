cfg_cronopete2 = configuration_data()
cfg_cronopete2.set('DATADIR', join_paths(get_option('prefix'),get_option('datadir')))
cfg_cronopete2.set('PKGDATADIR', join_paths(get_option('prefix'),get_option('datadir'),'cronopete'))
cfg_cronopete2.set('GETTEXT_PACKAGE', 'cronopete')
cfg_cronopete2.set('RELEASE_NAME', 'cronopete')
cfg_cronopete2.set('PREFIX', get_option('prefix'))
cfg_cronopete2.set('VERSION', '4.0.0')
cfg_cronopete2.set('TESTSRCDIR', meson.source_root())

cfgfile_3 = configure_file(input: 'Config.vala.base',output: 'Config.vala',configuration: cfg_cronopete2)

cronopete2_deps = [gtk_3_0_dep]
if ( not NO_APPINDICATOR )
cronopete2_deps += [appindicator3_0_1_dep]
endif
cronopete2_deps += [cairo_dep]
cronopete2_deps += [gdk_3_0_dep]
cronopete2_deps += [gdk_pixbuf_2_0_dep]
cronopete2_deps += [gee_0_8_dep]
cronopete2_deps += [gio_2_0_dep]
cronopete2_deps += [glib_2_0_dep]
cronopete2_deps += [gobject_2_0_dep]
cronopete2_deps += [gsl_dep]
cronopete2_deps += [pango_dep]
cronopete2_deps += [pangocairo_dep]
cronopete2_sources = [cfgfile_3]
cronopete2_sources += ['backup_base.vala']
cronopete2_sources += ['backup_rsync.vala']
cronopete2_sources += ['cronopete.vala']
cronopete2_sources += ['fixedlabel.vala']
cronopete2_sources += ['menu.vala']
cronopete2_sources += ['options.vala']
cronopete2_vala_args = ['--pkg','posix']
cronopete2_vala_args += ['--target-glib', '2.32']
cronopete2_c_args = []
if NO_APPINDICATOR
  cronopete2_vala_args += ['-D', 'NO_APPINDICATOR']
  cronopete2_c_args += ['-DNO_APPINDICATOR']
endif

executable('cronopete2',cronopete2_sources,dependencies: cronopete2_deps,vala_args: cronopete2_vala_args,c_args: cronopete2_c_args,install: true)

