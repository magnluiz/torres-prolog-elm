module Statistics exposing
    ( BestTimes
    , bestTimeFor
    , elapsedSeconds
    , formatTime
    , recordIfEligible
    , MatchStats
    , initMatchStats
    , recordMatch
    , addWinForDifficulty
    , matchStatsFor
    )

import Api exposing (Difficulty(..))
import Time


{-| Melhor tempo sem dicas e sem uso do Resolver, em segundos. `Nothing`
significa que ainda não há recorde sem ajuda para essa dificuldade.
-}
type alias BestTimes =
    { easy : Maybe Int
    , medium : Maybe Int
    , hard : Maybe Int
    }


type alias MatchStats =
    { easyGamesPlayed : Int
    , easyWins : Int
    , mediumGamesPlayed : Int
    , mediumWins : Int
    , hardGamesPlayed : Int
    , hardWins : Int
    }

initMatchStats : MatchStats
initMatchStats =
    { easyGamesPlayed = 0
    , easyWins = 0
    , mediumGamesPlayed = 0
    , mediumWins = 0
    , hardGamesPlayed = 0
    , hardWins = 0
    }


matchStatsFor : Difficulty -> MatchStats -> { gamesPlayed : Int, wins : Int }
matchStatsFor difficulty stats =
    case difficulty of
        Easy ->
            { gamesPlayed = stats.easyGamesPlayed, wins = stats.easyWins }

        Medium ->
            { gamesPlayed = stats.mediumGamesPlayed, wins = stats.mediumWins }

        Hard ->
            { gamesPlayed = stats.hardGamesPlayed, wins = stats.hardWins }


recordMatch : Difficulty -> Bool -> MatchStats -> MatchStats
recordMatch difficulty won stats =
    let
        winDelta =
            if won then
                1

            else
                0
    in
    case difficulty of
        Easy ->
            { stats
                | easyGamesPlayed = stats.easyGamesPlayed + 1
                , easyWins = stats.easyWins + winDelta
            }

        Medium ->
            { stats
                | mediumGamesPlayed = stats.mediumGamesPlayed + 1
                , mediumWins = stats.mediumWins + winDelta
            }

        Hard ->
            { stats
                | hardGamesPlayed = stats.hardGamesPlayed + 1
                , hardWins = stats.hardWins + winDelta
            }


addWinForDifficulty : Difficulty -> MatchStats -> MatchStats
addWinForDifficulty difficulty stats =
    case difficulty of
        Easy ->
            { stats | easyWins = stats.easyWins + 1 }

        Medium ->
            { stats | mediumWins = stats.mediumWins + 1 }

        Hard ->
            { stats | hardWins = stats.hardWins + 1 }


bestTimeFor : Difficulty -> BestTimes -> Maybe Int
bestTimeFor difficulty records =
    case difficulty of
        Easy ->
            records.easy

        Medium ->
            records.medium

        Hard ->
            records.hard


recordIfEligible : Difficulty -> Int -> Int -> Bool -> BestTimes -> BestTimes
recordIfEligible difficulty seconds hintsUsed solverUsed records =
    if hintsUsed > 0 || solverUsed then
        records

    else
        case bestTimeFor difficulty records of
            Just currentBest ->
                if seconds < currentBest then
                    setBestTime difficulty seconds records

                else
                    records

            Nothing ->
                setBestTime difficulty seconds records


setBestTime : Difficulty -> Int -> BestTimes -> BestTimes
setBestTime difficulty seconds records =
    case difficulty of
        Easy ->
            { records | easy = Just seconds }

        Medium ->
            { records | medium = Just seconds }

        Hard ->
            { records | hard = Just seconds }


elapsedSeconds : Time.Posix -> Time.Posix -> Int
elapsedSeconds startedAt now =
    max 0
        ((Time.posixToMillis now - Time.posixToMillis startedAt)
            // 1000
        )


formatTime : Int -> String
formatTime totalSeconds =
    let
        minutes =
            totalSeconds // 60

        seconds =
            modBy 60 totalSeconds

        pad value =
            if value < 10 then
                "0" ++ String.fromInt value

            else
                String.fromInt value
    in
    pad minutes ++ ":" ++ pad seconds
