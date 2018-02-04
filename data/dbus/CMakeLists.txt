### CMakeLists automatically created with AutoVala
### Do not edit

SET(DBUS_PREFIX ${CMAKE_INSTALL_PREFIX})
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/com.rastersoft.cronopete.service.base ${CMAKE_CURRENT_BINARY_DIR}/com.rastersoft.cronopete.service)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/com.rastersoft.cronopete.service DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/dbus-1/services/)
