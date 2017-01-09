######################################################################################
# PICMake VERSION 1.1.0
# HISTORY:
# 	1.0.0 2017.01.04 : first commit, one include for one target.
#   1.1.0 2017.01.09 : support multi targets, reorgnized functions and macros.
######################################################################################
#                               FUNCTIONS
# pi_collect_packagenames(<RESULT_NAME> [path1 path2 ...])
# pi_removesource(<VAR_NAME> <regex>)
# pi_hasmainfunc(<RESULT_NAME> source1 [source2 ...])
# pi_add_target(<name> <BIN | STATIC | SHARED> <src1|dir1> [src2 ...] [MODULES module1 ...] [REQUIRED module1 ...] [DEPENDENCY target1 ...])
# pi_add_targets([name1 ...])
# pi_report_target()
######################################################################################
#                               MACROS
# pi_collect_packages(<RESULT_NAME> [VERBOSE] [MODULES package1 ...] [REQUIRED package1 package2 ...])
# pi_check_modules(module1 [module2 ...])
# pi_report_modules(module1 [module2 ...])
# pi_install()
######################################################################################

cmake_minimum_required(VERSION 3.1)

if(NOT PICMAKE_LOADED)
	list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR})
	list(REMOVE_DUPLICATES CMAKE_MODULE_PATH)
endif(NOT PICMAKE_LOADED)

set(PI_CMAKE_VERSION "1.1.0")
set(PI_CMAKE_VERSION_MAJOR 1)
set(PI_CMAKE_VERSION_MINOR 1)
set(PI_CMAKE_VERSION_PATCH 0)

# pi_collect_packagenames(<RESULT_NAME> [path1 path2 ...])
function(pi_collect_packagenames RESULT_NAME)
	if(NOT ARGN)
		list(APPEND COLLECT_PATHS ${CMAKE_MODULE_PATH} ${CMAKE_ROOT}/Modules)
	else()
		set(COLLECT_PATHS ${ARGN})	
	endif()
	
	message("COLLECT_PATHS: ${COLLECT_PATHS}")

	foreach(COLLECT_PATH ${COLLECT_PATHS})
		file(GLOB PACKAGES RELATIVE ${COLLECT_PATH} ${COLLECT_PATH}/Find*.cmake)
		#message("PACKAGES: ${PACKAGES}")
		foreach(PACKAGE_PATH ${PACKAGES})
  		string(REGEX MATCH "Find([a-z|A-Z|0-9]+).cmake" PACKAGE_NAME "${PACKAGE_PATH}")
  		set(PACKAGE_NAME "${CMAKE_MATCH_1}")
			list(APPEND COLLECT_PACKAGE_NAMES ${PACKAGE_NAME})
			#message("PACKAGE_PATH: ${PACKAGE_PATH}")
			#message("PACKAGE_NAME: ${PACKAGE_NAME}")
		endforeach()
	endforeach()

	list(REMOVE_DUPLICATES COLLECT_PACKAGE_NAMES)
	list(SORT COLLECT_PACKAGE_NAMES)
	set(${RESULT_NAME} ${COLLECT_PACKAGE_NAMES} PARENT_SCOPE)
endfunction()

# pi_removesource(<VAR_NAME> <regex>)
function(pi_removesource VAR_NAME regex)
	foreach(SRC_FILE ${${VAR_NAME}})
		string(REGEX MATCH "${regex}" SHOULDREMOVE ${SRC_FILE})
		if(SHOULDREMOVE)
			list(REMOVE_ITEM ${VAR_NAME} ${SRC_FILE})
		endif()
	endforeach()
  set(${VAR_NAME} ${${VAR_NAME}} PARENT_SCOPE)
endfunction()

# pi_hasmainfunc(<RESULT_NAME> source1 [source2 ...])
function(pi_hasmainfunc RESULT_NAME)
  foreach(SOURCE_FILE ${ARGN})
		get_filename_component(SRC_FILE_NAME ${SOURCE_FILE} NAME_WE)
    string(TOLOWER ${SRC_FILE_NAME} SRC_FILE_NAME)
		if(SRC_FILE_NAME STREQUAL "main")
      list(APPEND MAIN_FILES ${SOURCE_FILE})
		endif()
  endforeach()
  set(${RESULT_NAME} ${MAIN_FILES} PARENT_SCOPE)
endfunction()

