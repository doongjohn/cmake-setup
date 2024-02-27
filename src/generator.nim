import std/os
import std/strutils
import std/strformat
import std/json
import pkg/puppy
import settingstype


proc generateCmakeListsTxt*(settings: Settings) =
  # download CPM.cmake
  if settings.useCpm:
    createDir("cmake")
    let cpmCmakeFile = open("cmake/CPM.cmake", fmWrite)
    defer: cpmCmakeFile.close()

    try:
      let cpmLatestRelease = parseJson(fetch("https://api.github.com/repos/cpm-cmake/CPM.cmake/releases/latest"))
      let cpmLatestVersion = cpmLatestRelease["tag_name"].getStr()
      let cpmDownloadUrl = cpmLatestRelease["assets"][0]["browser_download_url"].getStr()

      echo "download: CPM {cpmLatestVersion} ...".fmt()
      cpmCmakeFile.write(fetch(cpmDownloadUrl))
      echo "download: CPM {cpmLatestVersion} -> ./cmake/CPM.cmake"
    except:
      echo "Error: ", getCurrentExceptionMsg()

  # create CMakeLists.txt
  echo "output: CMakeLists.txt"
  let f = open("CMakeLists.txt", fmWrite)
  defer: f.close()

  f.writeLine("""
  cmake_minimum_required(VERSION {settings.cmakeVersion})

  set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
  set(CMAKE_COLOR_DIAGNOSTICS ON)

  project(
    {settings.projectName}
    VERSION {settings.projectVersion}
    DESCRIPTION "{settings.projectDesc}"
    HOMEPAGE_URL "{settings.projectHomepage}"
    LANGUAGES {settings.targetLanguage}
  )
  """.fmt().dedent())

  if settings.useCpm:
    f.writeLine("""
    include(cmake/CPM.cmake)
    # https://github.com/cpm-cmake/CPM.cmake/wiki/More-Snippets
    """.dedent())

  # create a target
  let srcExt = if settings.targetLanguage == "C": "c" else: "cpp"
  let headerExt = if settings.targetLanguage == "C": "h" else: "hpp"
  case settings.targetType
  of "exe":
    f.writeLine("""
    add_executable({settings.targetName} "")
    """.fmt().dedent())
  of "shared-lib":
    f.writeLine("""
    add_library({settings.targetName} SHARED "")
    """.fmt().dedent())
  of "static-lib":
    f.writeLine("""
    add_library({settings.targetName} STATIC "")
    """.fmt().dedent())
  of "header-only":
    f.writeLine("""
    add_library({settings.targetName} INTERFACE)
    """.dedent())

  if settings.targetType != "header-only":
    f.writeLine("""
    set_target_properties({settings.targetName}
      PROPERTIES
      OUTPUT_NAME {settings.targetName})

    target_compile_features({settings.targetName}
      PRIVATE {settings.targetStandardVersion})

    # use sanitizers
    if (NOT WIN32 AND CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
      set(SANITIZER_OPTIONS
        $<$<CONFIG:Debug>:-fno-omit-frame-pointer>
        $<$<CONFIG:Debug>:-fno-sanitize-recover=all>
        $<$<CONFIG:Debug>:-fsanitize=address,undefined>)
      target_compile_options(example-app PRIVATE ${{SANITIZER_OPTIONS}})
      target_link_options(example-app PRIVATE ${{SANITIZER_OPTIONS}})
    endif()

    # target_include_directories({settings.targetName}
    #   PRIVATE ${{PROJECT_SOURCE_DIR}}/include)

    # target_compile_definitions({settings.targetName}
    #   PRIVATE HELLO=1)
    """.fmt().dedent())
  else:
    f.writeLine("""
    # target_include_directories({settings.targetName}
    #   INTERFACE ${PROJECT_SOURCE_DIR}/include)

    # target_compile_definitions({settings.targetName}
    #   INTERFACE HELLO=1)
    """.dedent())

  if settings.targetType != "header-only":
    f.writeLine("""
    file(GLOB_RECURSE SOURCES
      src/*.{srcExt}
      src/*.{headerExt})
    target_sources({settings.targetName}
      PRIVATE ${{SOURCES}})

    # target_link_libraries({settings.targetName}
    #   library_name)

    if (CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
      target_compile_options({settings.targetName}
        # more warnings
        PRIVATE -Wall
        PRIVATE -Wextra)
    endif()
    if (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
      target_compile_options({settings.targetName}
        # more warnings
        PRIVATE /Wall
        PRIVATE /sdl)
    endif()
    """.fmt().dedent())
