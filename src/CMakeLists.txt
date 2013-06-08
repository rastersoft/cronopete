set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/cronopete")
set (GETTEXT_PACKAGE "cronopete")
set (RELEASE_NAME "Cronopete")
set (VERSION "3.3.2")
set (VERSION_INFO "Release")
set (CMAKE_C_FLAGS "")
set (PREFIX ${CMAKE_INSTALL_PREFIX})

configure_file (${CMAKE_SOURCE_DIR}/src/Config.vala.cmake ${CMAKE_BINARY_DIR}/src/Config.vala)

add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")

find_package(PkgConfig)

set(MODULES_TO_CHECK gsl gee-1.0)

if(USE_GTK2)
	set(MODULES_TO_CHECK ${MODULES_TO_CHECK} gtk+-2.0)
else()
	set(MODULES_TO_CHECK ${MODULES_TO_CHECK} gtk+-3.0)
endif()

if(NO_APPINDICATOR)
else()
	if(USE_GTK2)
		set(MODULES_TO_CHECK ${MODULES_TO_CHECK} appindicator-0.1)
	else()
		set(MODULES_TO_CHECK ${MODULES_TO_CHECK} appindicator3-0.1)
	endif()
endif()

pkg_check_modules(DEPS REQUIRED ${MODULES_TO_CHECK})

add_definitions(${DEPS_CFLAGS})
link_libraries(${DEPS_LIBRARIES})
link_directories(${DEPS_LIBRARY_DIRS})

find_package(Vala REQUIRED)
include(ValaVersion)
ensure_vala_version("0.18.0" MINIMUM)

include(ValaPrecompile)

set(SOURCE_FILES 	backup.vala
	${CMAKE_BINARY_DIR}/src/Config.vala
	icons_widget.vala
	options.vala
	choose.vala
	cronopete.vala
	menu.vala
	restore.vala
	usbhd_backend.vala)

set(PACKAGES_VALA gio-2.0
	posix
	gee-1.0
	gsl
	gmodule-2.0)

set(COMPILE_OPTIONS_VALA -X -O2)

if(USE_GTK2)
	set(SOURCE_FILES ${SOURCE_FILES} switch_widget.vala)
	set(PACKAGES_VALA ${PACKAGES_VALA} gtk+-2.0)
	set(COMPILE_OPTIONS_VALA ${COMPILE_OPTIONS_VALA} -D USE_GTK2)
else()
	set(PACKAGES_VALA ${PACKAGES_VALA} gtk+-3.0)
endif()

if(NO_APPINDICATOR)
else()
	set(COMPILE_OPTIONS_VALA ${COMPILE_OPTIONS_VALA} -D USE_APPINDICATOR)
	if(USE_GTK2)
		set(PACKAGES_VALA ${PACKAGES_VALA} appindicator-0.1)
	else()
		set(PACKAGES_VALA ${PACKAGES_VALA} appindicator3-0.1)
	endif()
endif()

vala_precompile(VALA_C
	${SOURCE_FILES}
PACKAGES
	${PACKAGES_VALA}
OPTIONS
	${COMPILE_OPTIONS_VALA}
)

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

