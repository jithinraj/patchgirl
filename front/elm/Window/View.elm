module Window.View exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)

import BuilderApp.BuilderTree.View as BuilderTree
import BuilderApp.BuilderTree.Util as BuilderTree
import Postman.View as Postman
import EnvApp.View as EnvApp
import EnvApp.EnvNav.View as EnvNav
import BuilderApp.EnvSelection.View as EnvSelection
import MainNavBar.View as MainNavBar
import MainNavBar.Model as MainNavBar
import VarApp.View as VarApp
import WorkspaceApp.View as WorkspaceApp

import BuilderApp.Builder.View as Builder
import BuilderApp.View as BuilderApp

import Util.List as List

import BuilderApp.BuilderTree.Model as BuilderTree

import Window.Model exposing(..)
import Window.Message exposing(..)

view : Model -> Html Msg
view model =
    let
        contentView : Html Msg
        contentView =
            div [ id "content" ] <|
                case model.mainNavBarModel of
                    MainNavBar.EnvTab -> [ Html.map EnvNavMsg (EnvNav.view model.envNavModel) ]
                    MainNavBar.ReqTab -> [ builderView model ]
                    MainNavBar.VarTab -> [ Html.map VarAppMsg (VarApp.view model.varAppModel) ]
                    MainNavBar.WorkspaceTab -> [ Html.map WorkspaceAppMsg (WorkspaceApp.view model.workspaceAppModel) ]
    in
        div []
            [ Html.map MainNavBarMsg (MainNavBar.view model.mainNavBarModel)
            , contentView
            ]

builderView : Model -> Html Msg
builderView model =
  let
    treeView : Html Msg
    treeView =
      Html.map BuilderTreeMsg (BuilderTree.view model.builderAppModel.builderTreeModel)
    envSelectionView : Html Msg
    envSelectionView =
      Html.map EnvSelectionMsg (EnvSelection.view model.selectedEnvModel)
  in
    div [ id "builderApp" ]
      [ div [ id "treeView" ] [ treeView ]
      , div [ id "builderView" ] [ (Html.map BuilderAppMsg (BuilderApp.view model.builderAppModel)) ]
      , div [ class "" ] [ envSelectionView ]
      ]

postmanView : Html Msg
postmanView =
  Html.map PostmanMsg Postman.view