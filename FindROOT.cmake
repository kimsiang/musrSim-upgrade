# - Find a ROOT installation
#
# Locates ROOT via the root-config script and defines the variables the
# FairRoot-derived build files expect.
#
#   ROOT_FOUND              TRUE if a usable ROOT was found
#   ROOT_VERSION            full version string as reported by root-config
#   ROOT_VERSION_MAJOR/MINOR/PATCH
#   ROOT_VERSION_NUMBER     major*10000 + minor*100 + patch, for comparisons
#   ROOT_CONFIG_EXECUTABLE  path to root-config
#   ROOT_INCLUDE_DIR        header directory   (also ROOT_INCLUDES, ROOT_INCLUDE_DIRS)
#   ROOT_LIBRARY_DIR        library directory  (also ROOT_LIBRARY_DIRS)
#   ROOT_LIBRARIES          link flags from `root-config --glibs`
#   ROOT_BINARY_DIR         bin directory
#   ROOT_CINT_EXECUTABLE    rootcling (or rootcint on ROOT 5)
#   ROOTSYS                 installation prefix
#
# Honours ROOT_MIN_VERSION (accepts "6.24/00" or "6.24.00") and the standard
# find_package(ROOT 6.24 ...) version argument.
#
# ---------------------------------------------------------------------------
# NOTE: ROOT >= 6.10 ships its own CMake package configuration. Prefer
#
#     find_package(ROOT 6.24 REQUIRED CONFIG COMPONENTS Core RIO Hist Tree)
#     target_link_libraries(myapp PRIVATE ROOT::Core ROOT::RIO ...)
#
# which gives you imported targets with correct include dirs, the C++ standard
# ROOT was built with, and per-component linking. This module exists only for
# older build files that cannot be migrated yet.
# ---------------------------------------------------------------------------
#
# Originally F.Uhlig@gsi.de (fairroot.gsi.de). Repaired for ROOT >= 6.32 and
# CMake >= 3.5.

set(ROOT_DEFINITIONS "")
set(ROOT_INSTALLED_VERSION_TOO_OLD FALSE)

#----------------------------------------------------------------------------
# Locate root-config.
#
# The original searched ONLY ${SIMPATH}/tools/root/bin and $ENV{ROOTSYS}/bin
# with NO_DEFAULT_PATH, so a ROOT that was on PATH but without ROOTSYS set
# (Homebrew, system packages, LCG views) was reported as missing. Try the
# explicit locations first, then fall back to PATH.
#----------------------------------------------------------------------------
find_program(ROOT_CONFIG_EXECUTABLE
  NAMES root-config
  HINTS ${SIMPATH}/tools/root/bin
        $ENV{ROOTSYS}/bin
        ${ROOTSYS}/bin
  DOC "Path to the root-config script"
)

if(NOT ROOT_CONFIG_EXECUTABLE)
  set(ROOT_FOUND FALSE)
  if(ROOT_FIND_REQUIRED)
    message(FATAL_ERROR
      "ROOT not found. Set ROOTSYS, put root-config on PATH (e.g. by sourcing "
      "thisroot.sh), or pass -DROOT_CONFIG_EXECUTABLE=/path/to/root-config.")
  endif()
  return()
endif()

# Derive ROOTSYS from <prefix>/bin/root-config
get_filename_component(_root_bin_dir ${ROOT_CONFIG_EXECUTABLE} DIRECTORY)
get_filename_component(ROOTSYS ${_root_bin_dir} DIRECTORY)
set(ENV{ROOTSYS} ${ROOTSYS})

