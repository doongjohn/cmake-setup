import
  std/os,
  std/strutils,
  std/strformat,
  std/json

import
  noise as nimnoise,
  puppy


# Effective Modern CMake
# https://gist.github.com/mbinna/c61dbb39bca0e4fb7d1f73b0d66a4fd1

# LEARN: cmake build type
# https://blog.feabhas.com/2021/07/cmake-part-2-release-and-debug-builds/
# https://stackoverflow.com/questions/7724569/debug-vs-release-in-cmake

# LEARN: cmake generator expression
# https://stackoverflow.com/questions/58729233/what-is-the-use-case-for-generator-expression-on-target-include-directories


var noise = Noise.init()


proc readLine(prompt: string, preload: string = ""): string =
  noise.setPrompt(Styler.init(fgGreen, prompt))
  noise.preloadBuffer(preload)
  if not noise.readLine():
    quit(1)
  noise.getLine()


template completion(list: openArray[string], body: untyped): string =
  block:
    noise.setCompletionHook(proc (_: var Noise, text: string): int =
      for w in list:
        if w.find(text) != -1:
          noise.addCompletion w
    )
    defer: noise.setCompletionHook(nil)
    body


proc main =
  if fileExists("CMakeLists.txt"):
    echo "CMakeLists.txt already exists!"
    return

  let projectName = readLine("project name: ", getCurrentDir().lastPathPart())
  let projectVersion = readLine("project version: ", "0.1.0")
  let projectDesc = readLine("project desc: ")
  let projectHomepage = readLine("project homepage: ")

  let targetName = readLine("target name: ", projectName)

  # TODO: use promt list
  # https://github.com/nim-lang/nimble/blob/1339046c4424ae6237f66b24508eff234511a8bd/src/nimblepkg/cli.nim
  let targetType = completion(["exe", "shared-lib", "static-lib", "header-only"]):
    readLine("target type [exe, shared-lib, static-lib, header-only]: ", "exe")

  let targetLanguage = completion(["C", "CXX"]):
    readLine("target languages [C, CXX]: ", "CXX")

  let srcExtension = if targetLanguage == "CXX": "cpp" else: "c"

  # std version
  # https://stackoverflow.com/questions/70667513/cmake-cxx-standard-vs-target-compile-features
  # https://cmake.org/cmake/help/latest/prop_gbl/CMAKE_C_KNOWN_FEATURES.html
  # https://cmake.org/cmake/help/latest/prop_gbl/CMAKE_CXX_KNOWN_FEATURES.html
  let targetStandardVersion = case targetLanguage
  of "C":
    completion([
      "c_std_90",
      "c_std_99",
      "c_std_11",
      "c_std_17",
      "c_std_23",
    ]):
      readLine("target std version: ", "c_std_17")
  of "CXX":
    completion([
      "cxx_std_98",
      "cxx_std_11",
      "cxx_std_14",
      "cxx_std_17",
      "cxx_std_20",
      "cxx_std_23",
      "cxx_std_26",
    ]):
      readLine("target std version: ", "cxx_std_20")
  else:
    ""

  let useMingw = completion(["true", "false"]):
    readLine("use mingw: ", "false")

  let useCpm = completion(["true", "false"]):
    readLine("use CPM: ", "true")

  if useCpm == "true":
    createDir("cmake")
    let cpmCmakeFile = open("cmake/CPM.cmake", fmWrite)
    defer: cpmCmakeFile.close()
    let latestReleaseJson = parseJson(fetch("https://api.github.com/repos/cpm-cmake/CPM.cmake/releases/latest"))
    let cpmLatestVersion = latestReleaseJson["tag_name"].getStr()
    let cpmDownloadUrl = latestReleaseJson["assets"][0]["browser_download_url"].getStr()
    echo "download: CPM {cpmLatestVersion}".fmt
    cpmCmakeFile.write(fetch(cpmDownloadUrl))

  echo "output: CMakeLists.txt"
  let f = open("CMakeLists.txt", fmWrite)
  defer: f.close()

  f.writeLine("""
  cmake_minimum_required(VERSION 3.25)

  # generate compile_commands.json
  set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
  """.fmt.dedent)

  if useMingw == "true":
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
    """.dedent)

  f.writeLine("""
  project(
    {projectName}
    VERSION {projectVersion}
    DESCRIPTION "{projectDesc}"
    HOMEPAGE_URL "{projectHomepage}"
    LANGUAGES {targetLanguage}
  )
  """.fmt.dedent)

  if useCpm == "true":
    f.writeLine("""
    include(cmake/CPM.cmake)
    # https://github.com/cpm-cmake/CPM.cmake/wiki/More-Snippets
    """.dedent)

  f.writeLine("set(TARGET_NAME {targetName})\n".fmt)

  case targetType
  of "exe":
    f.writeLine("""
    file(GLOB_RECURSE SRC_FILES src/*.{srcExtension})
    add_executable(${{TARGET_NAME}} ${{SRC_FILES}})
    """.fmt.dedent)
  of "shared-lib":
    f.writeLine("""
    file(GLOB_RECURSE SRC_FILES src/*.{srcExtension})
    add_library(${{TARGET_NAME}} ${{SRC_FILES}})
    """.fmt.dedent)
  of "static-lib":
    f.writeLine("""
    file(GLOB_RECURSE SRC_FILES src/*.{srcExtension})
    add_library(${{TARGET_NAME}} STATIC ${{SRC_FILES}})
    """.fmt.dedent)
  of "header-only":
    f.writeLine("""
    add_library(${TARGET_NAME} INTERFACE)
    """.dedent)

  f.writeLine("""
  target_compile_features(${{TARGET_NAME}}
    PRIVATE {targetStandardVersion})
  """.fmt.dedent)

  f.writeLine("""
  target_compile_options(${TARGET_NAME}
    PRIVATE -fno-omit-frame-pointer
    PRIVATE -fno-sanitize-recover=all
    PRIVATE -fsanitize=address,undefined)

  target_link_options(${TARGET_NAME}
    PRIVATE -fno-omit-frame-pointer
    PRIVATE -fno-sanitize-recover=all
    PRIVATE -fsanitize=address,undefined)
  """.dedent)

  case targetType
  of "header-only":
    f.writeLine("""
    # target_include_directories(${TARGET_NAME}
    #   INTERFACE ${PROJECT_SOURCE_DIR}/include)
    """.dedent)
  else:
    f.writeLine("""
    # target_include_directories(${TARGET_NAME}
    #   PRIVATE ${PROJECT_SOURCE_DIR}/include)
    """.dedent)

  f.writeLine("""
  # target_link_libraries(${TARGET_NAME}
  #   library_name)
  """.dedent)


main()
