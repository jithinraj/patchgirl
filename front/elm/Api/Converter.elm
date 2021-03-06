module Api.Converter exposing(..)

import Api.Generated as Back
import Application.Type exposing (..)
import Application.Type as Front
import Dict
import Uuid
import Tuple
import Animation


-- * request Collection


convertRequestCollectionFromBackToFront : Back.RequestCollection -> Front.RequestCollection
convertRequestCollectionFromBackToFront backRequestCollection =
    let
        (Back.RequestCollection id backRequestNodes) = backRequestCollection
    in
        Front.RequestCollection id (convertRequestNodesFromBackToFront backRequestNodes)

convertRequestNodesFromBackToFront : List Back.RequestNode -> List Front.RequestNode
convertRequestNodesFromBackToFront backRequestNodes =
    let
        convertRequestNodeFromBackToFront : Back.RequestNode -> Front.RequestNode
        convertRequestNodeFromBackToFront backRequestNode =
            case backRequestNode of
                Back.RequestFolder folder ->
                    Front.RequestFolder
                        { id = folder.requestNodeId
                        , name = NotEdited folder.requestNodeName
                        , open = not <| List.isEmpty folder.requestNodeChildren
                        , children = convertRequestNodesFromBackToFront folder.requestNodeChildren
                        }
                Back.RequestFile file ->
                    Front.RequestFile
                        { id = file.requestNodeId
                        , name = NotEdited file.requestNodeName
                        , httpUrl = NotEdited file.requestNodeHttpUrl
                        , httpMethod = NotEdited (convertMethodFromBackToFront file.requestNodeHttpMethod)
                        , httpHeaders = NotEdited file.requestNodeHttpHeaders
                        , httpBody = NotEdited file.requestNodeHttpBody
                        , requestComputationResult = Nothing
                        , showResponseView = False
                        , runRequestIconAnimation = Animation.style []
                        }
    in
        List.map convertRequestNodeFromBackToFront backRequestNodes


-- * environment


convertEnvironmentFromBackToFront : Back.Environment -> Front.Environment
convertEnvironmentFromBackToFront { environmentId, environmentName, environmentKeyValues } =
    { id = environmentId
    , name = NotEdited environmentName
    , showRenameInput = False
    , keyValues = List.map convertEnvironmentKeyValueFromBackToFront environmentKeyValues
    }


-- * environment key values


convertEnvironmentKeyValueFromBackToFront : Back.KeyValue -> Front.Storable Front.NewKeyValue Front.KeyValue
convertEnvironmentKeyValueFromBackToFront { keyValueId, keyValueKey, keyValueValue } =
    Saved { id = keyValueId
          , key = keyValueKey
          , value = keyValueValue
          }

convertEnvironmentKeyValueFromFrontToBack : Front.Storable Front.NewKeyValue Front.KeyValue -> Back.NewKeyValue
convertEnvironmentKeyValueFromFrontToBack storable =
    case storable of
        New { key, value } ->
            { newKeyValueKey = key
            , newKeyValueValue = value
            }

        Saved { key, value } ->
            { newKeyValueKey = key
            , newKeyValueValue = value
            }

        Edited2 _ { key, value } ->
            { newKeyValueKey = key
            , newKeyValueValue = value
            }


-- * account


convertSessionFromBackToFront : Back.Session -> Front.Session
convertSessionFromBackToFront backSession =
    case backSession of
        Back.VisitorSession { sessionAccountId, sessionCsrfToken } ->
            Front.Visitor { id = sessionAccountId
                          , csrfToken = sessionCsrfToken
                          , signInEmail = ""
                          , signInPassword = ""
                          , signInErrors = []
                          , signUpEmail = ""
                          , signUpError = Nothing
                          , signUpMessage = Nothing
                          }

        Back.SignedUserSession { sessionAccountId, sessionCsrfToken, sessionGithubEmail, sessionGithubAvatarUrl } ->
            Front.SignedUser
                { id = sessionAccountId
                , csrfToken = sessionCsrfToken
                , email = sessionGithubEmail
                , avatarUrl = sessionGithubAvatarUrl
                }


-- * request computation


convertRequestComputationResultFromBackToFront : Back.RequestComputationResult -> Front.RequestComputationResult
convertRequestComputationResultFromBackToFront backRequestComputationResult =
    case backRequestComputationResult of
        Back.RequestTimeout ->
            Front.RequestTimeout

        Back.RequestNetworkError ->
            Front.RequestNetworkError

        Back.RequestBadUrl ->
            Front.RequestBadUrl

        Back.GotRequestComputationOutput { requestComputationOutputStatusCode
                                         , requestComputationOutputHeaders
                                         , requestComputationOutputBody
                                         } ->
            Front.GotRequestComputationOutput
                { statusCode = requestComputationOutputStatusCode
                , statusText = ""
                , headers = Dict.fromList <| List.map (Tuple.mapFirst String.toLower) requestComputationOutputHeaders
                , body = requestComputationOutputBody
                }

convertRequestComputationInputFromFrontToFromBack : Front.RequestComputationInput -> Back.RequestComputationInput
convertRequestComputationInputFromFrontToFromBack frontRequestInput =
   { requestComputationInputMethod = convertMethodFromFrontToBack frontRequestInput.method
   , requestComputationInputHeaders = frontRequestInput.headers
   , requestComputationInputScheme = convertSchemeFromFrontToBack frontRequestInput.scheme
   , requestComputationInputUrl = frontRequestInput.url
   , requestComputationInputBody = frontRequestInput.body
   }

convertMethodFromBackToFront : Back.Method -> Front.HttpMethod
convertMethodFromBackToFront method =
    case method of
        Back.Get -> Front.HttpGet
        Back.Post -> Front.HttpPost
        Back.Put -> Front.HttpPut
        Back.Delete -> Front.HttpDelete
        Back.Patch -> Front.HttpPatch
        Back.Head -> Front.HttpHead
        Back.Options -> Front.HttpOptions

convertMethodFromFrontToBack : Front.HttpMethod -> Back.Method
convertMethodFromFrontToBack method =
    case method of
        Front.HttpGet -> Back.Get
        Front.HttpPost -> Back.Post
        Front.HttpPut -> Back.Put
        Front.HttpDelete -> Back.Delete
        Front.HttpPatch -> Back.Patch
        Front.HttpHead -> Back.Head
        Front.HttpOptions -> Back.Options

convertSchemeFromFrontToBack : Front.Scheme -> Back.Scheme
convertSchemeFromFrontToBack scheme =
    case scheme of
        Front.Http -> Back.Http
        Front.Https -> Back.Https
