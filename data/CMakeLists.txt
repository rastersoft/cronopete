### CMakeLists automatically created with AutoVala
### Do not edit

install(PROGRAMS ${CMAKE_CURRENT_SOURCE_DIR}/cronopete_preferences.sh DESTINATION ${CMAKE_INSTALL_BINDIR})
install(PROGRAMS ${CMAKE_CURRENT_SOURCE_DIR}/cronopete_restore.sh DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/cronopete_preferences.desktop DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/applications/ )
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/cronopete_restore.desktop DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/applications/ )
if( NOT ( ${CMAKE_INSTALL_PREFIX} MATCHES "^/home/" ) )
	install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/cronopete.desktop DESTINATION /etc/xdg/autostart/ )
else()
	MESSAGE(STATUS "[33mAutostart file data/cronopete.desktop will not be installed. You must create your own .desktop file and put it at ~/.config/autostart[39m")
endif()
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/cronopete.plug ${CMAKE_CURRENT_BINARY_DIR}/cronopete.plug)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/cronopete.plug DESTINATION lib/plugs/cronopete/cronopete/)
include(GSettings)
add_schema(org.rastersoft.cronopete.gschema.xml)