#----------------------------------------------------------------------------
# Helper: run root-config with one argument.
# execute_process replaces EXEC_PROGRAM, which is deprecated since CMake 3.0
# and REMOVED in CMake 4.0 - the original module cannot configure at all there.
#----------------------------------------------------------------------------
function(_root_config _arg _outvar)
  execute_process(
    COMMAND ${ROOT_CONFIG_EXECUTABLE} --${_arg}
    OUTPUT_VARIABLE _out
    ERROR_VARIABLE  _err
    RESULT_VARIABLE _res
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  if(NOT _res EQUAL 0)
    message(FATAL_ERROR "\"${ROOT_CONFIG_EXECUTABLE} --${_arg}\" failed (${_res}): ${_err}")
  endif()
  set(${_outvar} "${_out}" PARENT_SCOPE)
endfunction()

_root_config(version ROOT_VERSION)
set(ROOTVERSION ${ROOT_VERSION})   # legacy alias

#----------------------------------------------------------------------------
# Parse the version.
#
# THIS IS THE BUG THAT BROKE ON ROOT 6.32+.
#
# The original used three regexes hard-coded to the legacy "6.34/06" form
# (a slash before the patch level). ROOT >= 6.32 reports plain semver,
# "6.34.06". string(REGEX REPLACE) returns its INPUT UNCHANGED when the
# pattern does not match - it does not error, it does not empty the variable -
# so all three components silently became the string "6.34.06", and the next
# line expanded to
#
#     MATH(EXPR found_vers "6.34.06*10000 + 6.34.06*100 + 6.34.06")
#
# hence "MATH cannot parse the expression ... unexpected exp_NUMBER".
#
# [./] accepts either separator. The trailing capture tolerates suffixes such
# as "6.36.00-rc1".
#----------------------------------------------------------------------------
set(_root_version_re "^([0-9]+)[./]0*([0-9]+)[./]0*([0-9]+)")

if(NOT ROOT_VERSION MATCHES "${_root_version_re}")
  message(FATAL_ERROR
    "Could not parse the ROOT version string \"${ROOT_VERSION}\" reported by "
    "${ROOT_CONFIG_EXECUTABLE}. Expected something like 6.34.06 or 6.34/06.")
endif()

# Leading zeros are stripped by the 0* in the regex above: MATH() would
# otherwise be handed "06", and a leading zero is not portable across the
# CMake versions this module has to run on.
set(ROOT_VERSION_MAJOR ${CMAKE_MATCH_1})
set(ROOT_VERSION_MINOR ${CMAKE_MATCH_2})
set(ROOT_VERSION_PATCH ${CMAKE_MATCH_3})

# Guard against an all-zero minor/patch being emptied by the 0* strip.
foreach(_c MAJOR MINOR PATCH)
  if(NOT ROOT_VERSION_${_c})
    set(ROOT_VERSION_${_c} 0)
  endif()
endforeach()

math(EXPR ROOT_VERSION_NUMBER
  "${ROOT_VERSION_MAJOR}*10000 + ${ROOT_VERSION_MINOR}*100 + ${ROOT_VERSION_PATCH}")

# Normalised dotted form, for VERSION_LESS style comparisons.
set(ROOT_VERSION_STRING
  "${ROOT_VERSION_MAJOR}.${ROOT_VERSION_MINOR}.${ROOT_VERSION_PATCH}")

#----------------------------------------------------------------------------
# Minimum version check. Accepts either separator in ROOT_MIN_VERSION, and
# also honours a version passed to find_package(ROOT <ver>).
#----------------------------------------------------------------------------
if(NOT ROOT_MIN_VERSION)
  if(ROOT_FIND_VERSION)
    set(ROOT_MIN_VERSION ${ROOT_FIND_VERSION})
  else()
    set(ROOT_MIN_VERSION "6.00.00")
  endif()
endif()

if(ROOT_MIN_VERSION MATCHES "^([0-9]+)[./]0*([0-9]*)[./]?0*([0-9]*)")
  set(_req_major ${CMAKE_MATCH_1})
  set(_req_minor ${CMAKE_MATCH_2})
  set(_req_patch ${CMAKE_MATCH_3})
  foreach(_v _req_major _req_minor _req_patch)
    if(NOT ${_v})
      set(${_v} 0)
    endif()
  endforeach()
else()
  message(FATAL_ERROR "Cannot parse ROOT_MIN_VERSION \"${ROOT_MIN_VERSION}\".")
endif()

math(EXPR _req_version_number "${_req_major}*10000 + ${_req_minor}*100 + ${_req_patch}")

if(ROOT_VERSION_NUMBER LESS _req_version_number)
  set(ROOT_FOUND FALSE)
  set(ROOT_INSTALLED_VERSION_TOO_OLD TRUE)
  message(WARNING
    "ROOT ${ROOT_VERSION} found at ${ROOTSYS}, but at least "
    "${ROOT_MIN_VERSION} is required.")
  if(ROOT_FIND_REQUIRED)
    message(FATAL_ERROR "ROOT version too old.")
  endif()
  return()
endif()

set(ROOT_FOUND TRUE)

#----------------------------------------------------------------------------
# Query the rest of the configuration.
#----------------------------------------------------------------------------
_root_config(libdir ROOT_LIBRARY_DIR)
_root_config(bindir ROOT_BINARY_DIR)
_root_config(incdir ROOT_INCLUDE_DIR)
_root_config(glibs  ROOT_LIBRARIES)

if(NOT EXISTS "${ROOT_LIBRARY_DIR}")
  message(WARNING
    "root-config reports the library directory as \"${ROOT_LIBRARY_DIR}\", "
    "but that path does not exist - the ROOT installation looks broken.")
endif()

# Aliases used by different generations of the surrounding build files.
set(ROOT_INCLUDES     ${ROOT_INCLUDE_DIR})
set(ROOT_INCLUDE_DIRS ${ROOT_INCLUDE_DIR})
set(ROOT_LIBRARY_DIRS ${ROOT_LIBRARY_DIR})

# The C++ standard ROOT was built with. Mixing standards between ROOT, Geant4
# and the application is a common source of link-time and ABI failures, so
# expose it for the caller to check. --cxxstandard exists from ROOT 6.10.
execute_process(
  COMMAND ${ROOT_CONFIG_EXECUTABLE} --cxxstandard
  OUTPUT_VARIABLE ROOT_CXX_STANDARD
  ERROR_QUIET
  RESULT_VARIABLE _std_res
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
if(NOT _std_res EQUAL 0)
  set(ROOT_CXX_STANDARD "")
endif()

mark_as_advanced(ROOT_CONFIG_EXECUTABLE ROOT_LIBRARY_DIR ROOT_INCLUDE_DIR ROOT_DEFINITIONS)

#----------------------------------------------------------------------------
# Dictionary generator.
#
# rootcint was the ROOT 5 tool. ROOT 6 replaced it with rootcling and dropped
# rootcint entirely in 6.20, so searching only for rootcint left
# ROOT_CINT_EXECUTABLE as NOTFOUND and any dictionary rule silently broken.
#----------------------------------------------------------------------------
find_program(ROOT_CINT_EXECUTABLE
  NAMES rootcling rootcint
  HINTS ${ROOT_BINARY_DIR}
  NO_DEFAULT_PATH
)

if(NOT ROOT_CINT_EXECUTABLE)
  message(STATUS "FindROOT: neither rootcling nor rootcint found in ${ROOT_BINARY_DIR}; "
                 "dictionary generation will not be available.")
endif()

if(NOT ROOT_FIND_QUIETLY)
  message(STATUS "Found ROOT ${ROOT_VERSION} in ${ROOTSYS}")
  if(ROOT_CXX_STANDARD)
    message(STATUS "  ROOT was built with C++${ROOT_CXX_STANDARD}")
  endif()
endif()

#----------------------------------------------------------------------------
# ROOT_GENERATE_DICTIONARY_LEGACY(<headers> <LinkDef> <output.cxx> <include dirs>)
#
# Renamed from ROOT_GENERATE_DICTIONARY: ROOT's own RootMacros.cmake defines a
# macro of that name with a different signature, and whichever was included
# last used to win silently. If you have ROOT's CMake package available, use
# its ROOT_GENERATE_DICTIONARY instead of this.
#----------------------------------------------------------------------------
macro(ROOT_GENERATE_DICTIONARY_LEGACY INFILES LINKDEF_FILE OUTFILE INCLUDE_DIRS_IN)
  set(_include_flags)
  foreach(_dir ${INCLUDE_DIRS_IN})
    list(APPEND _include_flags -I${_dir})
  endforeach()

  # Companion header/pcm sitting next to the generated source.
  string(REGEX REPLACE "^(.*)\\.[^.]*$" "\\1.h" _outfile_header "${OUTFILE}")

  add_custom_command(
    OUTPUT  ${OUTFILE} ${_outfile_header}
    COMMAND ${CMAKE_COMMAND} -E env
            ROOTSYS=${ROOTSYS}
            LD_LIBRARY_PATH=${ROOT_LIBRARY_DIR}:$ENV{LD_LIBRARY_PATH}
            DYLD_LIBRARY_PATH=${ROOT_LIBRARY_DIR}:$ENV{DYLD_LIBRARY_PATH}
            ${ROOT_CINT_EXECUTABLE} -f ${OUTFILE}
            ${_include_flags} ${INFILES} ${LINKDEF_FILE}
    DEPENDS ${INFILES} ${LINKDEF_FILE}
    COMMENT "Generating ROOT dictionary ${OUTFILE}"
  )
endmacro()

# The original also defined GENERATE_ROOT_TEST_SCRIPT, which called an
# undefined macro (CONVERT_LIST_TO_STRING) and configure_file'd template
# scripts under cmake/scripts/ that are not part of this project. It was dead
# and unusable, so it has been dropped rather than left as a trap.
