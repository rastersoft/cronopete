include(GSettings)
add_schema(cronopete.gschema.xml)

STRING (REPLACE "/" ";" PATH_LIST ${CMAKE_INSTALL_PREFIX})
SET (FINAL_PATH "")

FOREACH(element ${PATH_LIST})
	IF (${FOUND_USR})
		SET(FINAL_PATH ${FINAL_PATH}/.. )
	ELSE()
		IF(${element} STREQUAL "usr")
        	        SET(FOUND_USR 1)
			SET(FINAL_PATH ${FINAL_PATH}.. )
	        ENDIF()

	ENDIF()
ENDFOREACH()

IF(${CMAKE_INSTALL_PREFIX} MATCHES usr/local/? )
	SET( DBUS_PREFIX "/usr/local")
ELSE()
	SET (DBUS_PREFIX "/usr")
ENDIF()

configure_file(
	${CMAKE_CURRENT_SOURCE_DIR}/com.backup.cronopete.service.base
	${CMAKE_CURRENT_BINARY_DIR}/com.backup.cronopete.service
)

configure_file(
	${CMAKE_CURRENT_SOURCE_DIR}/cronopete.plug
	${CMAKE_CURRENT_BINARY_DIR}/cronopete.plug
)

install(FILES
	${CMAKE_CURRENT_BINARY_DIR}/com.backup.cronopete.service
DESTINATION
    ${CMAKE_INSTALL_PREFIX}/share/dbus-1/services/
)

install(FILES
	${CMAKE_CURRENT_SOURCE_DIR}/cronopete.desktop
DESTINATION
	${FINAL_PATH}/etc/xdg/autostart/
)
install(FILES
	${CMAKE_CURRENT_SOURCE_DIR}/cronopete_preferences.desktop
	${CMAKE_CURRENT_SOURCE_DIR}/cronopete_restore.desktop
DESTINATION
	share/applications/
)

install(FILES
	${CMAKE_CURRENT_BINARY_DIR}/cronopete.plug
DESTINATION
	lib/plugs/cronopete/cronopete/
)
