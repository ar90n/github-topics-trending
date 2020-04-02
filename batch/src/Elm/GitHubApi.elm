module GitHubApi exposing (..)

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
        (Url.Builder.CrossOrigin "https://github-trending-api.now.sh")
        [ "repositories" ]
        [ Url.Builder.string "language" language
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


trendingDecoder : Decoder (List Project)
trendingDecoder =
    D.list <|
        D.map2 Project
            (D.field "author" D.string)
            (D.field "name" D.string)


topicsDecoder =
    D.field "names" (D.list D.string)


requestGitHubApi : String -> Decoder a -> Task Http.Error a
requestGitHubApi url decoder =
    let
        github_token =
            "d7bb3143b795ff5a1a7fd0dab19491726bdc42df"
    in
    Http.task
        { method = "GET"
        , headers =
            [ Http.header "accept" "application/vnd.github.mercy-preview+json"
            , Http.header "authorization" ("Bearer " ++ github_token)
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


fetchTrending : Language -> DateRange -> Task Http.Error (List Project)
fetchTrending lang dateRange =
    requestGitHubApi (trendingEndpoint lang dateRange) trendingDecoder


fetchTopics : String -> String -> Task Http.Error (List String)
fetchTopics user repo =
    requestGitHubApi (topicsEndpoint user repo) topicsDecoder
