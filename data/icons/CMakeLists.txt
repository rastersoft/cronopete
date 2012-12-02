install(FILES
	${CMAKE_CURRENT_SOURCE_DIR}/cronopete_preferences.svg
	${CMAKE_CURRENT_SOURCE_DIR}/cronopete_restore.svg
DESTINATION
	share/icons/hicolor/scalable/apps
)


SET (list_sizes "16x16" "22x22" "24x24" "32x32" "48x48" "64x64" "128x128")

foreach(size_png ${list_sizes})
	install(FILES
		${CMAKE_CURRENT_SOURCE_DIR}/anacronopete_${size_png}.png
	DESTINATION
		share/icons/hicolor/${size_png}/apps
	RENAME
		anacronopete.png
	)
endforeach()

file(GLOB list_svg RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} cronopete-arrow-*.svg)

foreach(filename ${list_svg})
	install(FILES
			${CMAKE_CURRENT_SOURCE_DIR}/${filename}
		DESTINATION
			share/icons/hicolor/scalable/status
		)
endforeach()

IF(NOT (DEFINED ICON_UPDATE))
	SET (ICON_UPDATE "ON")
ENDIF()

IF( NOT (${ICON_UPDATE}  STREQUAL "OFF" ))

	if(USE_GTK2)
		install (CODE "execute_process ( COMMAND /usr/bin/gtk-update-icon-cache -t ${CMAKE_INSTALL_PREFIX}/share/icons/hicolor )" )
	else()
		install (CODE "execute_process ( COMMAND /usr/bin/gtk-update-icon-cache-3.0 -t ${CMAKE_INSTALL_PREFIX}/share/icons/hicolor )" )
	endif()
ENDIF()
