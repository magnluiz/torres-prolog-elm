module Towers exposing
    ( Board
    , Cell(..)
    , Clue(..)
    , ClueStatus(..)
    , Position
    , Puzzle
    , RawPuzzle
    , Side(..)
    , cellAt
    , clueStatus
    , clues
    , conflicts
    , emptyBoard
    , fromRaw
    , hasDot
    , isComplete
    , isRevealed
    , placeHeight
    , positions
    , revealSolution
    , setCell
    , size
    , toLists
    , toRaw
    , toggleMark
    , valueOf
    , visibleCount
    )

{-| Regras e representação das Torres Latinas, do lado do Elm.

Este módulo é PURO: não faz HTTP e não sabe nada de HTML. A busca pela
solução fica no Prolog; aqui estão só as verificações instantâneas que a tela
precisa a cada tecla (repetições, pontos e pistas de linhas completas).

Regras do jogo (as mesmas de backend/prolog/torres.pl):

1.  cada linha e cada coluna tem as alturas 1..N, sem repetir;
2.  uma pista na borda diz quantos prédios se veem daquele lado;
3.  há um ponto entre duas casas vizinhas SE E SOMENTE SE as alturas diferem
    de exatamente 1.

-}

import Array exposing (Array)
import Set exposing (Set)



-- TIPOS


{-| Posição de uma casa: (linha, coluna), ambas de 0 a N-1.
-}
type alias Position =
    ( Int, Int )


{-| Uma pista de borda. Poderíamos usar `Int` com 0 para "sem pista", como faz
o JSON, mas aí todo código que lê a pista teria de lembrar que 0 é especial.
Com um custom type, o compilador obriga a tratar os dois casos.
-}
type Clue
    = NoClue
    | Sees Int


{-| Os quatro lados de onde se olha a grade.
-}
type Side
    = Top
    | Bottom
    | Left
    | Right


{-| O puzzle: tamanho, pistas e pontos. Ele não muda durante a partida.

O tipo é exportado sem os campos visíveis para quem monta: a única forma de
criar um `Puzzle` fora deste módulo é `fromRaw`, que confere as dimensões.
(Um `type alias` de record não pode ser opaco; por isso embrulhamos o record
num custom type de um construtor só, `Puzzle`, que não é exportado.)

-}
type Puzzle
    = Puzzle
        { size : Int
        , top : Array Clue
        , bottom : Array Clue
        , left : Array Clue
        , right : Array Clue
        , dots : Set ( Position, Position )
        }


{-| O puzzle no formato da API: listas de inteiros, 0 = sem pista, e grades
de 0/1 para os pontos (veja a representação em torres.pl).
-}
type alias RawPuzzle =
    { top : List Int
    , bottom : List Int
    , left : List Int
    , right : List Int
    , hdots : List (List Int)
    , vdots : List (List Int)
    }


{-| Uma casa do tabuleiro do jogador.

Não há "pistas fixas" dentro da grade, como no Sudoku: toda casa começa vazia.

-}
type Cell
    = Placed Int -- altura colocada pelo jogador
    | Revealed Int -- altura revelada pelo Prolog (dica ou "resolver")
    | Marks (Set Int) -- casa vazia com candidatos anotados
    | Empty


{-| O tabuleiro: o tamanho e N x N casas num Array, linha por linha.

O tamanho fica junto das casas para que nenhuma função precise recebê-lo à
parte (e, portanto, nunca receba um tamanho errado).

-}
type Board
    = Board Int (Array Cell)


{-| Situação de uma pista de borda, para a tela colorir.
-}
type ClueStatus
    = Unchecked -- sem pista, ou a linha ainda tem casas vazias
    | Satisfied
    | Violated



-- PUZZLE


