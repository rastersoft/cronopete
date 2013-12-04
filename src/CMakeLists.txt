### CMakeLists automatically created with AutoVala
### Do not edit

set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/cronopete")
set (GETTEXT_PACKAGE "cronopete")
set (RELEASE_NAME "cronopete")
set (CMAKE_C_FLAGS "")
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (VERSION "3.15.2")
set (DOLLAR "$")

configure_file (${CMAKE_SOURCE_DIR}/src/Config.vala.cmake ${CMAKE_BINARY_DIR}/src/Config.vala)
add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")
set (VERSION "3.15.2")
add_definitions (${DEPS_CFLAGS})
link_libraries ( ${DEPS_LIBRARIES} )
link_directories ( ${DEPS_LIBRARY_DIRS} )
find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.20" MINIMUM)
include (ValaPrecompile)

set (VALA_PACKAGES ${VALA_PACKAGES} posix)
if ((NOT NO_APPINDICATOR) AND (NOT USE_GTK2))
	set (VALA_PACKAGES ${VALA_PACKAGES} appindicator3-0.1)
endif ()
if ((NOT NO_APPINDICATOR) AND (USE_GTK2))
	set (VALA_PACKAGES ${VALA_PACKAGES} appindicator-0.1)
endif ()
if (USE_GTK2)
	set (VALA_PACKAGES ${VALA_PACKAGES} gdk-2.0)
	set (VALA_PACKAGES ${VALA_PACKAGES} gtk+-2.0)
else ()
	set (VALA_PACKAGES ${VALA_PACKAGES} gdk-3.0)
	set (VALA_PACKAGES ${VALA_PACKAGES} glib-2.0)
	set (VALA_PACKAGES ${VALA_PACKAGES} gtk+-3.0)
endif ()
set (VALA_PACKAGES ${VALA_PACKAGES} cairo)
set (VALA_PACKAGES ${VALA_PACKAGES} gee-1.0)
set (VALA_PACKAGES ${VALA_PACKAGES} gio-2.0)
set (VALA_PACKAGES ${VALA_PACKAGES} gsl)

set (APP_SOURCES ${APP_SOURCES} ${CMAKE_CURRENT_BINARY_DIR}/Config.vala)
set (APP_SOURCES ${APP_SOURCES} backup.vala)
set (APP_SOURCES ${APP_SOURCES} choose.vala)
set (APP_SOURCES ${APP_SOURCES} cronopete.vala)
set (APP_SOURCES ${APP_SOURCES} icons_widget.vala)
set (APP_SOURCES ${APP_SOURCES} menu.vala)
set (APP_SOURCES ${APP_SOURCES} options.vala)
set (APP_SOURCES ${APP_SOURCES} restore.vala)
set (APP_SOURCES ${APP_SOURCES} switch_widget.vala)
set (APP_SOURCES ${APP_SOURCES} usbhd_backend.vala)

if (NO_APPINDICATOR)
	set (COMPILE_OPTIONS ${COMPILE_OPTIONS} -D NO_APPINDICATOR)
endif ()
if (USE_GTK2)
	set (COMPILE_OPTIONS ${COMPILE_OPTIONS} -D USE_GTK2)
endif ()

vala_precompile(VALA_C cronopete
	${APP_SOURCES}
PACKAGES
	${VALA_PACKAGES}
OPTIONS
	${COMPILE_OPTIONS}
)

add_executable(cronopete ${VALA_C})

install(TARGETS
	cronopete
RUNTIME DESTINATION
	bin/
)

if(HAVE_VALADOC)
	valadoc(cronopete
		${CMAKE_BINARY_DIR}/valadoc/cronopete
		${APP_SOURCES}
	PACKAGES
		${VALA_PACKAGES}
	CUSTOM_VAPIS
		${CUSTOM_VAPIS_LIST}
	)
	install(DIRECTORY
		${CMAKE_BINARY_DIR}/valadoc
	DESTINATION
		share/doc/cronopete
	)
endif()
