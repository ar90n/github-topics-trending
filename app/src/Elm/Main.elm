module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events as Events exposing (on)
import Http
import Json.Decode as D exposing (Decoder)
import Task exposing (Task)
import Url
import Url.Builder
import Url.Parser exposing ((<?>), top)
import Url.Parser.Query as Q


type alias Model =
    { key : Nav.Key
    , root : String
    , date : String
    , lang : String
    , index : Status Index
    , topics : Status Topics
    }


type alias Flags =
    { appRootUrl : String }


type Status a
    = Failure
    | Loading
    | Success a


type alias Index =
    Dict String (Dict String (List String))


type alias Topics =
    List ( String, Int )


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | IndexFetched (Maybe String) (Maybe String) Index
    | TopicsFetched (List ( String, Int ))
    | ErrorResponse Http.Error
    | RequestChanged String String


onChange : (String -> msg) -> Attribute msg
onChange handler =
    on "change" (D.map handler Events.targetValue)


attemptFetching : (a -> Msg) -> Task Http.Error a -> Cmd Msg
attemptFetching toMessage task =
    let
        aux response =
            case response of
                Ok x ->
                    toMessage x

                Err x ->
                    ErrorResponse x
    in
    Task.attempt aux task


fetchResource : String -> Decoder a -> Task Http.Error a
fetchResource url decoder =
    Http.task
        { method = "GET"
        , url = url
        , headers = []
        , body = Http.emptyBody
        , resolver =
            Http.stringResolver
                (\response ->
                    case response of
                        Http.BadUrl_ badUrl ->
                            Err (Http.BadUrl badUrl)

                        Http.Timeout_ ->
                            Err Http.Timeout

                        Http.NetworkError_ ->
                            Err Http.NetworkError

                        Http.BadStatus_ metadata _ ->
                            Err (Http.BadStatus metadata.statusCode)

                        Http.GoodStatus_ _ body ->
                            case D.decodeString decoder body of
                                Ok value ->
                                    Ok value

                                Err err ->
                                    Err (Http.BadBody (D.errorToString err))
                )
        , timeout = Nothing
        }


fetchIndex : String -> Task Http.Error Index
fetchIndex rootUrl =
    let
        url =
            rootUrl ++ "/topics/index.json"

        decoder =
            D.dict (D.dict (D.list D.string))
    in
    fetchResource url decoder


fetchTopics : String -> String -> String -> Task Http.Error Topics
fetchTopics rootUrl date lang =
    let
        url =
            rootUrl ++ "/topics/" ++ String.replace "-" "/" date ++ "/" ++ lang ++ "/daily.json"

        decoder =
            D.keyValuePairs D.int
    in
    fetchResource url decoder


