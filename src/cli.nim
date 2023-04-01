import
  std/os,
  std/strutils

import noise as nimnoise

import settingstype


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


proc runInteractivePrompt*: Settings =
  result.projectName = readLine("cmake version: ", "3.25")

  result.projectName = readLine("project name: ", getCurrentDir().lastPathPart())
  result.projectVersion = readLine("project version: ", "0.1.0")
  result.projectDesc = readLine("project desc: ")
  result.projectHomepage = readLine("project homepage: ")

  result.targetName = readLine("target name: ", result.projectName)

  # TODO: use promt list
  # https://github.com/nim-lang/nimble/blob/1339046c4424ae6237f66b24508eff234511a8bd/src/nimblepkg/cli.nim#L210
  result.targetType = completion(["exe", "shared-lib", "static-lib", "header-only"]):
    readLine("target type [exe, shared-lib, static-lib, header-only]: ", "exe")

  result.targetLanguage = completion(["C", "CXX"]):
    readLine("target languages [C, CXX]: ", "CXX")

  # std version
  # https://stackoverflow.com/questions/70667513/cmake-cxx-standard-vs-target-compile-features
  # https://cmake.org/cmake/help/latest/prop_gbl/CMAKE_C_KNOWN_FEATURES.html
  # https://cmake.org/cmake/help/latest/prop_gbl/CMAKE_CXX_KNOWN_FEATURES.html
  result.targetStandardVersion = case result.targetLanguage
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

  let useMingwInput = completion(["true", "false"]):
    readLine("use mingw: ", "false")
  result.useMingw = useMingwInput == "true"

  let useCpmInput = completion(["true", "false"]):
    readLine("use CPM: ", "true")
  result.useCpm = useCpmInput == "true"
