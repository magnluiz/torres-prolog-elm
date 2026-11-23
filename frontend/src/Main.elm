port module Main exposing (main)

{-| Interface gráfica das Torres Latinas, na Arquitetura Elm:

  - `Model`: o estado completo, num único valor imutável;
  - `Msg`: tudo o que pode acontecer (cliques, teclas, respostas HTTP);
  - `update`: recebe uma `Msg` e o `Model` e devolve o novo `Model`;
  - `view`: desenha o `Model`. A tela é uma função do estado.

-}

import Api exposing (Difficulty(..))
import Browser
import Browser.Events
import Html exposing (Html, aside, button, details, div, footer, h1, header, input, label, li, main_, p, span, summary, text, ul)
import Html.Attributes exposing (attribute, checked, class, classList, disabled, type_, value)
import Html.Events exposing (onCheck, onClick)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Set exposing (Set)
import Statistics
import Task
import Time
import Towers exposing (Board, Cell(..), Clue(..), ClueStatus(..), Position, Puzzle, Side(..))
import Svg exposing (path, svg)
import Svg.Attributes as SvgAttr


port saveBestTimes : Encode.Value -> Cmd msg



-- MAIN


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }



-- MODEL


{-| Dados que o main.js entrega na inicialização.
-}
type alias Flags =
    { darkTheme : Bool
    , bestTimes : Statistics.BestTimes
    }


type alias Model =
    { game : Maybe Game
    , difficulty : Difficulty
    , mode : InputMode
    , status : Status
    , darkTheme : Bool
    , bestTimes : Statistics.BestTimes
    }


{-| Uma partida em andamento. Puzzle e tabuleiro andam JUNTOS: não existe
tabuleiro sem puzzle, nem um tabuleiro de tamanho diferente do puzzle,
porque os dois só nascem juntos (em `GotPuzzle`). Antes do primeiro puzzle
chegar, `Model.game` é `Nothing`.
-}
type alias Game =
    { puzzle : Puzzle
    , board : Board
    , history : History
    , selected : Maybe Position
    , difficulty : Difficulty
    , startedAt : Maybe Time.Posix
    , elapsedSeconds : Int
    , hintsUsed : Int
    , solverUsed : Bool
    , finished : Bool
    }


type alias History =
    { past : List Board
    , future : List Board
    }


{-| O que o sistema está fazendo agora.

O template do Sudoku usava `loading : Bool` e `error : Maybe String`. Esses
dois campos permitem uma combinação sem sentido (carregando E com erro), que
o código precisava evitar "na mão". Com um custom type, só existem os três
estados possíveis.

-}
type Status
    = Idle
    | Thinking
    | HintGiven String
    | Failed String


{-| O que acontece ao digitar uma altura: ela vai para a casa, ou vira um
candidato anotado.
-}
type InputMode
    = Heights
    | Candidates


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { game = Nothing
      , difficulty = Medium
      , mode = Heights
      , status = Thinking
      , darkTheme = flags.darkTheme
      , bestTimes = flags.bestTimes
      }
    , Api.generate Medium GotPuzzle
    )



-- UPDATE


