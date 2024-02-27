import std/os
import cli
import generator


proc main =
  if fileExists("CMakeLists.txt"):
    echo "`CMakeLists.txt` already exists in this directory!"
    return

  let settings = runInteractivePrompt()
  generateCmakeListsTxt(settings)


main()
