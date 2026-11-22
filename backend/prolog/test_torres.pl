/*  test_torres.pl: Testes unitários (plunit) das Torres Latinas.

    Para rodar:
        $ swipl -g run_tests -t halt backend/prolog/test_torres.pl
*/

:- use_module(torres).
:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(clpfd)).

%   Um tabuleiro N x N só com zeros (nenhuma casa preenchida).
empty_board(N, Board) :-
    length(Row, N),
    maplist(=(0), Row),
    length(Board, N),
    maplist(=(Row), Board).

:- begin_tests(visible).

test(ascending, true(K == 4)) :-
    visible([1,2,3,4], K).

test(descending, true(K == 1)) :-
    visible([4,3,2,1], K).

test(hidden_buildings, true(K == 2)) :-
    % O 1 fica escondido atrás do 2, e o 3 atrás do 4.
    visible([2,1,4,3], K).

test(runs_backwards, all(L == [[1,2,3,4]])) :-
    % O mesmo predicado, ao contrário: qual linha de 1..4 mostra 4 prédios?
    % Só a crescente. all(...) confere a lista de TODAS as respostas.
    length(L, 4),
    L ins 1..4,
    all_distinct(L),
    visible(L, 4),
    label(L).

:- end_tests(visible).

:- begin_tests(solve).

test(example_puzzle, true(S == [[1,2,3,4],[2,3,4,1],[3,4,1,2],[4,1,2,3]])) :-
    example_puzzle(P),
    solve(P, S).

test(example_is_unique, true(N == 1)) :-
    example_puzzle(P),
    count_solutions(P, 2, N).

test(dots_alone_are_not_enough, true(N == 2)) :-
    % Sem nenhuma pista de borda, os pontos do exemplo admitem mais de uma
    % solução (por exemplo, a grade espelhada com alturas 5 - h).
    example_puzzle([_, _, _, _, H, V]),
    count_solutions([[0,0,0,0], [0,0,0,0], [0,0,0,0], [0,0,0,0], H, V], 2, N).

test(keeps_player_numbers, true(S == [[1,2,3,4],[2,3,4,1],[3,4,1,2],[4,1,2,3]])) :-
    example_puzzle(P),
    solve(P, [[1,0,0,0],[0,0,0,0],[0,0,1,0],[0,0,0,3]], S).

test(wrong_player_number, fail) :-
    example_puzzle(P),
    solve(P, [[2,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]], _).

test(missing_dot_forbids_consecutive, fail) :-
    % Sem pontos em lugar nenhum, nenhum par de vizinhos pode ser
    % consecutivo. Numa linha 2x2 com 1 e 2 isso é impossível.
    solve([[0,0], [0,0], [0,0], [0,0], [[0],[0]], [[0,0]]], _).

:- end_tests(solve).

:- begin_tests(generate).

test(unique_solution, [true(N == 1), forall(member(D, [easy, medium]))]) :-
    generate(D, P),
    count_solutions(P, 2, N).

test(size, true(Sizes == [4, 5, 6])) :-
    findall(N,
            ( member(D, [easy, medium, hard]),
              generate(D, [Top | _]),
              length(Top, N) ),
            Sizes).

test(clues_match_solution) :-
    % Toda pista que sobrou confere com a solução: refazemos o puzzle
    % completo da solução e comparamos pista a pista (0 = sem pista).
    % full_puzzle/2 não é exportado; torres:full_puzzle o chama mesmo assim.
    generate(medium, P),
    solve(P, S),
    torres:full_puzzle(S, Full),
    P = [Top, Bottom, Left, Right, HDots, VDots],
    Full = [FTop, FBottom, FLeft, FRight, HDots, VDots],  % pontos: todos iguais
    maplist(clue_agrees, [Top, Bottom, Left, Right], [FTop, FBottom, FLeft, FRight]).

clue_agrees(Clues, FullClues) :-
    maplist([C, F] >> (C =:= 0 -> true ; C =:= F), Clues, FullClues).

test(bad_difficulty, error(type_error(_, impossible))) :-
    generate(impossible, _).

:- end_tests(generate).

:- begin_tests(hint).

test(hint_matches_solution, true(Value == Expected)) :-
    example_puzzle(P),
    empty_board(4, B),
    hint(P, B, [Row, Col, Value, _Explanation]),
    solve(P, S),
    nth0(Row, S, SRow), nth0(Col, SRow, Expected).

test(hint_on_empty_cell, true(Cell == 0)) :-
    example_puzzle(P),
    B = [[1,2,3,4],[0,0,0,0],[3,4,1,2],[4,1,2,3]],
    hint(P, B, [Row, Col, _, _Explanation]),
    nth0(Row, B, BRow), nth0(Col, BRow, Cell).

test(complete_board, true(Result == complete)) :-
    example_puzzle(P),
    solve(P, S),
    hint(P, S, Result).

test(unsolvable_board, true(Result == unsolvable)) :-
    example_puzzle(P),
    hint(P, [[4,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]], Result).

:- end_tests(hint).
