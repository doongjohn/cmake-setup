import std/os

import
  cli,
  generator


# Effective Modern CMake
# https://gist.github.com/mbinna/c61dbb39bca0e4fb7d1f73b0d66a4fd1

# LEARN: cmake build type
# https://blog.feabhas.com/2021/07/cmake-part-2-release-and-debug-builds/
# https://stackoverflow.com/questions/7724569/debug-vs-release-in-cmake

# LEARN: cmake generator expression
# https://stackoverflow.com/questions/58729233/what-is-the-use-case-for-generator-expression-on-target-include-directories


proc main =
  if fileExists("CMakeLists.txt"):
    echo "CMakeLists.txt already exists!"
    return

  let settings = runInteractivePrompt()
  generateCmakelistsTxt(settings)


main()
