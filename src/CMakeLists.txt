### CMakeLists automatically created with AutoVala
### Do not edit

if(${CMAKE_INSTALL_PREFIX} MATCHES usr/local/? )
	set( AUTOVALA_INSTALL_PREFIX "/usr/local")
else()
	set( AUTOVALA_INSTALL_PREFIX "/usr")
endif()

STRING (REPLACE "/" ";" AUTOVALA_PATH_LIST ${CMAKE_INSTALL_PREFIX})
SET (FINAL_AUTOVALA_PATH "")

FOREACH(element ${AUTOVALA_PATH_LIST})
	IF (${FOUND_USR})
		SET(FINAL_AUTOVALA_PATH ${FINAL_AUTOVALA_PATH}/.. )
	ELSE()
		IF(${element} STREQUAL "usr")
			SET(FOUND_USR 1)
			SET(FINAL_AUTOVALA_PATH ${FINAL_AUTOVALA_PATH}.. )
		ENDIF()
	ENDIF()
ENDFOREACH()

set (DATADIR "${AUTOVALA_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/cronopete")
set (GETTEXT_PACKAGE "cronopete")
set (RELEASE_NAME "cronopete")
set (CMAKE_C_FLAGS "")
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (VERSION "3.15.1")
set (DOLLAR "$")

configure_file (${CMAKE_SOURCE_DIR}/src/Config.vala.cmake ${CMAKE_BINARY_DIR}/src/Config.vala)
add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")
set (VERSION "3.15.1")
add_definitions(${DEPS_CFLAGS})
link_libraries( ${DEPS_LIBRARIES} )
link_directories( ${DEPS_LIBRARY_DIRS} )
find_package(Vala REQUIRED)
include(ValaVersion)
ensure_vala_version("0.18" MINIMUM)
include(ValaPrecompile)

set (VALA_PACKAGES ${VALA_PACKAGES} posix)
set (VALA_PACKAGES ${VALA_PACKAGES} gee-1.0)
set (VALA_PACKAGES ${VALA_PACKAGES} cairo)
set (VALA_PACKAGES ${VALA_PACKAGES} gsl)
IF ((NOT NO_APPINDICATOR) AND (NOT USE_GTK2))
set (VALA_PACKAGES ${VALA_PACKAGES} appindicator3-0.1)
ENDIF()
IF ((NOT NO_APPINDICATOR) AND (USE_GTK2))
set (VALA_PACKAGES ${VALA_PACKAGES} appindicator-0.1)
ENDIF()
IF (USE_GTK2)
set (VALA_PACKAGES ${VALA_PACKAGES} gtk+-2.0)
set (VALA_PACKAGES ${VALA_PACKAGES} gdk-2.0)
ELSE()
set (VALA_PACKAGES ${VALA_PACKAGES} gtk+-3.0)
set (VALA_PACKAGES ${VALA_PACKAGES} gdk-3.0)
set (VALA_PACKAGES ${VALA_PACKAGES} glib-2.0)
ENDIF()


set (APP_SOURCES ${APP_SOURCES} ${CMAKE_CURRENT_BINARY_DIR}/Config.vala)
set (APP_SOURCES ${APP_SOURCES} switch_widget.vala)
set (APP_SOURCES ${APP_SOURCES} options.vala)
set (APP_SOURCES ${APP_SOURCES} usbhd_backend.vala)
set (APP_SOURCES ${APP_SOURCES} cronopete.vala)
set (APP_SOURCES ${APP_SOURCES} menu.vala)
set (APP_SOURCES ${APP_SOURCES} icons_widget.vala)
set (APP_SOURCES ${APP_SOURCES} restore.vala)
set (APP_SOURCES ${APP_SOURCES} backup.vala)
set (APP_SOURCES ${APP_SOURCES} choose.vala)

IF (USE_GTK2)
	SET(OPTION_DEFINES ${OPTION_DEFINES} -D USE_GTK2)
ENDIF()
IF (NO_APPINDICATOR)
	SET(OPTION_DEFINES ${OPTION_DEFINES} -D NO_APPINDICATOR)
ENDIF()

vala_precompile(VALA_C cronopete
	${APP_SOURCES}
PACKAGES
	${VALA_PACKAGES}
OPTIONS
	 ${OPTION_DEFINES}
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
