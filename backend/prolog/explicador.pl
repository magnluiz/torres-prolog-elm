/*  explicador.pl: motor de inferência explicável para dicas.
    Analisa as restrições e gera justificativas em linguagem natural.
*/

:- module(explicador, [explain_cell/6]).
:- use_module(library(clpfd)).
:- use_module(library(lists)).


%! explain_cell(+Puzzle, +Board, +Row, +Col, +Value, -Explanation) is det.
%  Examina por que a a altura Value é a escolha correta para a célula (Row, Col).
explain_cell(Puzzle, Board, Row, Col, Value, Explanation) :-
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

        % Caso 3: É forçada por um ponto Kropki com vizinho conhecido
    ;   kropki_dot_forced(Puzzle, Board, Row, Col, Value, Explanation)
    ->  true

        % Caso 4: É forçada por uma pista de borda
    ;   edge_clue_forced(Puzzle, Row, Col, Value, N, Explanation)
    ->  true

        % 5. Dedução combinada de restrições (CLP/FD)
    ;   build_explanation(general_case, [Value, Row1, Col1], Explanation)
    ),
    !.

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
%   Verifica se uma pista de visibilidade obriga a célula a receber o prédio mais alto de todos.
edge_clue_forced(Puzzle, Row, Col, Value, N, Explanation) :-
    Puzzle = [Top, Bottom, Left, Right, _, _],
    Value =:= N,

    (   Row =:= 0, 
        nth0(Col, Top, 1)

    ->  build_explanation(edge_clue_top, [Value], Explanation)

    ;   Row =:= N - 1,
        nth0(Col, Bottom, 1)

    ->  build_explanation(edge_clue_bottom, [Value], Explanation)

    ;   Col =:= 0,
        nth0(Row, Left, 1)

    ->  build_explanation(edge_clue_left, [Value], Explanation)

    ;   Col =:= N - 1,
        nth0(Row, Right, 1)

    ->  build_explanation(edge_clue_right, [Value], Explanation)
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
    edge_clue_top,
    'A pista de borda exige ver apenas 1 prédio. Portanto, o prédio mais alto (~w) tem que ficar nesta extremidade.'
).

message(
    edge_clue_bottom,
    'A pista de borda exige ver apenas 1 prédio. Portanto, o prédio mais alto (~w) tem que ficar nesta extremidade.'
).

message(
    edge_clue_left,
    'A pista de borda exige ver apenas 1 prédio. Portanto, o prédio mais alto (~w) tem que ficar nesta extremidade.'
).

message(
    edge_clue_right,
    'A pista de borda exige ver apenas 1 prédio. Portanto, o prédio mais alto (~w) tem que ficar nesta extremidade.'
).

message(
    general_case,
    'A altura ~w na posição (~w, ~w) é a única compatível simultaneamente com as pistas e os pontos.'
).
% ==================================================================================================