type Msg
    = NewGame Difficulty
    | GotPuzzle (Result String Puzzle)
    | CellClicked Position
    | HeightPressed Int
    | ErasePressed
    | ModeToggled
    | ThemeToggled Bool
    | MoveSelection Int Int
    | UndoPressed
    | RedoPressed
    | HintRequested
    | GotHint (Result String Api.Hint)
    | SolveRequested
    | GotSolution (Result String (List (List Int)))
    | ResetRequested
    | ErrorDismissed
    | ClockStarted Time.Posix
    | Tick Time.Posix


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NewGame difficulty ->
            ( { model | difficulty = difficulty, status = Thinking }
            , Api.generate difficulty GotPuzzle
            )

        GotPuzzle (Ok puzzle) ->
            ( { model
                | game =
                   
                    Just
                       
                        { puzzle = puzzle
                        , board = Towers.emptyBoard puzzle
                        , history = { past = [], future = [] }
                        , selected = Nothing
                        , difficulty = model.difficulty
                        , startedAt = Nothing
                        , elapsedSeconds = 0
                        , hintsUsed = 0
                        , solverUsed = False
                        , finished = False
                        }
                , status = Idle
              }
            , Task.perform ClockStarted Time.now
            )

        GotPuzzle (Err error) ->
            ( { model | status = Failed error }, Cmd.none )

        CellClicked position ->
            ( updateGame (\game -> { game | selected = Just position }) model, Cmd.none )

        HeightPressed height ->
            if boardInputLocked model then
                ( model, Cmd.none )

            else
                let
                    change =
                        case model.mode of
                            Heights ->
                                Towers.placeHeight Placed height

                            Candidates ->
                                \position -> Towers.toggleMark position height

                    -- Ignora alturas maiores que o tamanho da grade.
                    fits game =
                        height <= Towers.size game.puzzle

                    updatedModel =
                        updateGame
                            (\game ->
                                if fits game then
                                    changeSelected change game

                                else
                                    game
                            )
                            (dismissHint model)
                in
                finishIfComplete updatedModel

        ErasePressed ->
            if boardInputLocked model then
                ( model, Cmd.none )

            else
                finishIfComplete
                    (updateGame
                        (changeSelected 
                            (\position -> Towers.setCell position Empty)
                        )
                        (dismissHint model)
                    )

        ModeToggled ->
            ( { model | mode = toggleMode model.mode }, Cmd.none )

        ThemeToggled dark ->
            -- A troca de cores é feita pelo CSS do daisyUI; aqui só guardamos
            -- o estado do checkbox para a `view`.
            ( { model | darkTheme = dark }, Cmd.none )

        MoveSelection dRow dCol ->
            ( updateGame (moveSelection dRow dCol) model, Cmd.none )

        UndoPressed ->
            if boardInputLocked model then
                ( model, Cmd.none )

            else
                ( updateGame undoGame { model | status = Idle }
                , Cmd.none
                )

        RedoPressed ->
            if boardInputLocked model then
                ( model, Cmd.none )

            else
                ( updateGame redoGame { model | status = Idle }
                , Cmd.none
                )

        HintRequested ->
            askProlog Api.hint GotHint model

        GotHint (Ok { row, col, value, explanation }) ->
            finishIfComplete
                (updateGame
                    (\game ->
                        recordBoard
                            (Towers.placeHeight Revealed value ( row, col ) game.board)
                            { game
                                | selected = Just ( row, col )
                                , hintsUsed = game.hintsUsed + 1
                            }
                    )
                    { model | status = HintGiven explanation }
                )

        GotHint (Err error) ->
            ( { model | status = Failed error }, Cmd.none )

        SolveRequested ->
            -- Pedimos a solução a partir do tabuleiro VAZIO: se o jogador
            -- errou alguma casa, isso não impede o Prolog de resolver, e
            -- `revealSolution` corrige o erro na tela.
            askProlog (\puzzle _ -> Api.solve puzzle (Towers.emptyBoard puzzle)) GotSolution model

        GotSolution (Ok solution) ->
            finishIfComplete
                (updateGame
                    (\game ->
                        recordBoard
                            (Towers.revealSolution solution game.board)
                            { game | solverUsed = True }
                    )
                    { model | status = Idle }
                )

        GotSolution (Err error) ->
            ( { model | status = Failed error }, Cmd.none )

        ResetRequested ->
            if boardInputLocked model then
                ( model, Cmd.none )

            else
                ( updateGame
                    (\game -> recordBoard (Towers.emptyBoard game.puzzle) game)
                    { model | status = Idle }
                , Cmd.none
                )

        ErrorDismissed ->
            ( { model | status = Idle }, Cmd.none )

        ClockStarted startedAt ->
            finishIfComplete
                (updateGame (\game -> { game | startedAt = Just startedAt }) model)

        Tick now ->
            updateTimer now model


updateTimer : Time.Posix -> Model -> ( Model, Cmd Msg )
updateTimer now model =
    case model.game of
        Just game ->
            case game.startedAt of
                Just startedAt ->
                    if game.finished then
                        ( model, Cmd.none )

                    else
                        let
                            elapsed =
                                Statistics.elapsedSeconds startedAt now

                            updatedModel =
                                updateGame
                                    (\current -> { current | elapsedSeconds = elapsed })
                                    model
                        in
                        finishIfComplete updatedModel

                Nothing ->
                    ( model, Cmd.none )

        Nothing ->
            ( model, Cmd.none )


