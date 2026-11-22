module Api exposing
    ( Difficulty(..)
    , Hint
    , difficultyLabel
    , generate
    , hint
    , solve
    )

{-| Comunicação com o backend (FastAPI + Prolog).

As funções deste módulo devolvem um `Cmd msg`: uma DESCRIÇÃO da requisição.
Quem a executa é o runtime do Elm, que depois chama o `update` com a
mensagem indicada. Assim todas as nossas funções continuam puras.

As URLs começam com `/api/...`. Em desenvolvimento, o Vite repassa essas
requisições para o backend em <http://localhost:8000> (veja vite.config.js).

-}

import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Towers exposing (Board, Puzzle, RawPuzzle)


type Difficulty
    = Easy
    | Medium
    | Hard


difficultyLabel : Difficulty -> String
difficultyLabel difficulty =
    case difficulty of
        Easy ->
            "Fácil 4×4"

        Medium ->
            "Médio 5×5"

        Hard ->
            "Difícil 6×6"


{-| Nome usado pela API (e pelo Prolog: são os átomos easy/medium/hard).
-}
difficultyToString : Difficulty -> String
difficultyToString difficulty =
    case difficulty of
        Easy ->
            "easy"

        Medium ->
            "medium"

        Hard ->
            "hard"


type alias Hint =
    { row : Int
    , col : Int
    , value : Int
    , explanation : String
    }



-- REQUISIÇÕES


generate : Difficulty -> (Result String Puzzle -> msg) -> Cmd msg
generate difficulty toMsg =
    Http.post
        { url = "/api/generate"
        , body =
            Http.jsonBody
                (Encode.object [ ( "difficulty", Encode.string (difficultyToString difficulty) ) ])
        , expect = expectJson toMsg (Decode.field "puzzle" puzzleDecoder)
        }


{-| A solução chega como lista de linhas; quem a aplica ao tabuleiro é
`Towers.revealSolution`.
-}
solve : Puzzle -> Board -> (Result String (List (List Int)) -> msg) -> Cmd msg
solve puzzle board toMsg =
    Http.post
        { url = "/api/solve"
        , body = Http.jsonBody (encodeRequest puzzle board)
        , expect = expectJson toMsg (Decode.field "board" gridDecoder)
        }


hint : Puzzle -> Board -> (Result String Hint -> msg) -> Cmd msg
hint puzzle board toMsg =
    Http.post
        { url = "/api/hint"
        , body = Http.jsonBody (encodeRequest puzzle board)
        , expect = expectJson toMsg hintDecoder
        }



-- JSON


{-| Lê o puzzle em duas etapas. `Decode.map6` monta o `RawPuzzle` (só
listas de inteiros); depois `Decode.andThen` passa o resultado por
`Towers.fromRaw`, que confere as dimensões. Se `fromRaw` devolver `Err`, o
decoder inteiro falha com aquela mensagem. Um JSON torto nunca vira um
`Puzzle`.
-}
puzzleDecoder : Decoder Puzzle
puzzleDecoder =
    Decode.map6 RawPuzzle
        (Decode.field "top" (Decode.list Decode.int))
        (Decode.field "bottom" (Decode.list Decode.int))
        (Decode.field "left" (Decode.list Decode.int))
        (Decode.field "right" (Decode.list Decode.int))
        (Decode.field "hdots" gridDecoder)
        (Decode.field "vdots" gridDecoder)
        |> Decode.andThen
            (\raw ->
                case Towers.fromRaw raw of
                    Ok puzzle ->
                        Decode.succeed puzzle

                    Err problem ->
                        Decode.fail problem
            )


gridDecoder : Decoder (List (List Int))
gridDecoder =
    Decode.list (Decode.list Decode.int)


hintDecoder : Decoder Hint
hintDecoder =
    Decode.map4 Hint
        (Decode.field "row" Decode.int)
        (Decode.field "col" Decode.int)
        (Decode.field "value" Decode.int)
        (Decode.field "explanation" Decode.string)


{-| `{"puzzle": {...}, "board": [[...], ...]}`: o backend não guarda
estado, então cada pedido leva o puzzle junto.
-}
encodeRequest : Puzzle -> Board -> Encode.Value
encodeRequest puzzle board =
    Encode.object
        [ ( "puzzle", encodePuzzle (Towers.toRaw puzzle) )
        , ( "board", encodeGrid (Towers.toLists board) )
        ]


encodePuzzle : RawPuzzle -> Encode.Value
encodePuzzle raw =
    Encode.object
        [ ( "top", Encode.list Encode.int raw.top )
        , ( "bottom", Encode.list Encode.int raw.bottom )
        , ( "left", Encode.list Encode.int raw.left )
        , ( "right", Encode.list Encode.int raw.right )
        , ( "hdots", encodeGrid raw.hdots )
        , ( "vdots", encodeGrid raw.vdots )
        ]


encodeGrid : List (List Int) -> Encode.Value
encodeGrid =
    Encode.list (Encode.list Encode.int)



-- TRATAMENTO DE ERROS
--
-- `Http.expectJson` descarta o corpo das respostas de erro (ex.: 422). Nosso
-- backend manda uma mensagem útil em `{"detail": "..."}`, então escrevemos
-- nossa própria versão, que devolve sempre um `Result String a`.


expectJson : (Result String a -> msg) -> Decoder a -> Http.Expect msg
expectJson toMsg decoder =
    Http.expectStringResponse toMsg <|
        \response ->
            case response of
                Http.GoodStatus_ _ body ->
                    Decode.decodeString decoder body
                        |> Result.mapError (\_ -> "Resposta inesperada do servidor.")

                Http.BadStatus_ metadata body ->
                    Err (errorDetail metadata.statusCode body)

                Http.BadUrl_ url ->
                    Err ("URL inválida: " ++ url)

                Http.Timeout_ ->
                    Err "O servidor demorou demais para responder."

                Http.NetworkError_ ->
                    Err "Não foi possível falar com o servidor. O backend está rodando?"


errorDetail : Int -> String -> String
errorDetail status body =
    case Decode.decodeString (Decode.field "detail" Decode.string) body of
        Ok detail ->
            detail

        Err _ ->
            "Erro no servidor (código " ++ String.fromInt status ++ ")."
