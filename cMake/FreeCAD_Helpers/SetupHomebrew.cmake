# SetupHomebrew.cmake
# Auto-detect Homebrew installation and configure keg-only packages on macOS
#
# This macro should be called early in the CMake configuration process,
# before any find_package() calls that might need Homebrew packages.

macro(SetupHomebrew)
    if(APPLE)
        # Detect Homebrew prefix
        # Apple Silicon Macs use /opt/homebrew, Intel Macs use /usr/local
        if(NOT DEFINED HOMEBREW_PREFIX)
            execute_process(
                COMMAND brew --prefix
                OUTPUT_VARIABLE HOMEBREW_PREFIX
                OUTPUT_STRIP_TRAILING_WHITESPACE
                ERROR_QUIET
                RESULT_VARIABLE HOMEBREW_RESULT
            )
            if(NOT HOMEBREW_RESULT EQUAL 0)
                # Fallback detection based on architecture
                if(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "arm64")
                    set(HOMEBREW_PREFIX "/opt/homebrew")
                else()
                    set(HOMEBREW_PREFIX "/usr/local")
                endif()
                if(EXISTS "${HOMEBREW_PREFIX}/bin/brew")
                    message(STATUS "Homebrew detected at: ${HOMEBREW_PREFIX}")
                else()
                    set(HOMEBREW_PREFIX "")
                    message(STATUS "Homebrew not found")
                endif()
            else()
                message(STATUS "Homebrew detected at: ${HOMEBREW_PREFIX}")
            endif()
        endif()

        if(HOMEBREW_PREFIX)
            # Add Homebrew to prefix path if not already present
            if(NOT "${HOMEBREW_PREFIX}" IN_LIST CMAKE_PREFIX_PATH)
                list(APPEND CMAKE_PREFIX_PATH "${HOMEBREW_PREFIX}")
            endif()

            # List of known keg-only packages that FreeCAD may need
            # These are not symlinked into HOMEBREW_PREFIX by default
            set(FREECAD_HOMEBREW_KEG_ONLY_PACKAGES
                "icu4c"
                "icu4c@76"
                "icu4c@77"
                "icu4c@78"
                "med-file@4.1.1"
                "qt@5"
                "python@3.11"
                "python@3.12"
                "python@3.13"
            )

            # Auto-detect and add keg-only packages to CMAKE_PREFIX_PATH
            foreach(_pkg ${FREECAD_HOMEBREW_KEG_ONLY_PACKAGES})
                set(_pkg_path "${HOMEBREW_PREFIX}/opt/${_pkg}")
                if(EXISTS "${_pkg_path}" AND IS_DIRECTORY "${_pkg_path}")
                    if(NOT "${_pkg_path}" IN_LIST CMAKE_PREFIX_PATH)
                        list(APPEND CMAKE_PREFIX_PATH "${_pkg_path}")
                        message(STATUS "  Added keg-only package: ${_pkg}")
                    endif()
                endif()
            endforeach()

            # Detect Python version that has pivy installed (for GUI builds)
            if(BUILD_GUI AND NOT Python3_EXECUTABLE)
                set(_python_versions "3.13" "3.12" "3.11" "3.10")
                foreach(_pyver ${_python_versions})
                    set(_site_packages "${HOMEBREW_PREFIX}/lib/python${_pyver}/site-packages")
                    if(EXISTS "${_site_packages}/pivy")
                        set(_python_exec "${HOMEBREW_PREFIX}/bin/python${_pyver}")
                        if(EXISTS "${_python_exec}")
                            message(STATUS "  Found pivy for Python ${_pyver}, using: ${_python_exec}")
                            set(Python3_EXECUTABLE "${_python_exec}" CACHE FILEPATH "Python interpreter with pivy")
                            break()
                        endif()
                    endif()
                endforeach()
            endif()

            # Workaround for HDF5/libaec CMake target issue on Homebrew
            # HDF5's CMake config references libaec::sz but doesn't find_package(libaec) first
            # We need to find libaec before VTK/HDF5 are loaded
            if(EXISTS "${HOMEBREW_PREFIX}/lib/cmake/libaec")
                find_package(libaec CONFIG QUIET)
                if(libaec_FOUND)
                    message(STATUS "  Found libaec (required by HDF5)")
                endif()
            endif()

            # Set macOS deployment target if not already specified
            # This prevents issues when using a newer SDK (e.g., 26.0) on an older macOS version
            if(NOT CMAKE_OSX_DEPLOYMENT_TARGET)
                # Get the current macOS version
                execute_process(
                    COMMAND sw_vers -productVersion
                    OUTPUT_VARIABLE MACOS_VERSION
                    OUTPUT_STRIP_TRAILING_WHITESPACE
                    ERROR_QUIET
                )
                if(MACOS_VERSION)
                    # Extract major version (e.g., "15" from "15.7.1")
                    string(REGEX MATCH "^[0-9]+" MACOS_MAJOR_VERSION "${MACOS_VERSION}")
                    if(MACOS_MAJOR_VERSION)
                        set(CMAKE_OSX_DEPLOYMENT_TARGET "${MACOS_MAJOR_VERSION}.0" CACHE STRING "Minimum macOS deployment version")
                        message(STATUS "  Set deployment target: macOS ${CMAKE_OSX_DEPLOYMENT_TARGET}")
                    endif()
                endif()
            endif()

            # Store for later use
            set(HOMEBREW_PREFIX "${HOMEBREW_PREFIX}" CACHE PATH "Homebrew installation prefix")
        endif()
    endif()
endmacro(SetupHomebrew)