parseUrl : Url.Url -> Maybe ( Maybe String, Maybe String )
parseUrl url =
    let
        queryParser =
            Q.map2
                (\maybeDate maybeLang -> ( maybeDate, maybeLang ))
                (Q.string "date")
                (Q.string "lang")

        parser =
            (Url.Parser.s "github-topics-trending") <?> queryParser
    in
    Url.Parser.parse parser url


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        model =
            Model key flags.appRootUrl "" "any" Loading Loading
    in
    case parseUrl url of
        Just ( maybeDate, maybeLang ) ->
            ( model
            , attemptFetching (IndexFetched maybeDate maybeLang) <| fetchIndex model.root
            )

        Nothing ->
            ( { model | index = Failure, topics = Failure }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        IndexFetched maybeDate maybeLang index ->
            let
                date =
                    Maybe.withDefault
                        (Dict.keys index |> List.maximum |> Maybe.withDefault "")
                        maybeDate

                lang =
                    Maybe.withDefault "any" maybeLang
            in
            ( { model | date = date, lang = lang, index = Success index }
            , attemptFetching TopicsFetched <| fetchTopics model.root date lang
            )

        TopicsFetched ts ->
            ( { model | topics = Success ts }, Cmd.none )

        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            case model.index of
                Loading ->
                    ( { model | index = Failure, topics = Failure }, Cmd.none )

                Failure ->
                    ( { model | index = Failure, topics = Failure }, Cmd.none )

                Success index ->
                    case parseUrl url of
                        Just ( maybeDate, maybeLang ) ->
                            update (IndexFetched maybeDate maybeLang index) model

                        Nothing ->
                            ( { model | index = Failure, topics = Failure }, Cmd.none )

        RequestChanged date lang ->
            let
                url =
                    Url.Builder.relative
                        []
                        [ Url.Builder.string "date" date
                        , Url.Builder.string "lang" lang
                        ]
            in
            ( model, Nav.pushUrl model.key url )

        ErrorResponse _ ->
            ( { model
                | index =
                    if model.index == Loading then
                        Failure

                    else
                        model.index
                , topics = Failure
              }
            , Cmd.none
            )


viewNotFound : Html msg
viewNotFound =
    title "Not found ..."


viewLoading : Html msg
viewLoading =
    title "Not found ..."


topics : Status Topics -> Html Msg
topics successTopics =
    let
        topicItem ( t, _ ) =
            li [ style "margin" "8px" ] [ text t ]
    in
    div
        [ class "col-12" ]
        [ case successTopics of
            Loading ->
                text "Loading ..."

            Failure ->
                text "Not found ..."

            Success ts ->
                ts
                    |> List.map topicItem
                    |> ul []
        ]


title : String -> Html msg
title msg =
    h1
        [ classList
            [ ( "u-text-center", True )
            , ( "u-font-alt", True )
            ]
        ]
        [ text msg ]


divider : Html msg
divider =
    div [ class "divider" ] []


faIcon : String -> Html msg
faIcon name =
    div
        [ class "form-group-label" ]
        [ span [ class "icon" ]
            [ i
                [ classList
                    [ ( "fa-wrapper", True )
                    , ( "fas", True )
                    , ( name, True )
                    ]
                ]
                []
            ]
        ]


datePicker : Index -> String -> String -> Html Msg
datePicker index date lang =
    let
        minDate =
            Dict.keys index |> List.minimum |> Maybe.withDefault ""

        maxDate =
            Dict.keys index |> List.maximum |> Maybe.withDefault ""
    in
    div
        [ classList
            [ ( "col-6", True )
            , ( "form-group", True )
            ]
        ]
        [ faIcon "fa-calendar"
        , input
            [ type_ "date"
            , class "form-group-input"
            , value date
            , Html.Attributes.min minDate
            , Html.Attributes.max maxDate
            , onChange (\x -> RequestChanged x lang)
            ]
            []
        ]


langSelector : Index -> String -> String -> Html Msg
langSelector index date lang =
    let
        selectItem sel x =
            option [ value x, selected (x == sel) ] [ text x ]
    in
    div
        [ classList
            [ ( "col-6", True )
            , ( "form-group", True )
            ]
        ]
        [ faIcon "fa-code"
        , select
            [ onChange (\x -> RequestChanged date x)
            , classList
                [ ( "select", True )
                , ( "form-group-input", True )
                ]
            ]
            (index
                |> Dict.get date
                |> Maybe.map (\x -> Dict.keys x)
                |> Maybe.withDefault []
                |> List.map (selectItem lang)
            )
        ]


menu : Index -> String -> String -> Html Msg
menu index date lang =
    div
        [ class "col-12" ]
        [ datePicker index date lang
        , langSelector index date lang
        ]


viewContents : Index -> Model -> Html Msg
viewContents index model =
    div
        [ classList
            [ ( "hero", True )
            ]
        ]
        [ div
            [ classList
                [ ( "hero-body", True )
                , ( "content", True )
                ]
            ]
            [ div
                [ classList
                    [ ( "frame", True )
                    , ( "row", True )
                    , ( "level", True )
                    , ( "fill-height", True )
                    ]
                ]
                [ div
                    [ class "content" ]
                    [ title "Topics in GitHub Trending"
                    , divider
                    , menu index model.date model.lang
                    , topics model.topics
                    ]
                ]
            ]
        ]


view : Model -> Browser.Document Msg
view model =
    { title = "Topics in GitHub Trending"
    , body =
        case model.index of
            Loading ->
                [ viewLoading ]

            Failure ->
                [ viewNotFound ]

            Success index ->
                [ viewContents index model ]
    }


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
