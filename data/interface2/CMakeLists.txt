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

if (USE_GTK2)
	install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/about.ui DESTINATION share/cronopete/ )
	install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/chooser.ui DESTINATION share/cronopete/ )
	install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/config_exported.ui DESTINATION share/cronopete/ )
	install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/folder_selector.ui DESTINATION share/cronopete/ )
	install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/format_error.ui DESTINATION share/cronopete/ )
	install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/format_force.ui DESTINATION share/cronopete/ )
	install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/formatting.ui DESTINATION share/cronopete/ )
	install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/main.ui DESTINATION share/cronopete/ )
	install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/options.ui DESTINATION share/cronopete/ )
	install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/restore_error.ui DESTINATION share/cronopete/ )
	install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/restore_ok.ui DESTINATION share/cronopete/ )
	install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/restoring.ui DESTINATION share/cronopete/ )
	install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/welcome.ui DESTINATION share/cronopete/ )
endif ()

