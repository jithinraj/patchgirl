module Api.Converter exposing(..)

import Api.Client as Back
import BuilderApp.Model as Front

import BuilderApp.Builder.Model as Builder

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
                        { name = folder.name
                        , open = False
                        , showRenameInput = False
                        , children = convertRequestNodesFromBackToFront folder.children
                        }
                Back.RequestFile file ->
                    Front.RequestFile
                        { name = file.name
                        , showRenameInput = False
                        , isSaved = True
                        , url = file.url
                        , method = file.method
                        , headers = file.headers
                        , body = file.body
                        , response = Nothing
                        }
    in
        List.map convertRequestNodeFromBackToFront backRequestNodes

convertRequestNodesFromFrontToBack : List Front.RequestNode -> List Back.RequestNode
convertRequestNodesFromFrontToBack frontRequestNodes =
    let
        convertRequestNodeFromFrontToBack : Front.RequestNode -> Back.RequestNode
        convertRequestNodeFromFrontToBack frontRequestNode =
            case frontRequestNode of
                Front.RequestFolder folder ->
                    Back.RequestFolder
                        { name = folder.name
                        , children = convertRequestNodesFromFrontToBack folder.children
                        }
                Front.RequestFile file ->
                    Back.RequestFile
                        { name = file.name
                        , url = file.url
                        , method = file.method
                        , headers = file.headers
                        , body = file.body
                        }
    in
        List.map convertRequestNodeFromFrontToBack frontRequestNodes