finishIfComplete : Model -> ( Model, Cmd Msg )
finishIfComplete model =
    case model.game of
        Just game ->
            case game.startedAt of
                Just _ ->
                    if game.finished || not (Towers.isComplete game.puzzle game.board) then
                        ( model, Cmd.none )

                    else
                        let
                            finishedGame =
                                { game | finished = True }

                            finishedModel =
                                { model
                                    | game = Just finishedGame
                                    , status = Idle
                                }

                            updatedRecords =
                                Statistics.recordIfEligible
                                    game.difficulty
                                    game.elapsedSeconds
                                    game.hintsUsed
                                    game.solverUsed
                                    model.bestTimes
                        in
                        if updatedRecords == model.bestTimes then
                            ( finishedModel, Cmd.none )

                        else
                            let
                                modelWithRecord =
                                    { finishedModel | bestTimes = updatedRecords }
                            in
                            ( modelWithRecord
                            , saveBestTimes (encodeBestTimes updatedRecords)
                            )

                Nothing ->
                    ( model, Cmd.none )

        Nothing ->
            ( model, Cmd.none )


encodeBestTimes : Statistics.BestTimes -> Encode.Value
encodeBestTimes records =
    Encode.object
        [ ( "easy", encodeMaybeInt records.easy )
        , ( "medium", encodeMaybeInt records.medium )
        , ( "hard", encodeMaybeInt records.hard )
        ]


encodeMaybeInt : Maybe Int -> Encode.Value
encodeMaybeInt maybeSeconds =
    case maybeSeconds of
        Just seconds ->
            Encode.int seconds

        Nothing ->
            Encode.null


{-| Limpa a mensagem de dica se ela estiver visível, voltando o estado
para `Idle`. Usada quando o jogador volta a interagir com o tabuleiro.
-}
dismissHint : Model -> Model
dismissHint model =
    case model.status of
        HintGiven _ ->
            { model | status = Idle }

        _ ->
            model


{-| Aplica uma alteração à partida, se houver uma. `Maybe.map` faz
exatamente isso: aplica a função dentro do `Just` e deixa `Nothing` como está.
-}
updateGame : (Game -> Game) -> Model -> Model
updateGame change model =
    { model | game = Maybe.map change model.game }


{-| Atualiza o tabuleiro e registra o estado anterior na pilha de "desfazer".
-}
recordBoard : Board -> Game -> Game
recordBoard nextBoard game =
    if nextBoard == game.board then
        game

    else
        { game
            | board = nextBoard
            , history =
                { past = game.board :: game.history.past
                , future = []
                }
        }


{-| Desfaz a última jogada, se houver. O tabuleiro atual vai para a pilha de "refazer".
-}
undoGame : Game -> Game
undoGame game =
    case game.history.past of
        previousBoard :: remainingPast ->
            { game
                | board = previousBoard
                , history =
                    { past = remainingPast
                    , future = game.board :: game.history.future
                    }
            }

        [] ->
            game



{-| Refaz a última jogada desfeita, se houver. O tabuleiro atual vai para a pilha de "desfazer".
-}
redoGame : Game -> Game
redoGame game =
    case game.history.future of
        nextBoard :: remainingFuture ->
            { game
                | board = nextBoard
                , history =
                    { past = game.board :: game.history.past
                    , future = remainingFuture
                    }
            }

        [] ->
            game


{-| Monta um pedido ao Prolog com o puzzle e o tabuleiro da partida atual.
O primeiro argumento é a função de `Api` (`Api.hint`, por exemplo), já
esperando só o puzzle, o tabuleiro e a mensagem de resposta.
-}
askProlog : (Puzzle -> Board -> (Result String a -> Msg) -> Cmd Msg) -> (Result String a -> Msg) -> Model -> ( Model, Cmd Msg )
askProlog request toMsg model =
    case model.game of
        Just game ->
            ( { model | status = Thinking }, request game.puzzle game.board toMsg )

        Nothing ->
            ( model, Cmd.none )


{-| Altera a casa selecionada, se houver uma. Recebe uma FUNÇÃO que diz o
que fazer com a casa (colocar, anotar, apagar): é uma função de ordem
superior.
-}
changeSelected : (Position -> Board -> Board) -> Game -> Game
changeSelected change game =
    case game.selected of
        Just position ->
            recordBoard (change position game.board) game

        Nothing ->
            game


