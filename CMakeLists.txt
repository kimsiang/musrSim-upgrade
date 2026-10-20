#----------------------------------------------------------------------------
# Setup the project
cmake_minimum_required(VERSION 3.16...3.31)
project(musrSim_upgrade CXX)

#----------------------------------------------------------------------------
# Find ROOT (via root-config, see FindROOT.cmake)
include(${PROJECT_SOURCE_DIR}/FindROOT.cmake)

# Use the same C++ standard as ROOT was built with (at least C++17, required by Geant4 11)
set(CMAKE_CXX_STANDARD 17)
execute_process(COMMAND ${ROOT_CONFIG_EXECUTABLE} --cflags
                OUTPUT_VARIABLE _root_cflags OUTPUT_STRIP_TRAILING_WHITESPACE)
if(_root_cflags MATCHES "-std=(c|gnu)\\+\\+([0-9]+)" AND CMAKE_MATCH_2 GREATER 17)
  set(CMAKE_CXX_STANDARD ${CMAKE_MATCH_2})
endif()
set(CMAKE_CXX_STANDARD_REQUIRED ON)
message(STATUS "musrSim: using C++${CMAKE_CXX_STANDARD}")

#----------------------------------------------------------------------------
# Find Geant4 package, activating all available UI and Vis drivers by default.
# Set WITH_GEANT4_UIVIS to OFF to build a batch-mode-only executable.
option(WITH_GEANT4_UIVIS "Build with Geant4 UI and Vis drivers" ON)
if(WITH_GEANT4_UIVIS)
  find_package(Geant4 REQUIRED ui_all vis_all)
else()
  find_package(Geant4 REQUIRED)
endif()
include(${Geant4_USE_FILE})

include_directories(${PROJECT_SOURCE_DIR}/include
                    ${PROJECT_SOURCE_DIR}/src_cry
                    ${ROOT_INCLUDE_DIR})
link_directories(${ROOT_LIBRARY_DIR})

#----------------------------------------------------------------------------
# Directory holding the CRY cosmic-ray data tables (cosmics_*.data).
# Can be overridden at configure time (-DCRY_DATA_DIR=...) or at run time
# with the CRYDATAPATH environment variable.
set(CRY_DATA_DIR "${PROJECT_SOURCE_DIR}/cryData" CACHE PATH "Directory with CRY data files")

#----------------------------------------------------------------------------
# Sources and headers (headers are listed so they show up in IDEs)
file(GLOB sources ${PROJECT_SOURCE_DIR}/src/*.cc
                  ${PROJECT_SOURCE_DIR}/src/*.cpp
                  ${PROJECT_SOURCE_DIR}/src_cry/*.cc)
file(GLOB headers ${PROJECT_SOURCE_DIR}/include/*.hh
                  ${PROJECT_SOURCE_DIR}/include/*.h
                  ${PROJECT_SOURCE_DIR}/src_cry/*.hh
                  ${PROJECT_SOURCE_DIR}/src_cry/*.h)

#----------------------------------------------------------------------------
# Executable
add_executable(musrSim musrSim.cc ${sources} ${headers})
target_compile_definitions(musrSim PRIVATE CRY_DATA_DIR="${CRY_DATA_DIR}")
target_link_libraries(musrSim ${Geant4_LIBRARIES} ${ROOT_LIBRARIES})

#----------------------------------------------------------------------------
# Copy the macros and input tables from run/ to <build>/run, so the
# executable can be run directly from there (cd build/run; ../musrSim 101.mac).
file(GLOB run_files LIST_DIRECTORIES false ${PROJECT_SOURCE_DIR}/run/*)
foreach(_file ${run_files})
  get_filename_component(_name ${_file} NAME)
  configure_file(${_file} ${PROJECT_BINARY_DIR}/run/${_name} COPYONLY)
endforeach()

#----------------------------------------------------------------------------
# Install the executable to 'bin' directory under CMAKE_INSTALL_PREFIX
install(TARGETS musrSim DESTINATION bin)
