# SPDX-License-Identifier: LGPL-2.1-or-later

add_subdirectory(Build)
add_subdirectory(3rdParty)
add_subdirectory(Base)
add_subdirectory(App)
add_subdirectory(Main)
add_subdirectory(Mod)
add_subdirectory(Ext)
add_subdirectory(Doc)

if(BUILD_GUI)
    add_subdirectory(Gui)
    if(UNIX AND NOT APPLE)
        add_subdirectory(XDGData)
    endif()
endif(BUILD_GUI)

if(BUILD_TEMPLATE)
    add_subdirectory(Tools/_TEMPLATE_)
endif(BUILD_TEMPLATE)

# "if" clause moved into local CMakeLists.txt file to support Conda and Homebrew builds
add_subdirectory(MacAppBundle)

# Add dependencies from FreeCADMain to all enabled module GUI libraries
# This ensures building FreeCADMain also builds all modules (needed for Xcode, etc.)
if(BUILD_GUI AND TARGET FreeCADMain)
    set(FREECAD_MODULE_TARGETS "")
    
    # Check for each module's GUI target and add as dependency if it exists
    foreach(_target 
        PartGui PartDesignGui SketcherGui MeshGui MeshPartGui PointsGui
        AssemblyGui TechDrawGui FemGui PathGui SpreadsheetGui SurfaceGui
        ImportGui InspectionGui MatGui ReverseEngineeringGui RobotGui
        StartGui WebGui MeasureGui CloudGui)
        if(TARGET ${_target})
            list(APPEND FREECAD_MODULE_TARGETS ${_target})
        endif()
    endforeach()
    
    # Add Python-only modules that are custom targets
    foreach(_target Draft BIM OpenSCAD AddonManager Test Tux Plot Help Show Idf)
        if(TARGET ${_target})
            list(APPEND FREECAD_MODULE_TARGETS ${_target})
        endif()
    endforeach()
    
    # Add script targets that copy Python files (Init.py, InitGui.py, etc.)
    foreach(_target
        PartScripts PartDesignScripts SketcherScripts MeshScripts PointsScripts
        SurfaceScripts SpreadsheetScripts StartScripts WebScripts RobotScripts
        ImportScripts CloudScripts MeasureScripts ReverseEngineeringScripts
        PartDesignHole)
        if(TARGET ${_target})
            list(APPEND FREECAD_MODULE_TARGETS ${_target})
        endif()
    endforeach()
    
    # Add Material module data targets (material libraries, models, etc.)
    foreach(_target
        MaterialScripts MaterialLib FluidMaterialLib AppearanceLib PatternLib
        MaterialModelLib MachiningLib MaterialToolsLib MaterialsAPILib)
        if(TARGET ${_target})
            list(APPEND FREECAD_MODULE_TARGETS ${_target})
        endif()
    endforeach()
    
    if(FREECAD_MODULE_TARGETS)
        add_dependencies(FreeCADMain ${FREECAD_MODULE_TARGETS})
        message(STATUS "FreeCADMain depends on: ${FREECAD_MODULE_TARGETS}")
    endif()
endif()

