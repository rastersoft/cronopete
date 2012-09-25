file(GLOB list_ui RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} *.ui)

foreach(file_ui ${list_ui})
        install(FILES
                ${file_ui}
        DESTINATION
                share/cronopete
        )
endforeach()
