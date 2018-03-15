### CMakeLists automatically created with AutoVala
### Do not edit

set (DATADIR "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_DATAROOTDIR}")
set (PKGDATADIR "${DATADIR}/cronopete")
set (GETTEXT_PACKAGE "cronopete")
set (RELEASE_NAME "cronopete")
set (CMAKE_C_FLAGS "")
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (VERSION "3.99.0")
set (TESTSRCDIR "${CMAKE_SOURCE_DIR}")
set (DOLLAR "$")

configure_file (${CMAKE_SOURCE_DIR}/src/Config.vala.base ${CMAKE_BINARY_DIR}/src/Config.vala)
add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")
set (VERSION "3.99.0")
add_definitions (${DEPS_CFLAGS})
link_libraries ( ${DEPS_LIBRARIES} )
link_directories ( ${DEPS_LIBRARY_DIRS} )
find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.36" MINIMUM)
include (ValaPrecompile)

set (VALA_PACKAGES ${VALA_PACKAGES} posix)
set (VALA_PACKAGES ${VALA_PACKAGES} gtk+-3.0)
if ((NOT NO_APPINDICATOR))
	set (VALA_PACKAGES ${VALA_PACKAGES} appindicator3-0.1)
endif ()
set (VALA_PACKAGES ${VALA_PACKAGES} cairo)
set (VALA_PACKAGES ${VALA_PACKAGES} gdk-3.0)
set (VALA_PACKAGES ${VALA_PACKAGES} gdk-pixbuf-2.0)
set (VALA_PACKAGES ${VALA_PACKAGES} gee-0.8)
set (VALA_PACKAGES ${VALA_PACKAGES} gio-2.0)
set (VALA_PACKAGES ${VALA_PACKAGES} glib-2.0)
set (VALA_PACKAGES ${VALA_PACKAGES} gobject-2.0)
set (VALA_PACKAGES ${VALA_PACKAGES} gsl)
set (VALA_PACKAGES ${VALA_PACKAGES} pango)
set (VALA_PACKAGES ${VALA_PACKAGES} pangocairo)
set (VALA_PACKAGES ${VALA_PACKAGES} udisks2)

set (APP_SOURCES ${APP_SOURCES} ${CMAKE_CURRENT_BINARY_DIR}/Config.vala)
set (APP_SOURCES ${APP_SOURCES} backup_base.vala)
set (APP_SOURCES ${APP_SOURCES} backup_rsync.vala)
set (APP_SOURCES ${APP_SOURCES} choose.vala)
set (APP_SOURCES ${APP_SOURCES} cronopete.vala)
set (APP_SOURCES ${APP_SOURCES} dates.vala)
set (APP_SOURCES ${APP_SOURCES} fixedlabel.vala)
set (APP_SOURCES ${APP_SOURCES} icons_widget.vala)
set (APP_SOURCES ${APP_SOURCES} menu.vala)
set (APP_SOURCES ${APP_SOURCES} options.vala)
set (APP_SOURCES ${APP_SOURCES} restore.vala)
set (APP_SOURCES ${APP_SOURCES} restore_canvas.vala)

if (NO_APPINDICATOR)
	set (COMPILE_OPTIONS ${COMPILE_OPTIONS} -D NO_APPINDICATOR)
	set (CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DNO_APPINDICATOR " )
	set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DNO_APPINDICATOR " )
endif ()

if ((${CMAKE_BUILD_TYPE} STREQUAL "Debug") OR (${CMAKE_BUILD_TYPE} STREQUAL "RelWithDebInfo"))
	set(COMPILE_OPTIONS ${COMPILE_OPTIONS} "-g")
endif()

set (COMPILE_OPTIONS ${COMPILE_OPTIONS} --target-glib 2.32 )

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
	${CMAKE_INSTALL_BINDIR}
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
		${CMAKE_INSTALL_DATAROOTDIR}/doc/cronopete
	)
endif()
