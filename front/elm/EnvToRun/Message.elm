module EnvToRun.Message exposing (..)

type Msg
  = PromptKey Int String
  | PromptValue Int String
  | AddNewInput
  | DeleteKeyValue Int