moveSelection : Int -> Int -> Game -> Game
moveSelection dRow dCol game =
    let
        n =
            Towers.size game.puzzle

        -- `modBy n` faz a seleção "dar a volta" nas bordas.
        move ( row, col ) =
            ( modBy n (row + dRow), modBy n (col + dCol) )
    in
    { game | selected = Just (Maybe.withDefault ( 0, 0 ) (Maybe.map move game.selected)) }


toggleMode : InputMode -> InputMode
toggleMode mode =
    case mode of
        Heights ->
            Candidates

        Candidates ->
            Heights



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Browser.Events.onKeyDown keyDecoder
        , timerSubscription model
        ]


timerSubscription : Model -> Sub Msg
timerSubscription model =
    case model.game of
        Just game ->
            case game.startedAt of
                Just _ ->
                    if game.finished then
                        Sub.none

                    else
                        Time.every 1000 Tick

                Nothing ->
                    Sub.none

        Nothing ->
            Sub.none


{-| Teclas que não nos interessam fazem o decoder FALHAR, e um decoder que
falha não gera mensagem nenhuma.
-}
keyDecoder : Decoder Msg
keyDecoder =
    Decode.map4 keyToMsgWithModifiers
        (Decode.field "key" Decode.string)
        (Decode.field "ctrlKey" Decode.bool)
        (Decode.field "metaKey" Decode.bool)
        (Decode.field "shiftKey" Decode.bool)
        |> Decode.andThen identity

keyToMsgWithModifiers : String -> Bool -> Bool -> Bool -> Decoder Msg
keyToMsgWithModifiers key ctrlKey metaKey shiftKey =
    if ctrlKey || metaKey then
        case ( String.toLower key, shiftKey ) of
            ( "z", True ) ->
                Decode.succeed RedoPressed

            ( "z", False ) ->
                Decode.succeed UndoPressed

            ( "y", _ ) ->
                Decode.succeed RedoPressed

            _ ->
                Decode.fail "Atalho ignorado"

    else
        keyToMsg key


keyToMsg : String -> Decoder Msg
keyToMsg key =
    case key of
        "ArrowUp" ->
            Decode.succeed (MoveSelection -1 0)

        "ArrowDown" ->
            Decode.succeed (MoveSelection 1 0)

        "ArrowLeft" ->
            Decode.succeed (MoveSelection 0 -1)

        "ArrowRight" ->
            Decode.succeed (MoveSelection 0 1)

        "Backspace" ->
            Decode.succeed ErasePressed

        "Delete" ->
            Decode.succeed ErasePressed

        "n" ->
            Decode.succeed ModeToggled

        "N" ->
            Decode.succeed ModeToggled

        _ ->
            case String.toInt key of
                Just 0 ->
                    Decode.succeed ErasePressed

                Just n ->
                    Decode.succeed (HeightPressed n)

                Nothing ->
                    Decode.fail "tecla ignorada"



-- VIEW


view : Model -> Html Msg
view model =
    div
        [ class "app"
        , attribute "data-mode"
            (case model.mode of
                Heights ->
                    "numbers"

                Candidates ->
                    "marks"
            )
        ]
        [ header [ class "app-header" ]
            [ div [ class "app-container app-header-content" ]
                [ h1 [ class "app-title" ] [ text "Torres Latinas" ]
                , span [ class "app-subtitle" ] [ text "Prolog + Elm" ]
                , viewThemeToggle model
                ]
            ]
        , main_ [ class "app-main" ]
            [ div [ class "app-container game" ]
                [ case model.game of
                    Just game ->
                        viewTowers game

                    Nothing ->
                        div [ class "towers towers--waiting" ] []
                , aside [ class "side-panel" ]
                    [ span [ class "panel-label" ] [ text "Novo jogo" ]
                    , viewDifficulty model
                    , div [ class "message-area" ] [ viewMessages model ]
                    , span [ class "panel-label" ] [ text "Estatísticas" ]
                    , viewStatistics model
                    , span [ class "panel-label" ] [ text "Alturas" ]
                    , viewHeightPad model
                    , span [ class "panel-label" ] [ text "Histórico" ]
                    , viewHistoryControls model
                    , span [ class "panel-label" ] [ text "Ajuda" ]
                    , viewActions model
                    , viewRules
                    ]
                ]
            ]
        , footer [ class "app-footer" ]
            [ text "Teclado: "
            , kbd [] [ text "1–6" ]
            , text " coloca, "
            , kbd [] [ text "setas" ]
            , text " movem, "
            , kbd [] [ text "⌫" ]
            , text " apaga, "
            , kbd [] [ text "N" ]
            , text " liga os candidatos."
            ]
        ]