# pi_add_target(<name> <BIN | STATIC | SHARED> <src1|dir1> [src2 ...] [MODULES module1 ...] [REQUIRED module1 ...] [DEPENDENCY target1 ...])
function(pi_add_target TARGET_NAME TARGET_TYPE)
  if(ARGC LESS 3)
    message("command 'add_target' need more than 3 arguments")
    return()
  endif(ARGC LESS 3)

  string(TOUPPER ${TARGET_TYPE} TARGET_TYPE)
  
  set(TARGET_SRCS )
  set(TARGET_MODULES )
  set(TARGET_REQUIRED )
  set(TARGET_COMPILEFLAGS)
  set(TARGET_LINKFLAGS)
  set(TARGET_DEFINITIONS)
  set(TARGET_DEPENDENCY)

  set(PARSE_STATUS "SRC")
  foreach(PARA ${ARGN})
    if(PARA STREQUAL "MODULES")
      set(PARSE_STATUS "MODULES")
    elseif(PARA STREQUAL "REQUIRED")
      set(PARSE_STATUS "REQUIRED")
    elseif(PARA STREQUAL "DEPENDENCY")
      set(PARSE_STATUS "DEPENDENCY")
    elseif(PARSE_STATUS STREQUAL "SRC")
      get_filename_component(ABSOLUTE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/${PARA}" ABSOLUTE)
      if(IS_DIRECTORY ${ABSOLUTE_PATH})
        file(GLOB_RECURSE PATH_SOURCE_FILES RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} ${PARA}/*.cpp ${PARA}/*.c ${PARA}/*.cc])
        #message("GLOB ${PATH_SOURCE_FILES} from ${PARA}")
        list(APPEND TARGET_SRCS ${PATH_SOURCE_FILES})
      else()
        list(APPEND TARGET_SRCS ${PARA})
      endif()
    elseif(PARSE_STATUS STREQUAL "MODULES")
      list(APPEND TARGET_MODULES ${PARA})
    elseif(PARSE_STATUS STREQUAL "REQUIRED")
      list(APPEND TARGET_REQUIRED ${PARA})
    elseif(PARSE_STATUS STREQUAL "DEPENDENCY")
      list(APPEND TARGET_DEPENDENCY ${PARA})
    else()
      message("PARSE_STATUS: ${PARSE_STATUS}, PARA: ${PARA}, failed to parse command add_target ${ARGV}")
    endif()
  endforeach()



  if(NOT TARGET_SRCS)
    message("add_target need at least 1 source file.")
    return()
  endif()

  if( NOT ((TARGET_TYPE STREQUAL "BIN") OR (TARGET_TYPE STREQUAL "STATIC") OR (TARGET_TYPE STREQUAL "SHARED")))
    message("TARGET_TYPE (${TARGET_TYPE}) should be BIN STATIC or SHARED")
  endif()

  foreach(MODULE_NAME ${TARGET_REQUIRED})
    string(TOUPPER ${MODULE_NAME} MODULE_NAME_UPPER)
    if(TARGET ${MODULE_NAME})
      #message("${MODULE_NAME} is a existed target")
      list(APPEND TARGET_LINKFLAGS ${MODULE_NAME})
    elseif(${MODULE_NAME_UPPER}_FOUND)
      list(APPEND TARGET_COMPILEFLAGS ${${MODULE_NAME_UPPER}_INCLUDES})
      list(APPEND TARGET_LINKFLAGS ${${MODULE_NAME_UPPER}_LIBRARIES})
      list(APPEND TARGET_DEFINITIONS ${${MODULE_NAME_UPPER}_DEFINITIONS})
    else()
      message("${TARGET_NAME} aborded since can't find dependency ${MODULE_NAME}.")
      return()
    endif()
  endforeach()
  
  foreach(MODULE_NAME ${TARGET_MODULES})
    string(TOUPPER ${MODULE_NAME} MODULE_NAME_UPPER)
    if(TARGET ${MODULE_NAME})
      #message("${MODULE_NAME} is a existed target")
      list(APPEND TARGET_LINKFLAGS ${MODULE_NAME})
    elseif(${MODULE_NAME_UPPER}_FOUND)
      list(APPEND TARGET_COMPILEFLAGS ${${MODULE_NAME_UPPER}_INCLUDES})
      list(APPEND TARGET_LINKFLAGS ${${MODULE_NAME_UPPER}_LIBRARIES})
      list(APPEND TARGET_DEFINITIONS ${${MODULE_NAME_UPPER}_DEFINITIONS})
    endif()
  endforeach()

	include_directories(${TARGET_COMPILEFLAGS})
  add_definitions(${TARGET_DEFINITIONS})

  if(TARGET_TYPE STREQUAL "BIN")
		set_property( GLOBAL APPEND PROPERTY APPS2COMPILE  " ${TARGET_NAME}")
		add_executable(${TARGET_NAME} ${CMAKE_CURRENT_SOURCE_DIR} ${TARGET_SRCS})
  elseif(TARGET_TYPE STREQUAL "STATIC")
    set_property( GLOBAL APPEND PROPERTY LIBS2COMPILE  " ${CMAKE_STATIC_LIBRARY_PREFIX}${TARGET_NAME}${CMAKE_STATIC_LIBRARY_SUFFIX}")
		add_library(${TARGET_NAME} STATIC ${CMAKE_CURRENT_SOURCE_DIR} ${TARGET_SRCS})
  elseif(TARGET_TYPE STREQUAL "SHARED")
		set_property( GLOBAL APPEND PROPERTY LIBS2COMPILE  " ${CMAKE_SHARED_LIBRARY_PREFIX}${TARGET_NAME}${CMAKE_SHARED_LIBRARY_SUFFIX}")
		add_library(${TARGET_NAME} SHARED ${CMAKE_CURRENT_SOURCE_DIR} ${TARGET_SRCS})
    #message("add_library(${TARGET_NAME} SHARED ${CMAKE_CURRENT_SOURCE_DIR} ${TARGET_SRCS})")
  else()
    message("add_target(TARGET_TYPE ${TARGET_TYPE}): THIS SHOULD NEVER HAPPEN!")
    return()
  endif()

  #message("ARGV: ${ARGV}")
  #message("TARGET_NAME: ${TARGET_NAME}")
  #message("TARGET_SRCS: ${TARGET_SRCS}")
  #message("TARGET_TYPE: ${TARGET_TYPE}")
  #message("TARGET_MODULES: ${TARGET_MODULES}")
  #message("TARGET_REQUIRED: ${TARGET_REQUIRED}")
  #message("TARGET_COMPILEFLAGS: ${TARGET_COMPILEFLAGS}")

  target_link_libraries(${TARGET_NAME} ${TARGET_LINKFLAGS} ${TARGET_DEPENDENCY})
  list(APPEND TARGET_MODULES ${TARGET_REQUIRED})
	if("${TARGET_MODULES}" MATCHES "Qt|QT|qt")
      #message("Compile ${TARGET_NAME} with AUTOMOC (${TARGET_MODULES})")
			set_target_properties(${TARGET_NAME} PROPERTIES AUTOMOC TRUE)
	endif()

endfunction(pi_add_target)

# pi_add_targets([name1 ...])
# TARGET_NAME     -- TARGET_NAME  -- Folder name
# TARGET_SRCS     -- TARGET_SRCS  -- All source files below ${CMAKE_CURRENT_SOURCE_DIR}
# TARGET_TYPE     -- TARGET_TYPE|MAKE_TYPE    -- BIN STATIC SHARED
# TARGET_MODULES  -- TARGET_MODULES|MODULES      -- All packages available
# TARGET_REQUIRED -- TARGET_REQUIRED|REQUIRED
function(pi_add_targets )
  if(ARGC LESS 2)
    if(ARGC EQUAL 1)
      set(TARGET_NAME ${ARGV})
      #message("TARGET_NAME: ${TARGET_NAME}")
      if(TARGET_NAME STREQUAL "NO_TARGET")
        return()
      endif()
    elseif(NOT TARGET_NAME)
            get_filename_component(TARGET_NAME ${CMAKE_CURRENT_SOURCE_DIR} NAME)
            string(REPLACE " " "_" TARGET_NAME ${TARGET_NAME})
            #message("Use folder name target ${TARGET_NAME}")
    endif()

    if(NOT TARGET_SRCS)
      set(TARGET_SRCS ${SOURCE_FILES_ALL})
    endif()

    if(NOT TARGET_SRCS)
      file(GLOB_RECURSE TARGET_SRCS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} *.cpp *.c *.cc])
      #pi_removesource(TARGET_SRCS "CMakeFiles")
    endif()

    if(NOT TARGET_TYPE)
      set(TARGET_TYPE ${MAKE_TYPE})
    endif()

    if(NOT TARGET_TYPE)
      pi_hasmainfunc(MAIN_FILES ${TARGET_SRCS})
      if(MAIN_FILES)
        set(TARGET_TYPE BIN)
      elseif(BUILD_SHARED_LIBS)
        set(TARGET_TYPE SHARED)
      else()
        set(TARGET_TYPE STATIC)
      endif(MAIN_FILES)
    endif()

    if(NOT TARGET_MODULES)
      set(TARGET_MODULES ${MODULES})
    endif()
    #message("TARGET_TYPE: ${TARGET_TYPE}")

    pi_add_target(${TARGET_NAME} ${TARGET_TYPE} ${TARGET_SRCS} MODULES ${TARGET_MODULES} REQUIRED ${TARGET_REQUIRED})
    return()
  endif(ARGC LESS 2)

  foreach(TARGET_NAME ${ARGV})
    if(${TARGET_NAME}_SRCS)
      if(NOT ${TARGET_NAME}_TYPE)
        pi_hasmainfunc(MAIN_FILES ${${TARGET_NAME}_SRCS})
        if(MAIN_FILES)
          set(${TARGET_NAME}_TYPE BIN)
        else()
          set(${TARGET_NAME}_TYPE SHARED)
        endif()
        pi_add_target(${TARGET_NAME} ${${TARGET_NAME}_TYPE} ${${TARGET_NAME}_SRCS} MODULES ${${TARGET_NAME}_MODULES} REQUIRED ${${TARGET_NAME}_REQUIRED})
      endif()
    else()
      message("Target ${TARGET_NAME} aborded since no source file found.")
    endif()
  endforeach()


endfunction(pi_add_targets)


# pi_report_target()
function(pi_report_target )
	get_property(LIBS2COMPILE GLOBAL PROPERTY LIBS2COMPILE)
	get_property(APPS2COMPILE GLOBAL PROPERTY APPS2COMPILE)

	message(STATUS "The following targets will to be build:")
	message(STATUS "LIBS(${CMAKE_LIBRARY_OUTPUT_DIRECTORY}): ${LIBS2COMPILE}")
	message(STATUS "APPS(${CMAKE_RUNTIME_OUTPUT_DIRECTORY}): ${APPS2COMPILE}")
endfunction()

function(pi_report_targets)
  pi_report_target()
endfunction()


######################################################################################
#                               MACROS

# pi_collect_packages([RESULT_NAME] [VERBOSE] [MODULES package1 ...] [REQUIRED package1 package2 ...])
macro(pi_collect_packages)

  set(PARSE_STATUS "RESULT_NAME")
  
  foreach(PARA ${ARGN})
    if(PARA STREQUAL "VERBOSE")
      set(COLLECT_VERBOSE TRUE)
    elseif(PARA STREQUAL "MODULES")
      set(PARSE_STATUS MODULES)
    elseif(PARA STREQUAL "REQUIRED")
      set(PARSE_STATUS REQUIRED)
    elseif(PARSE_STATUS STREQUAL "RESULT_NAME")
      set(RESULT_NAME ${PARA})
    elseif(PARSE_STATUS STREQUAL "MODULES")
      list(APPEND COLLECT_MODULES ${PARA})
    elseif(PARSE_STATUS STREQUAL "REQUIRED")
      list(APPEND COLLECT_REQUIRED ${PARA})
    else()
      message("PARSE_STATUS: ${PARSE_STATUS}, PARA: ${PARA}, failed to parse command pi_collect_packages ${ARGV}")
    endif()
  endforeach()

  if( (NOT COLLECT_MODULES) AND (NOT COLLECT_REQUIRED) )
		pi_collect_packagenames(COLLECT_MODULES)
  endif()

  if(NOT COLLECT_VERBOSE)
    set(COLLECT_FLAGS QUIET)
  endif()

  foreach(PACKAGE_NAME ${COLLECT_REQUIRED})
    find_package(${PACKAGE_NAME} REQUIRED ${COLLECT_FLAGS})
  endforeach()
  
  foreach(PACKAGE_NAME ${COLLECT_MODULES})
    find_package(${PACKAGE_NAME} ${COLLECT_FLAGS})
  endforeach()

  list(APPEND COLLECT_MODULES ${COLLECT_REQUIRED})

  if(COLLECT_VERBOSE)
    pi_report_modules(${COLLECT_MODULES})
  else()
    pi_check_modules(${COLLECT_REQUIRED})
  endif()

  foreach(PACKAGE_NAME ${COLLECT_MODULES})
    string(TOUPPER ${PACKAGE_NAME} PACKAGE_NAME_UPPER)
    if(${PACKAGE_NAME_UPPER}_FOUND)
      list(APPEND ${RESULT_NAME} ${PACKAGE_NAME})
    endif()
  endforeach()
  
endmacro()

# pi_check_module_part(<module_name> <part_source> <part_target>)
macro(pi_check_module_part MODULE_NAME PART_SOURCE PART_TARGET)
  string(TOUPPER ${MODULE_NAME} MODULE_NAME_UPPER)
  if(NOT ${MODULE_NAME_UPPER}_${PART_TARGET})
    if(${MODULE_NAME}_${PART_SOURCE})
      set(${MODULE_NAME_UPPER}_${PART_TARGET} ${${MODULE_NAME}_${PART_SOURCE}})
    elseif(${MODULE_NAME}_${PART_TARGET})
      set(${MODULE_NAME_UPPER}_${PART_TARGET} ${${MODULE_NAME}_${PART_TARGET}})
    elseif(${MODULE_NAME_UPPER}_${PART_SOURCE})
      set(${MODULE_NAME_UPPER}_${PART_TARGET} ${${MODULE_NAME_UPPER}_${PART_SOURCE}})
    endif()
  endif()
endmacro()

# pi_check_modules(module1 [module2 ...])
macro(pi_check_modules)
  foreach(MODULE_NAME ${ARGV})
    pi_check_module_part(${MODULE_NAME} INCLUDE_DIR INCLUDES)
    pi_check_module_part(${MODULE_NAME} LIBS LIBRARIES)
    pi_check_module_part(${MODULE_NAME} LIBRARY LIBRARIES)
    pi_check_module_part(${MODULE_NAME} found FOUND)
    pi_check_module_part(${MODULE_NAME} version VERSION)
    pi_check_module_part(${MODULE_NAME} DEFINITIONS DEFINITIONS)
    if(${MODULE_NAME_UPPER}_FOUND)
      list(APPEND ${MODULE_NAME_UPPER}_DEFINITIONS -DHAS_${MODULE_NAME_UPPER})
      list(REMOVE_DUPLICATES ${MODULE_NAME_UPPER}_DEFINITIONS)
    endif()    
  endforeach()
endmacro()


#pi_report_modules(module1 [module2 ...])
macro(pi_report_modules)
	pi_check_modules(${ARGV})
	foreach(MODULE_NAME ${ARGV})
		message("--------------------------------------")
		string(TOUPPER ${MODULE_NAME} MODULE_NAME_UPPER)
		if(${MODULE_NAME_UPPER}_VERSION)
			message("--${MODULE_NAME}: VERSION ${${MODULE_NAME_UPPER}_VERSION}")
		else()
			message("--${MODULE_NAME}:")
		endif()

		if(${MODULE_NAME_UPPER}_INCLUDES)
			message("  ${MODULE_NAME_UPPER}_INCLUDES: ${${MODULE_NAME_UPPER}_INCLUDES}")
		endif()


		if(${MODULE_NAME_UPPER}_LIBRARIES)
			message("  ${MODULE_NAME_UPPER}_LIBRARIES: ${${MODULE_NAME_UPPER}_LIBRARIES}")
		endif()

		if(${MODULE_NAME_UPPER}_DEFINITIONS)
			message("  ${MODULE_NAME_UPPER}_DEFINITIONS: ${${MODULE_NAME_UPPER}_DEFINITIONS}")
		endif()

	endforeach()
endmacro()

##########################################################
#           THINGS GOING TO REMOVE! DO NOT USE!
macro(autosetMakeType)
	if(BUILD_SHARED_LIBS)
		set(MAKE_TYPE "shared")
	else()
		set(MAKE_TYPE "static")
	endif()

	pi_hasmainfunc(MAIN_FILES ${SOURCE_FILES_ALL})
	
	if(MAIN_FILES)
		set(MAKE_TYPE  "bin")
	endif()
endmacro()

# Results collection
macro(PIL_CHECK_DEPENDENCY LIBNAME)
	pi_check_modules(${LIBNAME})
endmacro()

macro(PIL_ECHO_LIBINFO LIBNAME)
	pi_report_modules(${LIBNAME})
endmacro()

# The following things is deprected
macro(filtSOURCE_FILES_ALL DIR)
  pi_removesource(SOURCE_FILES_ALL ${DIR})
endmacro()

macro(reportTargets)
  pi_report_target()
endmacro()


set(PICMAKE_UTILS_LOADED TRUE)
set(PICMAKE_LOADED TRUE)
