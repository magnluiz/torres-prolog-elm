/*  torres.pl: Torres Latinas, um remix de Arranha-céus com pontos de Kropki.

    REGRAS DO JOGO
    --------------
    O tabuleiro é uma grade N x N (N = 4, 5 ou 6). Cada casa recebe a
    altura de um prédio, de 1 a N.

      1. Quadrado latino: em cada linha e em cada coluna, as alturas 1..N
         aparecem uma vez cada.
      2. Visibilidade (do Arranha-céus): uma pista na borda diz quantos
         prédios são vistos por quem olha daquele lado. Um prédio esconde
         todos os mais baixos que estão atrás dele.
      3. Pontos (regra própria do grupo, inspirada no Kropki): entre duas
         casas vizinhas há um ponto SE E SOMENTE SE as alturas diferem de
         exatamente 1. Todos os pontos são mostrados, então a FALTA de um
         ponto também é informação: ali a diferença não é 1.

    REPRESENTAÇÃO
    -------------
    Um puzzle é uma lista com seis listas de inteiros:

        [Top, Bottom, Left, Right, HDots, VDots]

      * Top, Bottom: N pistas, uma por coluna (olhando de cima / de baixo);
      * Left, Right: N pistas, uma por linha (olhando da esquerda / direita);
        nas quatro, 0 significa "sem pista";
      * HDots: N linhas com N-1 valores; 1 = ponto entre (L,C) e (L,C+1);
      * VDots: N-1 linhas com N valores; 1 = ponto entre (L,C) e (L+1,C).

    Usamos listas, e não um termo como puzzle(Top, ...), porque o janus
    converte listas para o Python, mas não termos compostos.

    O tabuleiro do jogador é uma lista de N linhas com N inteiros; 0 é casa
    vazia (igual ao template do Sudoku).

    A IDEIA CENTRAL
    ---------------
    Cada regra vira uma restrição do CLP(FD). O mesmo predicado serve para
    VERIFICAR uma pista (quando ela é um número) e para CALCULÁ-LA (quando
    ela é uma variável): é assim que o gerador descobre as pistas de uma
    grade completa, sem nenhum código extra para "contar prédios".

    COMO TESTAR NO TERMINAL
    -----------------------
        $ swipl backend/prolog/torres.pl
        ?- example_puzzle(P), solve(P, S), print_grid(S).
        ?- generate(medium, P), print_puzzle(P).
*/

:- module(torres,
          [ solve/2,             % +Puzzle, -Solution
            solve/3,             % +Puzzle, +Board, -Solution
            count_solutions/3,   % +Puzzle, +Limit, -Count
            generate/2,          % +Difficulty, -Puzzle
            hint/3,              % +Puzzle, +Board, -Result
            visible/2,           % ?Line, ?Count
            example_puzzle/1,    % -Puzzle
            print_grid/1,        % +Grid
            print_puzzle/1       % +Puzzle
          ]).

:- use_module(library(clpfd)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(random)).
:- use_module(library(solution_sequences)).


/* =========================================================================
   1. AS REGRAS (restrições)
   ========================================================================= */

%!  towers(?Puzzle, ?Rows) is det.
%
%   Impõe sobre Rows todas as regras do jogo descritas por Puzzle. Não
%   resolve nada sozinho: só registra as restrições. Quem atribui valores
%   é o labeling/2, chamado depois.
towers([Top, Bottom, Left, Right, HDots, VDots], Rows) :-
    length(Top, N),
    latin_square(N, Rows),
    transpose(Rows, Columns),

    % Regra 2. Olhar de baixo (ou da direita) é olhar a coluna (ou a
    % linha) de trás para frente; por isso as listas invertidas.
    maplist(reverse, Columns, ColumnsUp),
    maplist(reverse, Rows, RowsLeftward),
    maplist(edge_clue, Columns, Top),
    maplist(edge_clue, ColumnsUp, Bottom),
    maplist(edge_clue, Rows, Left),
    maplist(edge_clue, RowsLeftward, Right),

    % Regra 3. Os pontos horizontais ligam vizinhos dentro de cada linha;
    % os verticais, vizinhos dentro de cada coluna. Uma coluna é uma linha
    % da transposta, então VDots transposta tem o mesmo formato de HDots.
    maplist(line_dots, Rows, HDots),
    transpose(VDots, VDotsByColumn),
    maplist(line_dots, Columns, VDotsByColumn).