viewThemeToggle : Model -> Html Msg
viewThemeToggle model =
    label [ class "theme-toggle", attribute "aria-label" "Alternar tema claro/escuro" ]
        [ input
            [ type_ "checkbox"
            , class "theme-controller"
            , value "dark"
            , checked model.darkTheme
            , onCheck ThemeToggled
            ]
            []
        , span [ class "swap-off" ] [ text "☀" ]
        , span [ class "swap-on" ] [ text "☾" ]
        ]


kbd : List (Html.Attribute msg) -> List (Html msg) -> Html msg
kbd =
    Html.node "kbd"


isThinking : Model -> Bool
isThinking model =
    model.status == Thinking


boardInputLocked : Model -> Bool
boardInputLocked model =
    isThinking model
        || (case model.game of
                Just game ->
                    game.finished || Towers.isComplete game.puzzle game.board

                Nothing ->
                    True
           )


viewDifficulty : Model -> Html Msg
viewDifficulty model =
    let
        option difficulty =
            button
                [ class "difficulty-option"
                , classList [ ( "difficulty-option--active", difficulty == model.difficulty ) ]
                , disabled (isThinking model)
                , onClick (NewGame difficulty)
                ]
                [ text (Api.difficultyLabel difficulty) ]
    in
    div [ class "difficulty-picker" ] (List.map option [ Easy, Medium, Hard ])


viewMessages : Model -> Html Msg
viewMessages model =
    let
        isGameComplete =
            case model.game of
                Just game ->
                    Towers.isComplete game.puzzle game.board

                Nothing ->
                    False
    in
    if isGameComplete then
        case model.game of
            Just game ->
                div [ class "message message--success" ]
                    [ text (completionMessage game.board game.puzzle) ]

            Nothing ->
                text ""

    else
        case model.status of
            Failed error ->
                div [ class "message message--error" ]
                    [ span [] [ text error ]
                    , button [ class "message-close", onClick ErrorDismissed ] [ text "✕" ]
                    ]

            Thinking ->
                div [ class "message message--loading" ]
                    [ span [ class "spinner" ] []
                    , span [] [ text "O Prolog está pensando..." ]
                    ]

            HintGiven explanation ->
                div [ class "message message--info" ]
                    [ span [] [ text ("Dica: " ++ explanation) ]
                    , button [ class "message-close", onClick ErrorDismissed ] [ text "x" ]
                    ]

            Idle ->
                text ""


completionMessage : Board -> Puzzle -> String
completionMessage board puzzle =
    let
        revealed =
            Towers.positions (Towers.size puzzle)
                |> List.any (\pos -> Towers.isRevealed (Towers.cellAt pos board))
    in
    if revealed then
        "Resolvido (com ajuda do Prolog)."

    else
        "Parabéns! Você ergueu a cidade inteira!"


{-| O tabuleiro com as pistas em volta, numa grade (N+2) x (N+2):

    canto pistas de cima canto

    pistas tabuleiro N x N pistas

    canto pistas de baixo canto

O tamanho N vai para o CSS como a variável `--n` (atributo `style`); com
ela o CSS divide o tabuleiro em N colunas e ajusta o tamanho da fonte.

-}
viewTowers : Game -> Html Msg
viewTowers game =
    let
        n =
            Towers.size game.puzzle

        corner =
            span [ class "towers-corner" ] []

        clueStrip side =
            div [ class ("clues clues--" ++ sideName side) ]
                (List.indexedMap (viewClue game side) (Towers.clues side game.puzzle))
    in
    -- `Html.Attributes.style "--n" ...` NÃO funciona: o Elm aplica estilos
    -- com `elemento.style[nome] = valor`, que ignora variáveis CSS. Por isso
    -- escrevemos o atributo `style` inteiro, como texto.
    div [ class "towers", attribute "style" ("--n: " ++ String.fromInt n) ]
        [ corner
        , clueStrip Top
        , corner
        , clueStrip Left
        , viewBoard game
        , clueStrip Right
        , corner
        , clueStrip Bottom
        , corner
        ]


sideName : Side -> String
sideName side =
    case side of
        Top ->
            "top"

        Bottom ->
            "bottom"

        Left ->
            "left"

        Right ->
            "right"


