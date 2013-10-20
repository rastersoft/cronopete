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

file(GLOB list_data RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} *)
foreach(file_data ${list_data})
	IF(IS_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/${file_data})
		install(DIRECTORY
			${file_data}
		DESTINATION
			share/doc/cronopete
		)
	ELSE()
		install(FILES
			${file_data}
		DESTINATION
			share/doc/cronopete
		)
	ENDIF()
endforeach()

