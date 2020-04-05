module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Json.Decode as D exposing (Decoder)
import Url


type alias Model =
    { key : Nav.Key
    , url : Url.Url
    , root : String
    , index : Status (Dict String (Dict String (List String)))
    , topics : Status (List (String, Int))
    }


type alias Flags =
    { appRootUrl : String }


type Status a
    = Failure
    | Loading
    | Success a


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | IndexFetched (Result Http.Error (Dict String (Dict String (List String))))
    | TopicsFetched (Result Http.Error (List ( String, Int )))


indexDecoder : Decoder (Dict String (Dict String (List String)))
indexDecoder =
    D.dict (D.dict (D.list D.string))


topicsDecoder : Decoder (List ( String, Int ))
topicsDecoder =
    D.keyValuePairs D.int


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    ( Model key url flags.appRootUrl Loading Loading
    , Http.get
        { url = flags.appRootUrl ++ "/topics/index.json"
        , expect = Http.expectJson IndexFetched indexDecoder
        }
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        IndexFetched httpResponse ->
            case httpResponse of
                Ok index ->
                    ( { model | index = Success index }
                    , Dict.keys index
                        |> List.maximum
                        |> (\maybeDate ->
                                case maybeDate of
                                    Just date ->
                                        Http.get
                                            { url = model.root ++ "/topics/" ++ date ++ "/cpp/daily.json"
                                            , expect = Http.expectJson TopicsFetched topicsDecoder
                                            }

                                    Nothing ->
                                        Cmd.none
                           )
                    )

                Err _ ->
                    ( { model | index = Failure }, Cmd.none )

        TopicsFetched httpResponse ->
            case httpResponse of
                Ok topics ->
                    ( { model | topics = Success topics }
                    , Cmd.none
                    )

                Err _ ->
                    ( { model | index = Failure }, Cmd.none )

        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            ( { model | url = url }
            , Cmd.none
            )


view : Model -> Browser.Document Msg
view model =
    { title = "GitHub Topics Trending"
    , body =
        [ text "url:"
        , b [] [ text (Url.toString model.url) ]
        , ul []
            [ viewLink "/home"
            , viewLink "/profile"
            ]
        , case model.topics of
            Loading ->
                text "loading"

            Failure ->
                text "failure"

            Success s ->
                text (s |> List.map (\(c, n) -> c ++ ":" ++ (String.fromInt n)) |> String.concat)
        ]
    }


viewLink : String -> Html msg
viewLink path =
    li [] [ a [ href path ] [ text path ] ]


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = \_ -> Sub.none
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }
