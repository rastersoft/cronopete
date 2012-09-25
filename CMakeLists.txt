project (cronopete)

cmake_minimum_required (VERSION 2.6)
cmake_policy (VERSION 2.8)

list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)
enable_testing ()

set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/cronopete")
set (GETTEXT_PACKAGE "cronopete")
set (RELEASE_NAME "Cronopete")
set (VERSION "3.2.0")
set (VERSION_INFO "Release")
set (CMAKE_C_FLAGS "")
set (PREFIX ${CMAKE_INSTALL_PREFIX})

configure_file (${CMAKE_SOURCE_DIR}/src/Config.vala.cmake ${CMAKE_BINARY_DIR}/src/Config.vala)

add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")

find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED gtk+-3.0 gsl gee-1.0)

add_definitions(${DEPS_CFLAGS})
link_libraries(${DEPS_LIBRARIES})
link_directories(${DEPS_LIBRARY_DIRS})

find_package(Vala REQUIRED)
include(ValaVersion)
ensure_vala_version("0.16.0" MINIMUM)

include(ValaPrecompile)

vala_precompile(VALA_C
	src/backup.vala
	src/Config.vala
	src/icons_widget.vala
	src/options.vala
	src/choose.vala
	src/cronopete.vala
	src/menu.vala
	src/restore.vala
	src/usbhd_backend.vala
PACKAGES
	gio-2.0
	gtk+-3.0
	posix
	gee-1.0
	gsl
	gmodule-2.0
OPTIONS
	-X -O2
	-D USE_GTK3
)

add_subdirectory(po)

add_executable(cronopete ${VALA_C})

install(TARGETS cronopete RUNTIME DESTINATION bin)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/cronopete.desktop DESTINATION share/applications)
