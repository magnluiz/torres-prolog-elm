/*  explicador.pl: motor de inferência explicável para dicas.
    Analisa as restrições e gera justificativas em linguagem natural.
*/

:- module(explicador, [explain_cell/6, explain_cell_deductive/6]).
:- use_module(library(clpfd)).
:- use_module(library(lists)).

%!  explain_cell(+Puzzle, +Board, +Row, +Col, +Value, -Explanation) is det.
%  Examina a célula (Row, Col) do tabuleiro Board e explica por que ela deve receber o valor Value.
explain_cell(Puzzle, Board, Row, Col, Value, Explanation) :-
    (   explain_cell_deductive(Puzzle, Board, Row, Col, Value, Explanation)

    ->  true

        % Caso contrário, gera uma explicação genérica
    ;   Row1 is Row + 1,
        Col1 is Col + 1,
        build_explanation(general_case, [Value, Row1, Col1], Explanation)
    ),
    !.


%! explain_cell_deductive(+Puzzle, +Board, +Row, +Col, +Value, -Explanation) is semidet.
%  Tem sucesso apenas se houver uma dedução pedagógica direta (casos 1 a 4).
explain_cell_deductive(Puzzle, Board, Row, Col, Value, Explanation) :-
    length(Board, N),
    Row1 is Row + 1,
    Col1 is Col + 1,

    (   % Caso 1: É a única altura que falta na linha
        nth0(Row, Board, FullRow),
        delete(FullRow, 0, PresentRow),
        numlist(1, N, All),
        subtract(All, PresentRow, [Value])

    ->  build_explanation(single_in_row, [Row1, Value], Explanation)

        % Caso 2: É a única altura que falta na coluna
    ;   transpose(Board, Cols),
        nth0(Col, Cols, FullCol),
        delete(FullCol, 0, PresentCol),
        numlist(1, N, AllC),
        subtract(AllC, PresentCol, [Value])

    ->  build_explanation(single_in_col, [Col1, Value], Explanation)

        % Caso 3: É forçada pela interseção de dois pontos Kropki
    ;   double_dot_forced(Puzzle, Board, Row, Col, Value, Explanation)

    ->  true

        % Caso 4: É forçada por um ponto Kropki com vizinho conhecido
    ;   kropki_dot_forced(Puzzle, Board, Row, Col, Value, Explanation)

    ->  true

        % Caso 5: É forçada por uma pista de borda
    ;   edge_clue_forced(Puzzle, Row, Col, Value, N, Explanation)

    ->  true
    ).

%!  double_dot_forced(+Puzzle, +Board, +Row, +Col, +Value, -Explanation) is semidet.
%   Verifica se a célula possui dois vizinhos preenchidos com ponto Kropki cuja
%   interseção dos candidatos obriga um único valor.
double_dot_forced(Puzzle, Board, Row, Col, Value, Explanation) :-
    length(Board, N),
    findall(
        neighbor(NR, NC, NV),
        dot_neighbor(Puzzle, Board, Row, Col, NR, NC, NV),
        Neighbors
    ),
    Neighbors = [_, _ | _],
    select(neighbor(R1, C1, V1), Neighbors, Rest),
    member(neighbor(R2, C2, V2), Rest),
    kropki_cands(V1, N, Cands1),
    kropki_cands(V2, N, Cands2),
    intersection(Cands1, Cands2, [Value]),
    !,
    R1_1 is R1 + 1, C1_1 is C1 + 1,
    R2_1 is R2 + 1, C2_1 is C2 + 1,
    build_explanation(double_dot, [R1_1, C1_1, V1, R2_1, C2_1, V2, Value], Explanation).

%!  kropki_cands(+NeighborValue, +N, -Candidates) is det.
%   Gera a lista de alturas candidatas (entre 1 e N) que diferem por 1
%   do valor do vizinho.
kropki_cands(V, N, Cands) :-
    Low is V - 1,
    High is V + 1,
    findall(C, (member(C, [Low, High]), C >= 1, C =< N), Cands).