viewClue : Game -> Side -> Int -> Clue -> Html Msg
viewClue game side index clue =
    let
        status =
            Towers.clueStatus game.puzzle game.board side index
    in
    span
        [ class "clue"
        , classList
            [ ( "clue--ok", status == Satisfied )
            , ( "clue--wrong", status == Violated )
            ]
        ]
        [ case clue of
            Sees k ->
                text (String.fromInt k)

            NoClue ->
                text ""
        ]


viewBoard : Game -> Html Msg
viewBoard game =
    let
        conflicts =
            Towers.conflicts game.puzzle game.board
    in
    div
        [ class "board"
        , classList [ ( "board--solved", Towers.isComplete game.puzzle game.board ) ]
        ]
        (List.map (viewCell game conflicts) (Towers.positions (Towers.size game.puzzle)))


viewCell : Game -> Set Position -> Position -> Html Msg
viewCell game conflicts (( row, col ) as position) =
    let
        cell =
            Towers.cellAt position game.board

        height =
            Towers.valueOf cell

        isRelated =
            case game.selected of
                Just ( selRow, selCol ) ->
                    selRow == row || selCol == col

                Nothing ->
                    False

        selectedHeight =
            game.selected
                |> Maybe.andThen (\sel -> Towers.valueOf (Towers.cellAt sel game.board))

        -- Cada casa desenha os pontos da sua borda direita e de baixo.
        dot neighbor direction =
            if Towers.hasDot position neighbor game.puzzle then
                [ span [ class ("dot dot--" ++ direction) ] [] ]

            else
                []
    in
    button
        [ class "cell"
        , classList
            [ ( "cell--selected", game.selected == Just position )
            , ( "cell--related", isRelated )
            , ( "cell--same-value", height /= Nothing && height == selectedHeight )
            , ( "cell--conflict", Set.member position conflicts )
            , ( "cell--guess", isPlaced cell )
            , ( "cell--revealed", Towers.isRevealed cell )
            ]
        , attribute "aria-label"
            ("Linha " ++ String.fromInt (row + 1) ++ ", coluna " ++ String.fromInt (col + 1))
        , onClick (CellClicked position)
        ]
        ((case cell of
            Marks marks ->
                viewCornerMarks selectedHeight marks

            _ ->
                span [ class "cell-value" ]
                    [ text (Maybe.map String.fromInt height |> Maybe.withDefault "") ]
         )
            :: dot ( row, col + 1 ) "right"
            ++ dot ( row + 1, col ) "down"
        )


isPlaced : Cell -> Bool
isPlaced cell =
    case cell of
        Placed _ ->
            True

        _ ->
            False


viewCornerMarks : Maybe Int -> Set Int -> Html Msg
viewCornerMarks selectedHeight marks =
    let
        viewMark n =
            span
                [ class "corner-mark"
                , classList [ ( "corner-mark--highlight", Just n == selectedHeight ) ]
                ]
                [ text (String.fromInt n) ]
    in
    div [ class "corner-marks" ] (List.map viewMark (Set.toList marks))


viewHeightPad : Model -> Html Msg
viewHeightPad model =
    let
        noSelection =
            Maybe.andThen .selected model.game == Nothing

        inputDisabled =
            noSelection || boardInputLocked model

        maxHeight =
            Maybe.map (.puzzle >> Towers.size) model.game |> Maybe.withDefault 0

        heightKey n =
            button
                [ class "number-key"
                , disabled inputDisabled
                , onClick (HeightPressed n)
                ]
                [ text (String.fromInt n) ]

        marking =
            model.mode == Candidates
    in
    div [ class "number-pad" ]
        (List.map heightKey (List.range 1 maxHeight)
            ++ [ button
                    [ class "erase-key"
                    , disabled inputDisabled
                    , onClick ErasePressed
                    ]
                    [ text "⌫" ]
               , button
                    [ class "mode-toggle"
                    , classList [ ( "mode-toggle--on", marking ) ]
                    , onClick ModeToggled
                    ]
                    [ text
                        (if marking then
                            "✎ Anotando"

                         else
                            "✎ Candidatos"
                        )
                    ]
               ]
        )


