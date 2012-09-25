install(FILES
	${CMAKE_CURRENT_SOURCE_DIR}/cronopete_preferences.svg
	${CMAKE_CURRENT_SOURCE_DIR}/cronopete_restore.svg
DESTINATION
	share/icons/hicolor/scalable/apps
)
install(FILES
	${CMAKE_CURRENT_SOURCE_DIR}/anacronopete.svg
DESTINATION
	share/cronopete
)

file(GLOB list_png RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} *.png)

foreach(file_png ${list_png})
        install(FILES
                ${file_png}
        DESTINATION
                share/cronopete
        )
endforeach()