%!  dot_neighbor(+Puzzle, +Board, +Row, +Col, -NRow, -NCol, -NeighborValue) is nondet.
%   Localiza qualquer casa vizinha (nas 4 direções) que compartilhe um ponto
%   Kropki com (Row, Col) e que já esteja preenchida no tabuleiro.
dot_neighbor(Puzzle, Board, Row, Col, NRow, NCol, Neighbor) :-
    Puzzle = [_, _, _, _, HDots, VDots],
    length(Board, N),
    MaxIndex is N - 1,
    (   % Esquerda
        Col > 0, ColLeft is Col - 1,
        nth0(Row, HDots, HRow), 
        nth0(ColLeft, HRow, 1),

        nth0(Row, Board, BRow), 
        nth0(ColLeft, BRow, Neighbor),

        Neighbor > 0, NRow = Row, NCol = ColLeft

    ;   % Direita
        Col < MaxIndex, ColRight is Col + 1,
        nth0(Row, HDots, HRow), 
        nth0(Col, HRow, 1),

        nth0(Row, Board, BRow), 
        nth0(ColRight, BRow, Neighbor),

        Neighbor > 0, NRow = Row, NCol = ColRight

    ;   % Acima
        Row > 0, RowUp is Row - 1,
        nth0(RowUp, VDots, VRow), 
        nth0(Col, VRow, 1),

        nth0(RowUp, Board, BRowUp), 
        nth0(Col, BRowUp, Neighbor),

        Neighbor > 0, NRow = RowUp, NCol = Col

    ;   % Abaixo
        Row < MaxIndex, RowDown is Row + 1,
        nth0(Row, VDots, VRow), 
        nth0(Col, VRow, 1),

        nth0(RowDown, Board, BRowDown), 
        nth0(Col, BRowDown, Neighbor),

        Neighbor > 0, NRow = RowDown, NCol = Col
    ).

%!  kropki_dot_forced(+Puzzle, +Board, +Row, +Col, +Value, -Explanation) is semidet.
%   Verifica se a célula possui um vizinho com ponto Kropki que obriga a altura Value.
kropki_dot_forced(Puzzle, Board, Row, Col, Value, Explanation) :-
    Puzzle = [_, _, _, _, HDots, VDots],
    length(Board, N),
    MaxIndex is N - 1,

    (   % Vizinho à esquerda com ponto
        Col > 0, 
        ColLeft is Col -1,
        
        nth0(Row, HDots, HRow),
        nth0(ColLeft, HRow, 1),

        nth0(Row, Board, BRow),
        nth0(ColLeft, BRow, Neighbor),
        Neighbor > 0,
        alternative_eliminated(Neighbor, Value, N, Board, Row, Col)

    ->  ColLeft1 is ColLeft + 1,
        Row1 is Row + 1,
        build_explanation(kropki_dot, [Row1, ColLeft1, Neighbor, Value], Explanation)

        % Vizinho à direita com ponto
    ;   Col < MaxIndex,
        ColRight is Col + 1,

        nth0(Row, HDots, HRow),
        nth0(Col, HRow, 1),

        nth0(Row, Board, BRow),
        nth0(ColRight, BRow, Neighbor),
        Neighbor > 0,
        alternative_eliminated(Neighbor, Value, N, Board, Row, Col)

    ->  ColRight1 is ColRight + 1,
        Row1 is Row + 1,
        build_explanation(kropki_dot, [Row1, ColRight1, Neighbor, Value], Explanation)

        % Vizinho acima com ponto
    ;   Row > 0,
        RowUp is Row - 1,

        nth0(RowUp, VDots, VRow),
        nth0(Col, VRow, 1),

        nth0(RowUp, Board, BRowUp),
        nth0(Col, BRowUp, Neighbor),
        Neighbor > 0,
        alternative_eliminated(Neighbor, Value, N, Board, Row, Col)

    ->  RowUp1 is RowUp + 1,
        Col1 is Col + 1,
        build_explanation(kropki_dot, [RowUp1, Col1, Neighbor, Value], Explanation)
    
        % Vizinho abaixo com ponto
    ;   Row < MaxIndex,
        RowDown is Row + 1,

        nth0(Row, VDots, VRow),
        nth0(Col, VRow, 1),

        nth0(RowDown, Board, BRowDown),
        nth0(Col, BRowDown, Neighbor),
        Neighbor > 0,
        alternative_eliminated(Neighbor, Value, N, Board, Row, Col)

    ->  RowDown1 is RowDown + 1,
        Col1 is Col + 1,
        build_explanation(kropki_dot, [RowDown1, Col1, Neighbor, Value], Explanation)
    ).