%!  latin_square(+N, ?Rows) is det.
%
%   Regra 1: N linhas de N casas, alturas 1..N, sem repetição em linhas e
%   colunas.
latin_square(N, Rows) :-
    length(Rows, N),
    maplist(length_of(N), Rows),
    append(Rows, Cells),
    Cells ins 1..N,
    maplist(all_distinct, Rows),
    transpose(Rows, Columns),
    maplist(all_distinct, Columns).

%   length_of(?N, ?List): length/2 com os argumentos trocados, para poder
%   ser usado com aplicação parcial: maplist(length_of(4), Linhas) cria
%   (ou confere) linhas de 4 casas.
length_of(N, List) :-
    length(List, N).

%!  edge_clue(?Line, ?Clue) is det.
%
%   Pista 0 é "sem pista": nenhuma restrição. Qualquer outro valor (ou uma
%   variável, durante a geração) amarra a quantidade de prédios visíveis.
%   O teste `Clue == 0` só é verdadeiro quando Clue JÁ É o número 0; uma
%   variável livre não é idêntica a 0, e vai para o segundo ramo.
edge_clue(Line, Clue) :-
    (   Clue == 0
    ->  true
    ;   visible(Line, Clue)
    ).

%!  visible(?Line, ?Count) is det.
%
%   Count é o número de prédios de Line visíveis a partir do começo da
%   lista. Um prédio é visível quando é mais alto que todos os anteriores,
%   isto é, mais alto que o máximo até ali.
%
%   Cada prédio ganha um "booleano" B (0 ou 1) ligado à condição por
%   REIFICAÇÃO: `B #<==> (H #> Max)` diz que B é 1 exatamente quando
%   H > Max. Count é a soma dos Bs. Nada disso calcula na hora: são
%   restrições, que valem nos dois sentidos. Se a linha for conhecida,
%   Count é deduzido; se Count for conhecido, o resolvedor corta alturas
%   impossíveis da linha.
visible([First | Rest], Count) :-
    % O primeiro prédio é sempre visível; ele é o máximo inicial.
    visible_flags(Rest, First, Flags),
    sum([1 | Flags], #=, Count).

%   visible_flags(?Heights, ?MaxSoFar, -Flags)
%   Recursão sobre a lista, carregando o máximo visto até agora.
visible_flags([], _Max, []).
visible_flags([H | Hs], Max, [B | Bs]) :-
    B #<==> (H #> Max),
    NewMax #= max(Max, H),
    visible_flags(Hs, NewMax, Bs).

%!  line_dots(?Line, ?Dots) is det.
%
%   Dots tem um elemento por par de vizinhos de Line. Cada elemento é 1
%   quando os dois diferem de exatamente 1, e 0 caso contrário. Como é
%   "se e somente se" (#<==>), um 0 também restringe: ali a diferença NÃO
%   é 1. Essa é a regra própria do jogo.
line_dots([_], []).
line_dots([A, B | Rest], [Dot | Dots]) :-
    Dot in 0..1,
    Dot #<==> (abs(A - B) #= 1),
    line_dots([B | Rest], Dots).


/* =========================================================================
   2. RESOLVER
   ========================================================================= */

%!  solve(+Puzzle, -Solution) is semidet.
%
%   Solution é uma grade que satisfaz todas as regras de Puzzle.
solve(Puzzle, Solution) :-
    towers(Puzzle, Solution),
    append(Solution, Cells),
    labeling([ff], Cells),
    !.

%!  solve(+Puzzle, +Board, -Solution) is semidet.
%
%   Como solve/2, mas respeitando os números que o jogador já colocou em
%   Board (0 = vazio). Falha se não houver solução: ou o puzzle é
%   impossível, ou o jogador errou alguma casa. Os números de Board já
%   entram em Solution; towers/2 só restringe as casas que faltam.
solve(Puzzle, Board, Solution) :-
    grid_vars(Board, Solution),
    solve(Puzzle, Solution).

%!  count_solutions(+Puzzle, +Limit, -Count) is det.
%
%   Quantas soluções Puzzle tem, contando até Limit. Com Limit = 2, basta
%   para saber se a solução é única.
count_solutions(Puzzle, Limit, Count) :-
    findall(x,
            limit(Limit, ( towers(Puzzle, Rows),
                           append(Rows, Cells),
                           labeling([ff], Cells) )),
            Found),
    length(Found, Count).

unique_solution(Puzzle) :-
    count_solutions(Puzzle, 2, 1).

%   grid_vars(+Grid, -Vars): troca cada 0 por uma variável nova.
grid_vars(Grid, Vars) :-
    maplist(maplist(cell_var), Grid, Vars).

cell_var(0, _Fresh) :- !.
cell_var(N, N).


/* =========================================================================
   3. GERADOR
   =========================================================================

   (a) Sorteia um quadrado latino completo.
   (b) Calcula TODAS as pistas e pontos dessa grade, usando towers/2 com
       as pistas ainda desconhecidas (variáveis). É o mesmo código que
       verifica pistas, agora rodando "ao contrário".
   (c) Se, mesmo com todas as pistas, houver mais de uma solução, sorteia
       outra grade.
   (d) Apaga pistas de borda em ordem aleatória, mantendo cada remoção só
       se a solução continuar única. Os pontos nunca são apagados: a
       regra 3 depende de todos estarem à vista.
*/

%!  difficulty(?Name, ?Size, ?KeepRatio) is nondet.
%
%   Tamanho da grade e fração das pistas REMOVÍVEIS que mantemos de volta
%   como ajuda extra (0 = puzzle mínimo, o mais difícil).
difficulty(easy,   4, 0.5).
difficulty(medium, 5, 0.3).
difficulty(hard,   6, 0).

%!  generate(+Difficulty, -Puzzle) is det.
generate(Difficulty, Puzzle) :-
    must_be(oneof([easy, medium, hard]), Difficulty),
    difficulty(Difficulty, N, KeepRatio),
    repeat,                                   % (c): tenta de novo até dar certo
    random_latin_square(N, Grid),
    full_puzzle(Grid, Full),
    unique_solution(Full),
    !,
    edge_slots(N, Slots),
    random_permutation(Slots, Order),
    dig_clues(Order, Full, Minimal, Removed),
    restore_some(Removed, KeepRatio, Full, Minimal, Puzzle).

%!  random_latin_square(+N, -Rows) is det.
random_latin_square(N, Rows) :-
    latin_square(N, Rows),
    append(Rows, Cells),
    random_labeling(Cells),
    !.

%   Como label/1, mas testando os valores de cada casa em ordem aleatória.
random_labeling([]).
random_labeling([Var | Vars]) :-
    (   integer(Var)
    ->  true
    ;   fd_dom(Var, Domain),
        findall(V, (V in Domain, indomain(V)), Values),
        random_permutation(Values, Shuffled),
        member(Var, Shuffled)
    ),
    random_labeling(Vars).

%!  full_puzzle(+Grid, -Puzzle) is det.
%
%   Puzzle traz todas as pistas e pontos de Grid. Criamos o "molde" com
%   variáveis no lugar das pistas e deixamos towers/2 deduzi-las.
full_puzzle(Grid, [Top, Bottom, Left, Right, HDots, VDots]) :-
    length(Grid, N),
    M is N - 1,
    maplist(length_of(N), [Top, Bottom, Left, Right]),
    length(HDots, N), maplist(length_of(M), HDots),
    length(VDots, M), maplist(length_of(N), VDots),
    towers([Top, Bottom, Left, Right, HDots, VDots], Grid).

%!  edge_slots(+N, -Slots) is det.
%
%   Todas as posições de pista de borda, como Lado-Índice. findall/3 com
%   member/2 e between/3 enumera o produto cartesiano lados x índices.
edge_slots(N, Slots) :-
    Last is N - 1,
    findall(Side-I,
            ( member(Side, [0, 1, 2, 3]), between(0, Last, I) ),
            Slots).

%!  dig_clues(+Order, +Puzzle0, -Puzzle, -Removed) is det.
%
%   Tenta zerar cada pista na ordem dada. Removed acumula as que saíram,
%   para que restore_some/5 possa devolver algumas.
dig_clues([], Puzzle, Puzzle, []).
dig_clues([Slot | Slots], Puzzle0, Puzzle, Removed) :-
    set_clue(Slot, 0, Puzzle0, Candidate),
    (   unique_solution(Candidate)
    ->  Removed = [Slot | Removed1],
        dig_clues(Slots, Candidate, Puzzle, Removed1)
    ;   dig_clues(Slots, Puzzle0, Puzzle, Removed)
    ).

%!  restore_some(+Removed, +Ratio, +Full, +Minimal, -Puzzle) is det.
%
%   Devolve a Minimal as primeiras Ratio x |Removed| pistas removidas,
%   copiando os valores de Full. Pistas a mais nunca tiram a unicidade.
restore_some(Removed, Ratio, Full, Minimal, Puzzle) :-
    length(Removed, R),
    K is round(R * Ratio),
    length(Back, K),
    append(Back, _, Removed),
    foldl(restore_clue(Full), Back, Minimal, Puzzle).

restore_clue(Full, Slot, Puzzle0, Puzzle) :-
    get_clue(Slot, Full, Value),
    set_clue(Slot, Value, Puzzle0, Puzzle).

%   get_clue(+Side-Index, +Puzzle, -Value) e
%   set_clue(+Side-Index, +Value, +Puzzle0, -Puzzle): leem e trocam uma
%   pista de borda. Side é a posição da lista de pistas dentro do puzzle
%   (0 = Top, 1 = Bottom, 2 = Left, 3 = Right).
get_clue(Side-I, Puzzle, Value) :-
    nth0(Side, Puzzle, Clues),
    nth0(I, Clues, Value).

set_clue(Side-I, Value, Puzzle0, Puzzle) :-
    nth0(Side, Puzzle0, Clues0),
    replace_nth0(I, Clues0, Value, Clues),
    replace_nth0(Side, Puzzle0, Clues, Puzzle).

replace_nth0(Index, List, Elem, NewList) :-
    nth0(Index, List, _Old, Rest),
    nth0(Index, NewList, Elem, Rest).


/* =========================================================================
   4. DICA
   ========================================================================= */

%!  hint(+Puzzle, +Board, -Result) is det.
%
%   Result é uma lista [Linha, Coluna, Altura] (uma casa vazia, sorteada, e
%   a altura certa), ou o átomo `complete` (não há casa vazia) ou
%   `unsolvable` (o que o jogador colocou já contradiz as regras).
hint(Puzzle, Board, Result) :-
    (   solve(Puzzle, Board, Solution)
    ->  empty_positions(Board, Empty),
        (   Empty == []
        ->  Result = complete
        ;   random_member(Row-Col, Empty),
            nth0(Row, Solution, SolutionRow),
            nth0(Col, SolutionRow, Value),
            Result = [Row, Col, Value]
        )
    ;   Result = unsolvable
    ).

empty_positions(Board, Positions) :-
    findall(R-C,
            ( nth0(R, Board, Row),
              nth0(C, Row, 0) ),
            Positions).


/* =========================================================================
   5. UTILITÁRIOS PARA USO NO TERMINAL
   ========================================================================= */

%   Um puzzle 4x4 com todas as pistas, feito a partir da grade
%       1 2 3 4
%       2 3 4 1
%       3 4 1 2
%       4 1 2 3
%   Ele tem mais de uma solução? Confira com count_solutions/3.
example_puzzle([[4,3,2,1], [1,2,2,2], [4,3,2,1], [1,2,2,2],
                [[1,1,1], [1,1,0], [1,0,1], [0,1,1]],
                [[1,1,1,0], [1,1,0,1], [1,0,1,1]]]).

print_grid(Grid) :-
    forall(member(Row, Grid),
           ( maplist(format_cell, Row), nl )).

format_cell(0) :- !, write(' .').
format_cell(N) :- format(' ~w', [N]).

%   print_puzzle(+Puzzle): mostra as pistas em volta de uma grade vazia,
%   com os pontos como "o" (horizontal) e "8" (vertical).
print_puzzle([Top, Bottom, Left, Right, HDots, VDots]) :-
    format('    ~w~n', [Top]),
    print_rows(Left, Right, HDots, VDots),
    format('    ~w~n', [Bottom]).

print_rows([L], [R], [H], []) :- !,
    print_row(L, R, H).
print_rows([L | Ls], [R | Rs], [H | Hs], [V | Vs]) :-
    print_row(L, R, H),
    write('    '), maplist(format_vdot, V), nl,
    print_rows(Ls, Rs, Hs, Vs).

print_row(L, R, H) :-
    format('~w  [ .', [L]),
    maplist([D] >> (format_hdot(D), write('.')), H),
    format(' ]  ~w~n', [R]).

format_hdot(1) :- !, write(' o ').
format_hdot(_) :- write('   ').

format_vdot(1) :- !, write(' 8  ').
format_vdot(_) :- write('    ').
