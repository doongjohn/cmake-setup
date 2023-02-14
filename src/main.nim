import std/os

import
  cli,
  generator


# More Modern CMake
# https://hsf-training.github.io/hsf-training-cmake-webpage/index.html
# https://www.youtube.com/watch?v=y7ndUhdQuU8

# Effective Modern CMake
# https://gist.github.com/mbinna/c61dbb39bca0e4fb7d1f73b0d66a4fd1

# cmake build types
# https://blog.feabhas.com/2021/07/cmake-part-2-release-and-debug-builds/

# cmake generator expression
# https://junstar92.tistory.com/214


proc main =
  if fileExists("CMakeLists.txt"):
    echo "CMakeLists.txt already exists!"
    return

  let settings = runInteractivePrompt()
  generateCmakelistsTxt(settings)


main()
