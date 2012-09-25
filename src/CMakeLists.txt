configure_file (${CMAKE_SOURCE_DIR}/src/Config.vala.cmake ${CMAKE_BINARY_DIR}/src/Config.vala)

add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")

find_package(PkgConfig)

if(USE_GTK2)
	pkg_check_modules(DEPS REQUIRED gtk+-2.0 gsl gee-1.0)
else()
	pkg_check_modules(DEPS REQUIRED gtk+-3.0 gsl gee-1.0)
endif()

add_definitions(${DEPS_CFLAGS})
link_libraries(${DEPS_LIBRARIES})
link_directories(${DEPS_LIBRARY_DIRS})

find_package(Vala REQUIRED)
include(ValaVersion)
ensure_vala_version("0.16.0" MINIMUM)

include(ValaPrecompile)

if(USE_GTK2)
vala_precompile(VALA_C
	backup.vala
	${CMAKE_BINARY_DIR}/src/Config.vala
	icons_widget.vala
	options.vala
	choose.vala
	cronopete.vala
	menu.vala
	restore.vala
	usbhd_backend.vala
	switch_widget.vala
PACKAGES
	gio-2.0
	gtk+-2.0
	posix
	gee-1.0
	gsl
	gmodule-2.0
OPTIONS
	-X -O2
	-D USE_GTK2
)
else()
vala_precompile(VALA_C
	backup.vala
	${CMAKE_BINARY_DIR}/src/Config.vala
	icons_widget.vala
	options.vala
	choose.vala
	cronopete.vala
	menu.vala
	restore.vala
	usbhd_backend.vala
PACKAGES
	gio-2.0
	gtk+-3.0
	posix
	gee-1.0
	gsl
	gmodule-2.0
OPTIONS
	-X -O2
)

endif()



add_executable(cronopete ${VALA_C})

install(TARGETS
	cronopete
RUNTIME DESTINATION
	bin
)

install(PROGRAMS
	${CMAKE_CURRENT_SOURCE_DIR}/cronopete_preferences
	${CMAKE_CURRENT_SOURCE_DIR}/cronopete_restore
DESTINATION
	bin
)