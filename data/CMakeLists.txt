IF ( ( ${CMAKE_INSTALL_PREFIX} STREQUAL "/usr") OR
     ( ${CMAKE_INSTALL_PREFIX} STREQUAL "/usr/") OR
     ( ${CMAKE_INSTALL_PREFIX} STREQUAL "/usr/local" ) OR
     ( ${CMAKE_INSTALL_PREFIX} STREQUAL "/usr/local/" ))
	include(GSettings)
	add_schema(cronopete.gschema.xml)
ELSE()
	install(FILES
	        ${CMAKE_CURRENT_SOURCE_DIR}/cronopete.gschema.xml
	DESTINATION
        	share/glib-2.0/schemas/
	)
ENDIF()


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
	${CMAKE_CURRENT_SOURCE_DIR}/cronopete.plug
DESTINATION
	lib/plugs/cronopete/cronopete/
)
