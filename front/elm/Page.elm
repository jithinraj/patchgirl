module Page exposing (Page(..), urlToPage, href)

import Url
import Url.Parser.Query as Query
import Url.Parser as Url exposing ((</>), (<?>))
import Uuid


-- * model


type Page
    = HomePage
    | ReqPage (Maybe Uuid.Uuid)
    | EnvPage
    | NotFoundPage


-- * parser


uuidParser =
    Url.custom "UUID" Uuid.fromString


urlParser : Url.Parser (Page -> a) a
urlParser =
    Url.oneOf
        [ Url.map HomePage Url.top
        , Url.map (\id -> ReqPage (Just id)) (Url.s "req" </> uuidParser)
        , Url.map (ReqPage Nothing) (Url.s "req")
        , Url.map EnvPage (Url.s "env")
        ]


-- * href


href : Page -> String
href page =
    let
        pieces =
            case page of
                HomePage ->
                    []

                ReqPage (Just uuid) ->
                    ["req", Uuid.toString uuid]

                ReqPage Nothing ->
                    ["req"]

                EnvPage ->
                    ["env"]

                NotFoundPage ->
                    [ "notFound" ]
    in
        "#" ++ String.join "/" pieces


-- * util


urlToPage : Url.Url -> Page
urlToPage url =
    let
        {-
        The RealWorld spec treats the fragment like a path.
        This makes it *literally* the path, so we can proceed
        with parsing as if it had been a normal path all along.
         -}
        urlWithoutFragment =
            { url
                | path = Maybe.withDefault "" url.fragment
                , fragment = Nothing
            }
    in
        urlWithoutFragment
            |> Url.parse urlParser
            |> Maybe.withDefault NotFoundPage