{-| Converte o formato da API num `Puzzle`, conferindo as dimensões.

`Result String Puzzle` é o jeito do Elm de dizer "ou deu certo, ou aqui está
o motivo". Quem chama (o decoder em Api.elm) transforma um `Err` em falha
de decodificação, então um JSON malformado nunca vira um puzzle inválido.

-}
fromRaw : RawPuzzle -> Result String Puzzle
fromRaw raw =
    let
        n =
            List.length raw.top

        hasLength k list =
            List.length list == k

        shapeOk =
            n
                >= 2
                && List.all (hasLength n) [ raw.bottom, raw.left, raw.right ]
                && hasLength n raw.hdots
                && List.all (hasLength (n - 1)) raw.hdots
                && hasLength (n - 1) raw.vdots
                && List.all (hasLength n) raw.vdots

        toClues =
            List.map toClue >> Array.fromList
    in
    if shapeOk then
        Ok
            (Puzzle
                { size = n
                , top = toClues raw.top
                , bottom = toClues raw.bottom
                , left = toClues raw.left
                , right = toClues raw.right
                , dots =
                    Set.union
                        (dotPairs (\r c -> ( ( r, c ), ( r, c + 1 ) )) raw.hdots)
                        (dotPairs (\r c -> ( ( r, c ), ( r + 1, c ) )) raw.vdots)
                }
            )

    else
        Err "As dimensões do puzzle não batem."


toClue : Int -> Clue
toClue n =
    if n == 0 then
        NoClue

    else
        Sees n


fromClue : Clue -> Int
fromClue clue =
    case clue of
        NoClue ->
            0

        Sees n ->
            n


{-| Lê uma grade de 0/1 e devolve o conjunto de pares de casas ligados por
um ponto. `pairAt` diz qual par corresponde à linha r e coluna c da grade.
-}
dotPairs : (Int -> Int -> ( Position, Position )) -> List (List Int) -> Set ( Position, Position )
dotPairs pairAt grid =
    grid
        |> List.indexedMap
            (\r row ->
                List.indexedMap (\c dot -> ( pairAt r c, dot == 1 )) row
            )
        |> List.concat
        |> List.filter Tuple.second
        |> List.map Tuple.first
        |> Set.fromList


{-| O caminho inverso, para mandar o puzzle de volta ao backend.
-}
toRaw : Puzzle -> RawPuzzle
toRaw (Puzzle p) =
    let
        dotGrid rows cols pairAt =
            List.map
                (\r ->
                    List.map
                        (\c ->
                            if Set.member (pairAt r c) p.dots then
                                1

                            else
                                0
                        )
                        (List.range 0 (cols - 1))
                )
                (List.range 0 (rows - 1))

        toInts =
            Array.toList >> List.map fromClue
    in
    { top = toInts p.top
    , bottom = toInts p.bottom
    , left = toInts p.left
    , right = toInts p.right
    , hdots = dotGrid p.size (p.size - 1) (\r c -> ( ( r, c ), ( r, c + 1 ) ))
    , vdots = dotGrid (p.size - 1) p.size (\r c -> ( ( r, c ), ( r + 1, c ) ))
    }


size : Puzzle -> Int
size (Puzzle p) =
    p.size


{-| As pistas de um lado, na ordem das linhas (ou colunas).
-}
clues : Side -> Puzzle -> List Clue
clues side (Puzzle p) =
    Array.toList
        (case side of
            Top ->
                p.top

            Bottom ->
                p.bottom

            Left ->
                p.left

            Right ->
                p.right
        )


{-| Há um ponto entre estas duas casas? A ordem dos argumentos não importa.
-}
hasDot : Position -> Position -> Puzzle -> Bool
hasDot a b (Puzzle p) =
    Set.member ( min a b, max a b ) p.dots


{-| Todas as posições de uma grade N x N, na ordem de leitura.
-}
positions : Int -> List Position
positions n =
    List.range 0 (n - 1)
        |> List.concatMap (\row -> List.map (\col -> ( row, col )) (List.range 0 (n - 1)))