%!  alternative_eliminated(+Neighbor, +Value, +N, +Board, +Row, +Col) is semidet.
%   Confere se o ponto com o Neighbor obriga o valor Value, ou seja,
%   se a outra opção com diferença 1 é impossível ou já foi eliminada.
alternative_eliminated(Neighbor, Value, N, Board, Row, Col) :-
        % 1. Descobre qual seria a outra opção com diferença de 1:
    (   Value =:= Neighbor + 1

    ->  OtherOption is Neighbor - 1
    ;   OtherOption is Neighbor + 1
    ),

        % 2. A outra opção tem que estar comprovadamente eliminada:
    (   OtherOption < 1

    ;   OtherOption > N

    ;   nth0(Row, Board, BRow), 
        member(OtherOption, BRow)

    ;   transpose(Board, Cols), 
        nth0(Col, Cols, BCol), 
        member(OtherOption, BCol)
    ),
    !.

%!  edge_clue_forced(+Puzzle, +Row, +Col, +Value, +N, -Explanation) is semidet.
%   Verifica se uma pista de borda (1 ou N) obriga a altura da célula.
edge_clue_forced(Puzzle, Row, Col, Value, N, Explanation) :-
    Puzzle = [Top, Bottom, Left, Right, _, _],

    (   % Caso 1: Pista 1 obriga o prédio mais alto (N) colado na borda
        Value =:= N,
    
        (   Row =:= 0, 
            nth0(Col, Top, 1)
    
        ->  build_explanation(edge_clue_min, [Value], Explanation)
    
        ;   Row =:= N - 1,
            nth0(Col, Bottom, 1)
    
        ->  build_explanation(edge_clue_min, [Value], Explanation)
    
        ;   Col =:= 0,
            nth0(Row, Left, 1)
    
        ->  build_explanation(edge_clue_min, [Value], Explanation)
    
        ;   Col =:= N - 1,
            nth0(Row, Right, 1)
    
        ->  build_explanation(edge_clue_min, [Value], Explanation)
        )

    -> true
    
    ;

        % Caso 2: Pista N obriga ordem estritamente crescente a partir da borda
        (   nth0(Col, Top, N),
            Value =:= Row + 1

        ->  build_explanation(edge_clue_max, [N, Value], Explanation)

        ;   nth0(Col, Bottom, N),
            Value =:= N - Row

        ->  build_explanation(edge_clue_max, [N, Value], Explanation)

        ;   nth0(Row, Left, N),
            Value =:= Col + 1

        ->  build_explanation(edge_clue_max, [N, Value], Explanation)

        ;   nth0(Row, Right, N),
            Value =:= N - Col

        ->  build_explanation(edge_clue_max, [N, Value], Explanation)
        )
    ).


%! build_explanation(+Chave, +Argumentos, -TextoExplicacao) is det.
build_explanation(Chave, Argumentos, TextoExplicacao) :-
    message(Chave, Template),
    format(string(TextoExplicacao), Template, Argumentos).

% ==================================================================================================
% Tabela de Mensagens de Explicação
% ==================================================================================================
message(
    single_in_row,
    'Na linha ~w, todas as outras alturas já foram usadas. Resta apenas a ~w.'
).

message(
    single_in_col,
    'Na coluna ~w, todas as outras alturas já foram usadas. Resta apenas a ~w.'
).

message(
    kropki_dot,
    'O ponto com a casa vizinha (~w, ~w) de altura ~w exige diferença de 1. A única opção viável é ~w.'
).

message(
    edge_clue_min,
    'A pista de borda exige ver apenas 1 prédio. Portanto, o prédio mais alto (~w) tem que ficar nesta extremidade.'
).

message(
    edge_clue_max,
    'A pista de borda exige ver todos os ~w prédios. Portanto, as alturas devem crescer em ordem a partir da borda: esta posição deve ser ~w.'
).

message(
    general_case,
    'A altura ~w na posição (~w, ~w) é a única compatível simultaneamente com as pistas e os pontos.'
).

message(
    double_dot,
    'Os pontos Kropki ligam esta posição às casas (~w, ~w) [altura ~w] e (~w, ~w) [altura ~w]. A única altura com diferença de 1 para ambas é a ~w.'
).
% ==================================================================================================
