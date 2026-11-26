module StatisticsTest exposing (suite)

import Api exposing (Difficulty(..))
import Expect
import Statistics
import Test exposing (Test, describe, test)
import Time


emptyRecords : Statistics.BestTimes
emptyRecords =
    { easy = Nothing
    , medium = Nothing
    , hard = Nothing
    }


suite : Test
suite =
    describe "Estatísticas"
        [ describe "formatação do tempo"
            [ test "formata minutos e segundos" <|
                \_ ->
                    Statistics.formatTime 125
                        |> Expect.equal "02:05"
            , test "formata zero, segundos com zero à esquerda e um minuto" <|
                \_ ->
                    [ Statistics.formatTime 0
                    , Statistics.formatTime 9
                    , Statistics.formatTime 60
                    ]
                        |> Expect.equal [ "00:00", "00:09", "01:00" ]
            , test "calcula segundos completos e descarta a fração" <|
                \_ ->
                    Statistics.elapsedSeconds
                        (Time.millisToPosix 1000)
                        (Time.millisToPosix 6999)
                        |> Expect.equal 5
            , test "não retorna tempo negativo" <|
                \_ ->
                    Statistics.elapsedSeconds
                        (Time.millisToPosix 5000)
                        (Time.millisToPosix 3000)
                        |> Expect.equal 0
            ]
        , describe "recordes"
            [ test "registra a primeira partida sem ajuda" <|
                \_ ->
                    Statistics.recordIfEligible Easy 75 0 False emptyRecords
                        |> .easy
                        |> Expect.equal (Just 75)
            , test "não substitui um recorde por um tempo pior" <|
                \_ ->
                    Statistics.recordIfEligible Easy
                        90
                        0
                        False
                        { emptyRecords | easy = Just 75 }
                        |> .easy
                        |> Expect.equal (Just 75)
            , test "não registra partida em que usou dica" <|
                \_ ->
                    Statistics.recordIfEligible Easy 60 1 False emptyRecords
                        |> .easy
                        |> Expect.equal Nothing
            , test "não registra partida em que usou Resolver" <|
                \_ ->
                    Statistics.recordIfEligible Easy 60 0 True emptyRecords
                        |> .easy
                        |> Expect.equal Nothing
            , test "mantém recordes separados por dificuldade" <|
                \_ ->
                    Statistics.recordIfEligible Medium 80 0 False emptyRecords
                        |> .medium
                        |> Expect.equal (Just 80)
            , test "substitui o recorde quando o novo tempo é menor" <|
                \_ ->
                    Statistics.recordIfEligible Easy
                        60
                        0
                        False
                        { emptyRecords | easy = Just 75 }
                        |> .easy
                        |> Expect.equal (Just 60)
            , test "não substitui o recorde por um tempo igual" <|
                \_ ->
                    Statistics.recordIfEligible Easy
                        75
                        0
                        False
                        { emptyRecords | easy = Just 75 }
                        |> .easy
                        |> Expect.equal (Just 75)
            , test "atualiza uma dificuldade sem alterar as outras" <|
                \_ ->
                    Statistics.recordIfEligible Hard
                        65
                        0
                        False
                        { easy = Just 75
                        , medium = Just 80
                        , hard = Nothing
                        }
                        |> Expect.equal
                            { easy = Just 75
                            , medium = Just 80
                            , hard = Just 65
                            }
            ]
        , describe "placar de partidas e vitórias"
            [ test "inicia zerado" <|
                \_ ->
                    Statistics.initMatchStats
                        |> Expect.equal { gamesPlayed = 0, wins = 0 }
            , test "incrementa partidas jogadas e vitórias quando vence" <|
                \_ ->
                    Statistics.initMatchStats
                        |> Statistics.recordMatch True
                        |> Expect.equal { gamesPlayed = 1, wins = 1 }
            , test "incrementa apenas partidas jogadas quando não vence" <|
                \_ ->
                    Statistics.initMatchStats
                        |> Statistics.recordMatch False
                        |> Expect.equal { gamesPlayed = 1, wins = 0 }
            ]
        ]