{-| Todos os pares de casas vizinhas: à direita e abaixo de cada casa.
-}
neighborPairs : Int -> List ( Position, Position )
neighborPairs n =
    positions n
        |> List.concatMap
            (\( r, c ) ->
                List.filter (\( _, ( r2, c2 ) ) -> r2 < n && c2 < n)
                    [ ( ( r, c ), ( r, c + 1 ) ), ( ( r, c ), ( r + 1, c ) ) ]
            )



-- TABULEIRO


emptyBoard : Puzzle -> Board
emptyBoard (Puzzle p) =
    Board p.size (Array.repeat (p.size * p.size) Empty)


{-| O tabuleiro no formato da API: lista de linhas, 0 nas casas sem altura.
-}
toLists : Board -> List (List Int)
toLists (Board n cells) =
    cells
        |> Array.toList
        |> List.map (valueOf >> Maybe.withDefault 0)
        |> chunksOf n


chunksOf : Int -> List a -> List (List a)
chunksOf n list =
    case list of
        [] ->
            []

        _ ->
            List.take n list :: chunksOf n (List.drop n list)


valueOf : Cell -> Maybe Int
valueOf cell =
    case cell of
        Placed n ->
            Just n

        Revealed n ->
            Just n

        Marks _ ->
            Nothing

        Empty ->
            Nothing


isRevealed : Cell -> Bool
isRevealed cell =
    case cell of
        Revealed _ ->
            True

        _ ->
            False


cellAt : Position -> Board -> Cell
cellAt ( row, col ) (Board n cells) =
    Array.get (row * n + col) cells
        |> Maybe.withDefault Empty


setCell : Position -> Cell -> Board -> Board
setCell ( row, col ) cell (Board n cells) =
    Board n (Array.set (row * n + col) cell cells)


{-| Coloca uma altura e apaga esse candidato das casas da mesma linha e
coluna, que agora não podem mais ter essa altura.
-}
placeHeight : (Int -> Cell) -> Int -> Position -> Board -> Board
placeHeight toCell height (( row, col ) as position) (Board n cells) =
    let
        dropMark index cell =
            case cell of
                Marks marks ->
                    if index // n == row || modBy n index == col then
                        fromMarks (Set.remove height marks)

                    else
                        cell

                _ ->
                    cell
    in
    Board n (Array.indexedMap dropMark cells)
        |> setCell position (toCell height)


{-| Liga ou desliga um candidato numa casa sem altura.
-}
toggleMark : Position -> Int -> Board -> Board
toggleMark position n board =
    case cellAt position board of
        Empty ->
            setCell position (Marks (Set.singleton n)) board

        Marks marks ->
            if Set.member n marks then
                setCell position (fromMarks (Set.remove n marks)) board

            else
                setCell position (Marks (Set.insert n marks)) board

        _ ->
            board


{-| Construtor inteligente: nunca deixa existir `Marks` com o conjunto vazio,
que seria só um `Empty` disfarçado.
-}
fromMarks : Set Int -> Cell
fromMarks marks =
    if Set.isEmpty marks then
        Empty

    else
        Marks marks


{-| Copia as alturas de uma solução (vinda do Prolog) para as casas, como
`Revealed`. Casas que o jogador já acertou continuam `Placed`.
-}
revealSolution : List (List Int) -> Board -> Board
revealSolution solution (Board n cells) =
    let
        solutionArray =
            Array.fromList (List.concat solution)

        reveal index cell =
            case ( Array.get index solutionArray, valueOf cell ) of
                ( Just answer, Just current ) ->
                    if answer == current then
                        cell

                    else
                        Revealed answer

                ( Just answer, Nothing ) ->
                    Revealed answer

                ( Nothing, _ ) ->
                    cell
    in
    Board n (Array.indexedMap reveal cells)



-- VERIFICAÇÕES


