module Statistics exposing
    ( BestTimes
    , bestTimeFor
    , elapsedSeconds
    , formatTime
    , recordIfEligible
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
