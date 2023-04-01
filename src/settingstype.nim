type
  Settings* = object
    cmakeVersion*: string

    projectName*: string
    projectVersion*: string
    projectDesc*: string
    projectHomepage*: string

    targetName*: string
    targetType*: string
    targetLanguage*: string
    targetStandardVersion*: string

    useMingw*: bool
    useCpm*: bool