viewActions : Model -> Html Msg
viewActions model =
    let
        solved =
            case model.game of
                Just game ->
                    Towers.isComplete game.puzzle game.board

                Nothing ->
                    True

        nothingToAsk =
            isThinking model || solved
    in
    div [ class "actions" ]
        [ button [ class "action-button action-button--hint", disabled nothingToAsk, onClick HintRequested ] [ text "Dica" ]
        , button [ class "action-button action-button--solve", disabled nothingToAsk, onClick SolveRequested ] [ text "Resolver" ]
        , button [ class "action-button action-button--reset", disabled (boardInputLocked model), onClick ResetRequested ] [ text "Limpar" ]
        ]


viewHistoryControls : Model -> Html Msg
viewHistoryControls model =
    let
        ( canUndo, canRedo ) =
            case model.game of
                Just game ->
                    ( not (List.isEmpty game.history.past)
                    , not (List.isEmpty game.history.future)
                    )

                Nothing ->
                    ( False, False )
    in
    div [ class "history-controls" ]
        [ button
            [ class "history-button"
            , disabled (boardInputLocked model || not canUndo)
            , onClick UndoPressed
            , attribute "title" "Desfazer (⌘Z no Mac; Ctrl+Z no Windows/Linux)"
            ]
            [ undoIcon, text "Desfazer" ]
        , button
            [ class "history-button"
            , disabled (boardInputLocked model || not canRedo)
            , onClick RedoPressed
            , attribute "title" "Refazer (⌘⇧Z no Mac; Ctrl+Y no Windows/Linux)"
            ]
            [ redoIcon, text "Refazer" ]
        ]


undoIcon : Html Msg
undoIcon =
    svg
        [ SvgAttr.viewBox "0 0 24 24"
        , SvgAttr.width "18"
        , SvgAttr.height "18"
        , SvgAttr.fill "none"
        , SvgAttr.stroke "currentColor"
        , SvgAttr.strokeWidth "2"
        , SvgAttr.strokeLinecap "round"
        , SvgAttr.strokeLinejoin "round"
        , attribute "aria-hidden" "true"
        ]
        [ path [ SvgAttr.d "M3 7v6h6" ] []
        , path [ SvgAttr.d "M21 17a9 9 0 0 0-15-6.7L3 13" ] []
        ]


redoIcon : Html Msg
redoIcon =
    svg
        [ SvgAttr.viewBox "0 0 24 24"
        , SvgAttr.width "18"
        , SvgAttr.height "18"
        , SvgAttr.fill "none"
        , SvgAttr.stroke "currentColor"
        , SvgAttr.strokeWidth "2"
        , SvgAttr.strokeLinecap "round"
        , SvgAttr.strokeLinejoin "round"
        , attribute "aria-hidden" "true"
        ]
        [ path [ SvgAttr.d "M21 7v6h-6" ] []
        , path [ SvgAttr.d "M3 17a9 9 0 0 1 15-6.7L21 13" ] []
        ]


viewRules : Html Msg
viewRules =
    details [ class "rules" ]
        [ summary [] [ text "Como jogar" ]
        , ul []
            [ li [] [ text "Cada casa é um prédio de altura 1 a N. Cada linha e cada coluna tem todas as alturas, sem repetir." ]
            , li [] [ text "O número na borda diz quantos prédios se veem dali. Um prédio esconde os mais baixos atrás dele." ]
            , li [] [ text "Um ponto entre duas casas diz que as alturas diferem de exatamente 1. Sem ponto, a diferença NÃO é 1." ]
            ]
        , p [] [ text "Números na borda ficam verdes quando a linha cumpre a pista e vermelhos quando não cumpre." ]
        ]


viewStatistics : Model -> Html Msg
viewStatistics model =
    case model.game of
        Just game ->
            let
                best =
                    Statistics.bestTimeFor game.difficulty model.bestTimes
                        |> Maybe.map Statistics.formatTime
                        |> Maybe.withDefault "—"
            in
            div [ class "game-stats" ]
                [ p [ class "game-stat" ]
                    [ span [] [ text "Tempo" ]
                    , span [] [ text (Statistics.formatTime game.elapsedSeconds) ]
                    ]
                , p [ class "game-stat" ]
                    [ span [] [ text "Dicas usadas" ]
                    , span [] [ text (String.fromInt game.hintsUsed) ]
                    ]
                , p [ class "game-stat" ]
                    [ span [] [ text "Recorde sem ajuda" ]
                    , span [] [ text best ]
                    ]
                ]

        Nothing ->
            text ""
