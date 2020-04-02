module Main exposing (main)

import Cli.Option as Option
import Cli.OptionsParser as OptionsParser exposing (with)
import Cli.Program as Program
import Dict exposing (Dict)
import GitHubApi exposing (DateRange(..), Language(..), Project, fetchTopics, fetchTrending)
import Http
import Json.Decode as D exposing (Decoder)
import Json.Encode as E
import Ports
import Task exposing (Task)


type Msg
    = TrendingApiResponse (List Project)
    | TopicApiResponse (Dict String Int)
    | ErrorResponse Http.Error


type alias Model =
    ()


type alias TrendingApiOptions =
    { language : Language
    , dateRange : DateRange
    }


type alias Flags =
    Program.FlagsIncludingArgv {}


programConfig : Program.Config TrendingApiOptions
programConfig =
    Program.config
        |> Program.add
            (OptionsParser.build TrendingApiOptions
                |> with
                    (Option.optionalKeywordArg "language"
                        |> Option.withDefault "any"
                        |> Option.oneOf Any
                            [ ( "any", Any )
                            , ( "c", C )
                            , ( "cpp", Cpp )
                            , ( "js", JavaScript )
                            , ( "python", Python )
                            , ( "ts", TypeScript )
                            , ( "csharp", CSharp )
                            , ( "java", Java )
                            , ( "elm", Elm )
                            ]
                    )
                |> with
                    (Option.optionalKeywordArg "date-range"
                        |> Option.withDefault "daily"
                        |> Option.oneOf Daily
                            [ ( "daily", Daily )
                            , ( "weekly", Weekly )
                            , ( "monthly", GitHubApi.Monthly )
                            ]
                    )
            )


attemptApi : (a -> Msg) -> Task Http.Error a -> Cmd Msg
attemptApi toMessage task =
    let
        aux response =
            case response of
                Ok x ->
                    toMessage x

                Err x ->
                    ErrorResponse x
    in
    Task.attempt aux task


encodeToTopicsJson : List ( String, Int ) -> String
encodeToTopicsJson topics =
    topics
        |> List.map (\( k, v ) -> ( k, E.int v ))
        |> E.object
        |> E.encode 4


countWords : String -> Dict String Int -> Dict String Int
countWords k d =
    Dict.update k (Maybe.withDefault 0 >> (+) 1 >> Just) d


init : Flags -> TrendingApiOptions -> ( Model, Cmd Msg )
init _ { language, dateRange } =
    ( ()
    , attemptApi TrendingApiResponse (fetchTrending language dateRange)
    )


update : TrendingApiOptions -> Msg -> Model -> ( Model, Cmd Msg )
update trendingOptions msg model =
    case msg of
        TrendingApiResponse response ->
            ( model
            , response
                |> List.map
                    (\{ author, name } ->
                        fetchTopics author name
                    )
                |> Task.sequence
                |> attemptApi
                    (List.concat
                        >> List.foldl countWords Dict.empty
                        >> TopicApiResponse
                    )
            )

        TopicApiResponse response ->
            ( model
            , response
                |> Dict.toList
                |> encodeToTopicsJson
                |> Ports.print
            )

        ErrorResponse error ->
            case error of
                Http.BadUrl url ->
                    ( model, Ports.print ("Bad url:" ++ url) )

                Http.Timeout ->
                    ( model, Ports.print "Network timeout." )

                Http.NetworkError ->
                    ( model, Ports.print "Network error." )

                Http.BadStatus code ->
                    ( model, Ports.print ("Bad status:" ++ String.fromInt code) )

                Http.BadBody body ->
                    ( model, Ports.print ("Bad body:" ++ body) )


main : Program.StatefulProgram Model Msg TrendingApiOptions {}
main =
    Program.stateful
        { printAndExitFailure = Ports.printAndExitFailure
        , printAndExitSuccess = Ports.printAndExitSuccess
        , init = init
        , config = programConfig
        , update = update
        , subscriptions = \_ -> Sub.none
        }
