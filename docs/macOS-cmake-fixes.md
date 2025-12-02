# macOS CMake Configuration Fixes

## Problem Summary

When running `cmake ..` in the build directory on macOS with Homebrew-installed dependencies, several errors occur due to:
1. Missing packages
2. Keg-only packages not in the default search path
3. Python version mismatch between installed packages and detected Python
4. macOS deployment target mismatch with newer Xcode SDKs
5. Missing module dependencies when building specific targets in Xcode

## Required Package Installations

```bash
# Install missing packages
brew install pybind11
brew install coin3d
brew install pivy

# Install med-file from FreeCAD tap (keg-only)
brew install freecad/freecad/med-file@4.1.1
```

## CMake Configuration

### With SetupHomebrew.cmake (Implemented)

After the CMake improvements, simply run:

```bash
mkdir build && cd build
cmake .. -G Xcode
```

The `SetupHomebrew.cmake` helper will automatically:
- Detect the Homebrew prefix (`/opt/homebrew` on Apple Silicon, `/usr/local` on Intel)
- Add keg-only packages (icu4c, med-file, python versions) to `CMAKE_PREFIX_PATH`
- Detect which Python version has pivy installed and use it
- Set `CMAKE_OSX_DEPLOYMENT_TARGET` to match your macOS version (prevents SDK mismatch errors)
- Pre-load libaec (required by HDF5/VTK)

### Manual Configuration (If Needed)

If auto-detection doesn't work, use:

```bash
cmake \
  -G Xcode \
  -DCMAKE_PREFIX_PATH="/opt/homebrew/opt/icu4c@78;/opt/homebrew/opt/med-file@4.1.1" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
  -DPython3_EXECUTABLE=/opt/homebrew/bin/python3.13 \
  ..
```

## Xcode Generator

For debugging in Xcode, use the Xcode generator:

```bash
cmake .. -G Xcode
```

Then open `build/FreeCAD.xcodeproj` in Xcode. Select `FreeCADMain` as the target and run/debug.

### Xcode Requirements

- Use full Xcode (not just Command Line Tools): `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
- The project is configured so building `FreeCADMain` automatically builds all required dependencies

## Warnings (Non-blocking)

The following warnings appear but do not prevent configuration:

- `ompi-cxx was not found` - OpenMPI C++ bindings (optional)
- `SWIG not found` - SWIG bindings for pivy (optional, pivy already installed)
- `Matplotlib not found` - Plot module won't be available
- `OpenMP not found` - Parallel processing optimizations disabled
- `Vulkan headers not found` - Vulkan rendering not available
- `3DconnexionNavlib not found` - 3D mouse support (optional, install driver if needed)

## Build

After successful cmake configuration:

```bash
# Command line build
cmake --build /path/to/FreeCAD/build

# Or with Xcode
xcodebuild -project build/FreeCAD.xcodeproj -target FreeCADMain -configuration Debug
```

---

## CMake Improvements Made

### New File: `cMake/FreeCAD_Helpers/SetupHomebrew.cmake`

A new CMake helper that provides:

1. **Auto-detection of Homebrew prefix**
   - `/opt/homebrew` on Apple Silicon (arm64)
   - `/usr/local` on Intel (x86_64)

2. **Automatic keg-only package discovery**
   - ICU (icu4c, icu4c@76, icu4c@77, icu4c@78)
   - med-file@4.1.1
   - Qt 5 (qt@5)
   - Python versions (python@3.11, python@3.12, python@3.13)

3. **Python/Pivy version alignment**
   - Scans for Python versions that have pivy installed
   - Automatically sets `Python3_EXECUTABLE` to match

4. **macOS Deployment Target**
   - Auto-detects your macOS version using `sw_vers`
   - Sets `CMAKE_OSX_DEPLOYMENT_TARGET` to prevent SDK mismatch errors when using newer Xcode

5. **HDF5/libaec workaround**
   - Pre-loads libaec with `find_package(libaec CONFIG)` before VTK/HDF5
   - Fixes "libaec::sz target not found" errors

### Modified File: `CMakeLists.txt`

Added call to `SetupHomebrew()` early in the configuration process, after `InitializeFreeCADBuildOptions()` but before any `find_package()` calls.

### Modified File: `src/Gui/CMakeLists.txt`

Added dependency from `FreeCADGui` to GUI resource data targets:

```cmake
add_dependencies(FreeCADGui
    Stylesheets_data
    PreferencePacks_data
    PreferencePackTemplates_data
)
```

This ensures stylesheets and icons are built when building FreeCADGui.

### Modified File: `src/CMakeLists.txt`

Added comprehensive dependencies from `FreeCADMain` to all module targets:

```cmake
# After all modules are defined, add dependencies to FreeCADMain
if(BUILD_GUI AND TARGET FreeCADMain)
    # GUI module libraries
    foreach(_target PartGui PartDesignGui SketcherGui MeshGui ...)
        if(TARGET ${_target})
            add_dependencies(FreeCADMain ${_target})
        endif()
    endforeach()
    
    # Python-only modules
    foreach(_target Draft BIM OpenSCAD AddonManager ...)
        ...
    endforeach()
    
    # Script targets (copy Init.py, InitGui.py, etc.)
    foreach(_target PartScripts PartDesignScripts ...)
        ...
    endforeach()
    
    # Material module data targets
    foreach(_target MaterialScripts MaterialLib AppearanceLib ...)
        ...
    endforeach()
endif()
```

This ensures that building `FreeCADMain` in Xcode automatically builds:
- All module GUI libraries (PartGui, SketcherGui, etc.)
- Python-only workbenches (Draft, BIM, etc.)
- Python scripts (Init.py, InitGui.py for each module)
- Material libraries and appearance data

### Modified File: `src/Mod/Assembly/CMakeLists.txt`

Fixed Xcode new build system duplicate command issue by adding explicit target dependency:

```cmake
add_dependencies(AssemblyTests AssemblyScripts)
```

### Benefits

- Users on macOS can now run `cmake .. -G Xcode` without manual configuration
- No need to specify `CMAKE_PREFIX_PATH` for keg-only packages
- Python version automatically matches the one with pivy installed
- Works on both Apple Silicon and Intel Macs
- Building `FreeCADMain` automatically builds ALL required targets:
  - Core libraries (FreeCADBase, FreeCADApp, FreeCADGui)
  - All workbench modules (Part, PartDesign, Sketcher, etc.)
  - All Python scripts and initialization files
  - All material and appearance data
  - All stylesheet and icon resources
- No more "Material not found" or missing icon errors at runtime
- Xcode debugging works out of the box
