import
  std/os,
  std/strutils,
  std/strformat,
  std/json

import puppy

import settingstype


proc generateCmakelistsTxt*(settings: Settings) =
  if settings.useCpm:
    createDir("cmake")
    let cpmCmakeFile = open("cmake/CPM.cmake", fmWrite)
    defer: cpmCmakeFile.close()

    let latestReleaseJson = parseJson(fetch("https://api.github.com/repos/cpm-cmake/CPM.cmake/releases/latest"))
    let cpmLatestVersion = latestReleaseJson["tag_name"].getStr()
    let cpmDownloadUrl = latestReleaseJson["assets"][0]["browser_download_url"].getStr()

    echo "download: CPM {cpmLatestVersion} -> ./cmake/CPM.cmake".fmt()
    cpmCmakeFile.write(fetch(cpmDownloadUrl))

  echo "output: CMakeLists.txt"
  let f = open("CMakeLists.txt", fmWrite)
  defer: f.close()

  f.writeLine("""
  cmake_minimum_required(VERSION 3.25)

  # generate compile_commands.json
  set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
  """.dedent())

  # TODO: make mingw path configurable
  if settings.useMingw:
    f.writeLine("""
    # set target operating to windows
    set(CMAKE_SYSTEM_NAME Windows)

    # set compiler to mingw
    set(CMAKE_C_COMPILER /usr/bin/x86_64-w64-mingw32-gcc)
    set(CMAKE_CXX_COMPILER /usr/bin/x86_64-w64-mingw32-g++)
    set(CMAKE_RC_COMPILER /usr/bin/x86_64-w64-mingw32-windres)

    # where is the target environment located
    set(CMAKE_FIND_ROOT_PATH /usr/x86_64-w64-mingw32)

    # adjust the default behavior of the FIND_XXX() commands:
    # search programs in the host environment
    set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)

    # search headers and libraries in the target environment
    set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
    set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
    """.dedent())

  f.writeLine("""
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

  # create target
  f.writeLine("set(TARGET_NAME {settings.targetName})\n".fmt())
  let srcExtension = if settings.targetLanguage == "C": "c" else: "cpp"
  case settings.targetType
  of "exe":
    f.writeLine("""
    file(GLOB_RECURSE SRC_FILES src/*.{srcExtension})
    add_executable(${{TARGET_NAME}} ${{SRC_FILES}})
    """.fmt().dedent())
  of "shared-lib":
    f.writeLine("""
    file(GLOB_RECURSE SRC_FILES src/*.{srcExtension})
    add_library(${{TARGET_NAME}} ${{SRC_FILES}})
    """.fmt().dedent())
  of "static-lib":
    f.writeLine("""
    file(GLOB_RECURSE SRC_FILES src/*.{srcExtension})
    add_library(${{TARGET_NAME}} STATIC ${{SRC_FILES}})
    """.fmt().dedent())
  of "header-only":
    f.writeLine("""
    add_library(${TARGET_NAME} INTERFACE)
    """.dedent())

  # set language standard
  f.writeLine("""
  target_compile_features(${{TARGET_NAME}}
    PRIVATE {settings.targetStandardVersion})
  """.fmt().dedent())

  # use sanitizers (only for debug build)
  f.writeLine("""
  target_compile_options(${TARGET_NAME}
    PRIVATE
      -Wall
      $<$<CONFIG:Debug>:-fno-omit-frame-pointer>
      $<$<CONFIG:Debug>:-fno-sanitize-recover=all>
      $<$<CONFIG:Debug>:-fsanitize=address,undefined>)

  target_link_options(${TARGET_NAME}
    PRIVATE
      -Wall
      $<$<CONFIG:Debug>:-fno-omit-frame-pointer>
      $<$<CONFIG:Debug>:-fno-sanitize-recover=all>
      $<$<CONFIG:Debug>:-fsanitize=address,undefined>)
  """.dedent())

  # include directories (commented)
  case settings.targetType
  of "header-only":
    f.writeLine("""
    # target_include_directories(${TARGET_NAME}
    #   INTERFACE ${PROJECT_SOURCE_DIR}/include)
    """.dedent())
  else:
    f.writeLine("""
    # target_include_directories(${TARGET_NAME}
    #   PRIVATE ${PROJECT_SOURCE_DIR}/include)
    """.dedent())

  # link libraries (commented)
  f.writeLine("""
  # target_link_libraries(${TARGET_NAME}
  #   library_name)
  """.dedent())
