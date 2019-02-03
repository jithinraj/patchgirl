import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Json
import List.Extra as L

import Builder.Message as Builder
import Builder.App as Builder
import Builder.Model as Builder

import Tree.View as Tree
import Tree.Model as Tree
import Tree.Message as Tree
import Tree.App as Tree

import Postman.View as Postman
import Postman.Model as Postman
import Postman.Message as Postman
import Postman.App as Postman

import Env.View as Env
import Env.Model as Env
import Env.Message as Env
import Env.App as Env

import EnvNav.View as EnvNav
import EnvNav.Model as EnvNav
import EnvNav.Message as EnvNav
import EnvNav.App as EnvNav

import Runner.App as Runner
import Runner.Message as Runner
import Runner.Model as Runner

main =
  Browser.element
    { init = init
    , update = update
    , subscriptions = subscriptions
    , view = view
    }

type alias Model =
  { treeModel : Tree.Model
  , postmanModel : Postman.Model
  , envModel : Env.Model
  , envNavModel : EnvNav.Model
  , runnerModel : Runner.Model
  }

type Msg
  = TreeMsg Tree.Msg
  | BuilderMsg Builder.Msg
  | PostmanMsg Postman.Msg
  | EnvMsg Env.Msg
  | EnvNavMsg EnvNav.Msg
  | RunnerMsg Runner.Msg

init : () -> (Model, Cmd Msg)
init _ =
  let
    treeModel =
      { selectedNode = Nothing
      , displayedBuilderIndex = Just 4
      , tree = Tree.defaultTree
      }
    model =
      { treeModel = treeModel
      , postmanModel = Nothing
      , envModel = [("url", "swapi.co")]
      , envNavModel = ["env1"]
      , runnerModel = Nothing
      }
  in
    (model, Cmd.none)

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    TreeMsg subMsg ->
      case Tree.update subMsg model.treeModel of
        (newTreeModel, newMsg) -> ( { model | treeModel = newTreeModel }, Cmd.map TreeMsg newMsg)

    EnvNavMsg subMsg ->
      case EnvNav.update subMsg model.envNavModel of
        (newEnvNavModel, newMsg) -> ( { model | envNavModel = newEnvNavModel }, Cmd.map EnvNavMsg newMsg)

    PostmanMsg subMsg ->
      case Postman.update subMsg model.postmanModel of
        (Just newTree, newMsg) ->
          let
            newTreeModel =
              { selectedNode = Nothing
              , displayedBuilderIndex = Nothing
              , tree = newTree
              }
          in
            ( { model | treeModel = newTreeModel }, Cmd.map PostmanMsg newMsg)

        (Nothing, newMsg) ->
          (model, Cmd.none)

    BuilderMsg subMsg ->
      let
        mUpdatedBuilderToCmd : Maybe (Builder.Model, Cmd Builder.Msg)
        mUpdatedBuilderToCmd = Maybe.map (Builder.update subMsg) (mBuilder model.treeModel)
      in
        case (mBuilder model.treeModel, subMsg) of
          (Nothing, _) -> (model, Cmd.none)
          (Just builder, Builder.AskRun) ->
            let
              (updatedRunner, cmdRunner) = (Runner.update (Runner.Run model.envModel builder) model.runnerModel)
            in
              ( { model | runnerModel = updatedRunner }, Cmd.map RunnerMsg cmdRunner)
          (Just builder, _) ->
            let
              (updatedBuilder, cmdBuilder) = (Builder.update subMsg builder)
            in
              (model, Cmd.map BuilderMsg cmdBuilder)

    RunnerMsg subMsg ->
      case (subMsg, mBuilder model.treeModel, model.treeModel.displayedBuilderIndex) of
        (Runner.GetResponse response, Just builder, Just builderIdx) ->
          let
            (updatedBuilder, cmdBuilder) = (Builder.update (Builder.GiveResponse response) builder)
            updateNode : Tree.Node -> Tree.Node
            updateNode oldNode =
              case oldNode of
                Tree.File { name } -> Tree.File { name = name, builder = updatedBuilder, showRenameInput = False }
                _ -> oldNode
            newTree = Tree.modifyNode updateNode model.treeModel.tree builderIdx
            oldTreeModel = model.treeModel
            newTreeModel = { oldTreeModel | tree = newTree }
          in
            ( { model | treeModel = newTreeModel }, Cmd.map BuilderMsg cmdBuilder)
        _ -> (model, Cmd.none)

    EnvMsg subMsg ->
      case Env.update subMsg model.envModel of
        (newEnv, newMsg) ->
          ( { model | envModel = newEnv }, Cmd.map EnvMsg newMsg)

mBuilder : Tree.Model -> Maybe Builder.Model
mBuilder treeModel = treeModel.displayedBuilderIndex |> Maybe.andThen (Tree.findBuilder treeModel.tree)

subscriptions : Model -> Sub Msg
subscriptions _ =
  Sub.none

view : Model -> Html Msg
view model =
  let
    builderView : Html Msg
    builderView =
      div []
        [ div [] [ postmanView ]
        , div [] [ treeView model ]
        , div [] [ envNavView model ]
        , div [] [ builderAppView model.treeModel ]
        , div [] [ envView model ]
        ]
  in
    div [ id "app" ] [ builderView ]

postmanView : Html Msg
postmanView =
  Html.map PostmanMsg Postman.view

builderAppView : Tree.Model -> Html Msg
builderAppView treeModel =
  treeModel.displayedBuilderIndex
    |> Maybe.andThen (Tree.findBuilder treeModel.tree)
    |> Maybe.map Builder.view
    |> Maybe.map (Html.map BuilderMsg)
    |> Maybe.withDefault (div [] [ text (Maybe.withDefault "nope" (Maybe.map String.fromInt(treeModel.displayedBuilderIndex))) ])

treeView : Model -> Html Msg
treeView model =
  Html.map TreeMsg (Tree.view model.treeModel.tree)

envNavView : Model -> Html Msg
envNavView model =
  Html.map EnvNavMsg (EnvNav.view model.envNavModel)

envView : Model -> Html Msg
envView model =
  Html.map EnvMsg (Env.view model.envModel)
