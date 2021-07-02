module GitHubApi exposing (..)

import Debug
import Http
import Json.Decode as D exposing (Decoder)
import Task exposing (Task)
import Url.Builder exposing (..)


type Language
    = Any
    | C
    | Cpp
    | JavaScript
    | Python
    | TypeScript
    | CSharp
    | Java
    | Elm


type DateRange
    = Daily
    | Weekly
    | Monthly


type alias Project =
    { author : String
    , name : String
    }


trendingEndpoint : Language -> DateRange -> String
trendingEndpoint lang dateRange =
    let
        language =
            case lang of
                Any ->
                    ""

                C ->
                    "C"

                Cpp ->
                    "Cpp"

                JavaScript ->
                    "JavaScript"

                Python ->
                    "Python"

                TypeScript ->
                    "TypeScript"

                CSharp ->
                    "CSharp"

                Java ->
                    "Java"

                Elm ->
                    "Elm"

        since =
            case dateRange of
                Daily ->
                    "daily"

                Weekly ->
                    "weekly"

                Monthly ->
                    "monthly"
    in
    Url.Builder.custom
        (Url.Builder.CrossOrigin "https://trendings.herokuapp.com")
        [ "repo" ]
        [ Url.Builder.string "lang" language
        , Url.Builder.string "since" since
        ]
        Nothing


topicsEndpoint : String -> String -> String
topicsEndpoint user repo =
    Url.Builder.custom
        (Url.Builder.CrossOrigin "https://api.github.com")
        [ "repos", user, repo, "topics" ]
        []
        Nothing


fromJust : Maybe String -> String
fromJust x =
    case x of
        Just y ->
            y

        Nothing ->
            ""


projectFromList : List String -> Project
projectFromList lst =
    let
        author =
            lst |> List.head |> fromJust

        name =
            lst
                |> List.drop 1
                |> List.head
                |> fromJust
    in
    Project author name


trendingDecoder : Decoder (List Project)
trendingDecoder =
    D.field "items" <|
        D.list <|
            D.map (\repo -> repo |> String.split "/" |> projectFromList)
                (D.field "repo" D.string)


topicsDecoder =
    D.field "names" (D.list D.string)


requestGitHubApi : String -> String -> Decoder a -> Task Http.Error a
requestGitHubApi token url decoder =
    Http.task
        { method = "GET"
        , headers =
            [ Http.header "accept" "application/vnd.github.mercy-preview+json"
            , Http.header "authorization" ("Bearer " ++ token)
            ]
        , url = url
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

                        Http.BadStatus_ metadata body ->
                            Err (Http.BadStatus metadata.statusCode)

                        Http.GoodStatus_ metadata body ->
                            case D.decodeString decoder body of
                                Ok value ->
                                    Ok value

                                Err err ->
                                    Err (Http.BadBody (D.errorToString err))
                )
        , timeout = Nothing
        }


fetchTrending : String -> Language -> DateRange -> Task Http.Error (List Project)
fetchTrending token lang dateRange =
    requestGitHubApi token (trendingEndpoint lang dateRange) trendingDecoder


fetchTopics : String -> String -> String -> Task Http.Error (List String)
fetchTopics token user repo =
    requestGitHubApi token (topicsEndpoint user repo) topicsDecoder
