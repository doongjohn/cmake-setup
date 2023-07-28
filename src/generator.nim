import
  std/os,
  std/strutils,
  std/strformat,
  std/json

import puppy

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

  # generate `compile_commands.json` (only for make and ninja)
  # ln -s build/compile_commands.json compile_commands.json
  set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

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

  f.writeLine("""
  set_target_properties({settings.targetName}
    PROPERTIES # https://cmake.org/cmake/help/latest/manual/cmake-properties.7.html
    OUTPUT_NAME {settings.targetName})

  target_compile_features({settings.targetName}
    PRIVATE {settings.targetStandardVersion})

  # target_compile_definitions({settings.targetName}
  #   PRIVATE HELLO=1)
  """.fmt().dedent())

  if settings.targetType != "header-only":
    f.writeLine("""
    file(GLOB_RECURSE SRC_FILES
      src/*.{srcExt}
      src/*.{headerExt})
    target_sources({settings.targetName}
      PRIVATE ${{SRC_FILES}})

    # target_include_directories({settings.targetName}
    #   PRIVATE ${{PROJECT_SOURCE_DIR}}/include)

    # target_link_libraries({settings.targetName}
    #   library_name)
    """.fmt().dedent())
  else:
    f.writeLine("""
    # target_include_directories({settings.targetName}
    #   INTERFACE ${PROJECT_SOURCE_DIR}/include)
    """.dedent())

  # compiler and linker options
  f.writeLine("""
  if (CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
    target_compile_options({settings.targetName}
      PRIVATE
        # use colored output
        $<$<C_COMPILER_ID:GNU>:-fdiagnostics-color>
        $<$<C_COMPILER_ID:Clang>:-fcolor-diagnostics>
        $<$<CXX_COMPILER_ID:GNU>:-fdiagnostics-color>
        $<$<CXX_COMPILER_ID:Clang>:-fcolor-diagnostics>
        # more warnings
        -Wall -Wextra)

    if (NOT WIN32)
      # use sanitizers
      set(SANITIZER_OPTIONS
        $<$<CONFIG:Debug>:-fno-omit-frame-pointer>
        $<$<CONFIG:Debug>:-fno-sanitize-recover=all>
        $<$<CONFIG:Debug>:-fsanitize=address,undefined>)
      target_compile_options({settings.targetName}
        PRIVATE ${{SANITIZER_OPTIONS}})
      target_link_options({settings.targetName}
        PRIVATE ${{SANITIZER_OPTIONS}})
    endif()
  elseif (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
    # msvc compiler options: https://learn.microsoft.com/en-us/cpp/build/reference/compiler-options-listed-by-category
    target_compile_options({settings.targetName}
      PRIVATE
        # more warnings
        /W4 /sdl)

    # msvc linker options: https://learn.microsoft.com/en-us/cpp/build/reference/linker-options
    # target_link_options({settings.targetName}
    #   PRIVATE
    #     /VERBOSE)
  endif()
  """.fmt().dedent())
