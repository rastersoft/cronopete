### CMakeLists automatically created with AutoVala
### Do not edit

SET(DBUS_PREFIX ${AUTOVALA_INSTALL_PREFIX})
install(PROGRAMS ${CMAKE_CURRENT_SOURCE_DIR}/cronopete_preferences.sh DESTINATION bin/)
install(PROGRAMS ${CMAKE_CURRENT_SOURCE_DIR}/cronopete_restore.sh DESTINATION bin/)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/cronopete_preferences.desktop DESTINATION share/applications/ )
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/cronopete_restore.desktop DESTINATION share/applications/ )
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/cronopete.desktop DESTINATION /etc/xdg/autostart/ )
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/com.rastersoft.cronopete.service.base ${CMAKE_CURRENT_BINARY_DIR}/com.rastersoft.cronopete.service.base)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/com.rastersoft.cronopete.service.base DESTINATION ${CMAKE_INSTALL_PREFIX}/share/dbus-1/services/)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/cronopete.plug ${CMAKE_CURRENT_BINARY_DIR}/cronopete.plug)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/cronopete.plug DESTINATION lib/plugs/cronopete/cronopete/)
include(GSettings)
add_schema(org.rastersoft.cronopete.gschema.xml)