{-| Quantos prédios de uma linha se veem a partir do começo da lista.

É um `foldl` que carrega um par (maior altura vista até agora, quantidade
de visíveis). A mesma ideia de `visible/2` em torres.pl, só que aqui
calculamos para uma linha já conhecida, enquanto o Prolog também consegue
rodar "ao contrário" e restringir alturas desconhecidas.

-}
visibleCount : List Int -> Int
visibleCount heights =
    heights
        |> List.foldl
            (\height ( tallest, count ) ->
                if height > tallest then
                    ( height, count + 1 )

                else
                    ( tallest, count )
            )
            ( 0, 0 )
        |> Tuple.second


{-| As alturas de uma linha (ou coluna) do jeito que são vistas de um lado.
-}
lineFrom : Side -> Int -> Board -> List (Maybe Int)
lineFrom side index ((Board n _) as board) =
    let
        indexes =
            List.range 0 (n - 1)

        heightAt position =
            valueOf (cellAt position board)
    in
    case side of
        Top ->
            List.map (\row -> heightAt ( row, index )) indexes

        Bottom ->
            List.reverse (List.map (\row -> heightAt ( row, index )) indexes)

        Left ->
            List.map (\col -> heightAt ( index, col )) indexes

        Right ->
            List.reverse (List.map (\col -> heightAt ( index, col )) indexes)


{-| `Just` a lista inteira se todos os elementos forem `Just`; senão,
`Nothing`. (Existe pronta no pacote elm-community/maybe-extra.)
-}
allJust : List (Maybe a) -> Maybe (List a)
allJust =
    List.foldr (Maybe.map2 (::)) (Just [])


{-| A pista do lado `side`, posição `index`, já está cumprida ou quebrada?
Só dá para saber quando a linha está completa.
-}
clueStatus : Puzzle -> Board -> Side -> Int -> ClueStatus
clueStatus puzzle board side index =
    case List.drop index (clues side puzzle) |> List.head of
        Just (Sees expected) ->
            case allJust (lineFrom side index board) of
                Just heights ->
                    if visibleCount heights == expected then
                        Satisfied

                    else
                        Violated

                Nothing ->
                    Unchecked

        _ ->
            Unchecked


{-| Casas que quebram a regra 1 (altura repetida na linha ou coluna) ou a
regra 3 (vizinhas com alturas incompatíveis com o ponto, ou com a falta
dele). Só olha casas preenchidas, então dá para chamar a cada tecla.
-}
conflicts : Puzzle -> Board -> Set Position
conflicts puzzle ((Board n _) as board) =
    let
        filled =
            positions n
                |> List.filterMap
                    (\pos -> Maybe.map (\h -> ( pos, h )) (valueOf (cellAt pos board)))

        repeated ( ( r, c ) as pos, h ) =
            List.any
                (\( ( r2, c2 ) as other, h2 ) -> other /= pos && h == h2 && (r == r2 || c == c2))
                filled

        wrongDot ( a, b ) =
            case ( valueOf (cellAt a board), valueOf (cellAt b board) ) of
                ( Just ha, Just hb ) ->
                    (abs (ha - hb) == 1) /= hasDot a b puzzle

                _ ->
                    False

        dotOffenders =
            neighborPairs n
                |> List.filter wrongDot
                |> List.concatMap (\( a, b ) -> [ a, b ])
    in
    filled
        |> List.filter repeated
        |> List.map Tuple.first
        |> (++) dotOffenders
        |> Set.fromList


{-| O jogo termina quando todas as casas têm altura, não há conflitos e
nenhuma pista está quebrada. Como o Prolog só gera puzzles de solução
única, isso garante que o jogador chegou exatamente à solução.
-}
isComplete : Puzzle -> Board -> Bool
isComplete puzzle ((Board n cells) as board) =
    let
        allFilled =
            List.all (\cell -> valueOf cell /= Nothing) (Array.toList cells)

        cluesOk =
            [ Top, Bottom, Left, Right ]
                |> List.all
                    (\side ->
                        List.range 0 (n - 1)
                            |> List.all (\i -> clueStatus puzzle board side i /= Violated)
                    )
    in
    allFilled && Set.isEmpty (conflicts puzzle board) && cluesOk
