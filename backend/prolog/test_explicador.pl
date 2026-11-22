/*  Testes unitários do motor de explicações.

    Rodar isoladamente:
        swipl -g run_tests -t halt backend/prolog/test_explicador.pl
*/

:- use_module(library(plunit)).
:- use_module(explicador).

:- begin_tests(explicador).

test(single_missing_height_in_row) :-
    blank_puzzle(5, Puzzle),
    blank_board(5, Board0),
    set_row(Board0, 0, [1, 2, 3, 4, 0], Board),
    explicador:explain_cell_deductive(Puzzle, Board, 0, 4, 5, Priority, Explanation),
    Priority =:= 1,
    once(sub_string(Explanation, _, _, _, "Na linha 1")),
    once(sub_string(Explanation, _, _, _, "Resta apenas a 5")).

test(single_missing_height_in_column) :-
    blank_puzzle(5, Puzzle),
    Board = [[1,0,0,0,0],
             [2,0,0,0,0],
             [3,0,0,0,0],
             [4,0,0,0,0],
             [0,0,0,0,0]],
    explicador:explain_cell_deductive(Puzzle, Board, 4, 0, 5, Priority, Explanation),
    Priority =:= 1,
    once(sub_string(Explanation, _, _, _, "Na coluna 1")),
    once(sub_string(Explanation, _, _, _, "Resta apenas a 5")).

test(double_dot_intersection_n5) :-
    double_dot_fixture(horizontal, Puzzle, Board, Row, Col),
    explicador:double_dot_forced(Puzzle, Board, Row, Col, 3, Explanation),
    once(sub_string(Explanation, _, _, _, "altura 2")),
    once(sub_string(Explanation, _, _, _, "altura 4")),
    once(sub_string(Explanation, _, _, _, "é a 3")).

test(double_dot_mixed_directions_n5) :-
    double_dot_fixture(mixed, Puzzle, Board, Row, Col),
    explicador:double_dot_forced(Puzzle, Board, Row, Col, 3, _).

test(double_dot_vertical_directions_n5) :-
    double_dot_fixture(vertical, Puzzle, Board, Row, Col),
    explicador:double_dot_forced(Puzzle, Board, Row, Col, 3, _).

test(double_dot_does_not_force_when_intersection_has_two_values, [fail]) :-
    double_dot_fixture(equal_neighbors, Puzzle, Board, Row, Col),
    explicador:double_dot_forced(Puzzle, Board, Row, Col, _Value, _Explanation).

test(single_dot_can_force_from_row_elimination) :-
    single_dot_fixture(left, Puzzle, Board, Row, Col),
    explicador:kropki_dot_forced(Puzzle, Board, Row, Col, 3, Explanation),
    once(sub_string(Explanation, _, _, _, "A única opção viável é 3")).

test(single_dot_can_force_from_column_elimination) :-
    single_dot_fixture(above, Puzzle, Board, Row, Col),
    explicador:kropki_dot_forced(Puzzle, Board, Row, Col, 3, _).

test(single_dot_does_not_force_while_both_candidates_remain, [fail]) :-
    blank_puzzle(5, Puzzle0),
    blank_board(5, Board0),
    set_dot(Puzzle0, 2, 2, 2, 1, Puzzle),
    set_cell(Board0, 2, 1, 2, Board),
    explicador:kropki_dot_forced(Puzzle, Board, 2, 2, 3, _).

test(single_dot_helper_handles_all_four_directions,
     [forall(member(Direction, [left, right, above, below]))]) :-
    single_dot_fixture(Direction, Puzzle, Board, Row, Col),
    explicador:kropki_dot_forced(Puzzle, Board, Row, Col, 3, _).

test(single_dot_can_force_at_lower_boundary_n5) :-
    single_dot_boundary_fixture(1, Puzzle, Board),
    explicador:kropki_dot_forced(Puzzle, Board, 2, 2, 2, _).

test(single_dot_can_force_at_upper_boundary_n5) :-
    single_dot_boundary_fixture(5, Puzzle, Board),
    explicador:kropki_dot_forced(Puzzle, Board, 2, 2, 4, _).

test(edge_clue_one_forces_maximum_on_every_side,
     [forall(member(Side, [top, bottom, left, right]))]) :-
    edge_minimum_case(Side, Puzzle, Row, Col, Value),
    explicador:edge_clue_forced(Puzzle, Row, Col, Value, 5, Explanation),
    once(sub_string(Explanation, _, _, _, "mais alto")).

test(edge_clue_five_forces_ascending_order_on_every_side,
     [forall(member(Side, [top, bottom, left, right]))]) :-
    edge_maximum_case(Side, Puzzle, Row, Col, Value),
    explicador:edge_clue_forced(Puzzle, Row, Col, Value, 5, Explanation),
    once(sub_string(Explanation, _, _, _, "todos os 5 prédios")).

test(explain_cell_uses_direct_double_dot_deduction) :-
    double_dot_fixture(horizontal, Puzzle, Board, Row, Col),
    explicador:explain_cell_deductive(Puzzle, Board, Row, Col, 3, Priority, Explanation),
    Priority =:= 3,
    once(sub_string(Explanation, _, _, _, "Os pontos Kropki")),
    once(sub_string(Explanation, _, _, _, "é a 3")).

test(negative_kropki_deduction) :-
    blank_puzzle(5, Puzzle0),
    set_dot(Puzzle0, 2, 2, 2, 1, Puzzle),
    blank_board(5, Board0),
    set_cell(Board0, 2, 1, 2, Board1),
    set_cell(Board1, 1, 2, 4, Board),
    explicador:negative_kropki_forced(Puzzle, Board, 2, 2, 1, Explanation),
    once(sub_string(Explanation, _, _, _, "permite 1 ou 3")),
    once(sub_string(Explanation, _, _, _, "ausência de ponto")),
    once(sub_string(Explanation, _, _, _, "proíbe o 3")),
    once(sub_string(Explanation, _, _, _, "Resta apenas o 1")).

test(explain_cell_uses_negative_kropki_deduction) :-
    blank_puzzle(5, Puzzle0),
    set_dot(Puzzle0, 2, 2, 2, 1, Puzzle),
    blank_board(5, Board0),
    set_cell(Board0, 2, 1, 2, Board1),
    set_cell(Board1, 1, 2, 4, Board),
    explicador:explain_cell_deductive(Puzzle, Board, 2, 2, 1, Priority, Explanation),
    Priority =:= 3,
    once(sub_string(Explanation, _, _, _, "ausência de ponto")).

test(visibility_barrier_left) :-
    blank_puzzle(4, Puzzle0),
    set_test_clue(left, 0, 2, Puzzle0, Puzzle),
    blank_board(4, Board0),
    set_cell(Board0, 0, 0, 2, Board1),
    set_cell(Board1, 0, 2, 4, Board),
    explicador:visibility_barrier_forced(Puzzle, Board, 0, 1, 1, 4, Explanation),
    once(sub_string(Explanation, _, _, _, "pista da esquerda")),
    once(sub_string(Explanation, _, _, _, "escondida atrás")),
    once(sub_string(Explanation, _, _, _, "restando apenas a altura 1")).

test(visibility_barrier_right) :-
    blank_puzzle(4, Puzzle0),
    set_test_clue(right, 0, 2, Puzzle0, Puzzle),
    blank_board(4, Board0),
    set_cell(Board0, 0, 3, 2, Board1),
    set_cell(Board1, 0, 1, 4, Board),
    explicador:visibility_barrier_forced(Puzzle, Board, 0, 2, 1, 4, Explanation),
    once(sub_string(Explanation, _, _, _, "pista da direita")),
    once(sub_string(Explanation, _, _, _, "escondida atrás")),
    once(sub_string(Explanation, _, _, _, "restando apenas a altura 1")).

test(visibility_barrier_top) :-
    blank_puzzle(4, Puzzle0),
    set_test_clue(top, 0, 2, Puzzle0, Puzzle),
    blank_board(4, Board0),
    set_cell(Board0, 0, 0, 2, Board1),
    set_cell(Board1, 2, 0, 4, Board),
    explicador:visibility_barrier_forced(Puzzle, Board, 1, 0, 1, 4, Explanation),
    once(sub_string(Explanation, _, _, _, "pista do topo")),
    once(sub_string(Explanation, _, _, _, "escondida atrás")),
    once(sub_string(Explanation, _, _, _, "restando apenas a altura 1")).

test(visibility_barrier_bottom) :-
    blank_puzzle(4, Puzzle0),
    set_test_clue(bottom, 0, 2, Puzzle0, Puzzle),
    blank_board(4, Board0),
    set_cell(Board0, 3, 0, 2, Board1),
    set_cell(Board1, 1, 0, 4, Board),
    explicador:visibility_barrier_forced(Puzzle, Board, 2, 0, 1, 4, Explanation),
    once(sub_string(Explanation, _, _, _, "pista da base")),
    once(sub_string(Explanation, _, _, _, "escondida atrás")),
    once(sub_string(Explanation, _, _, _, "restando apenas a altura 1")).

test(explain_cell_uses_visibility_barrier_priority_3) :-
    blank_puzzle(4, Puzzle0),
    set_test_clue(left, 0, 2, Puzzle0, Puzzle),
    blank_board(4, Board0),
    set_cell(Board0, 0, 0, 2, Board1),
    set_cell(Board1, 0, 2, 4, Board),
    explicador:explain_cell_deductive(Puzzle, Board, 0, 1, 1, Priority, Explanation),
    Priority =:= 3,
    once(sub_string(Explanation, _, _, _, "escondida atrás")).

test(visibility_barrier_does_not_force_when_two_candidates_remain, [fail]) :-
    blank_puzzle(4, Puzzle0),
    set_test_clue(left, 0, 2, Puzzle0, Puzzle),
    blank_board(4, Board0),
    set_cell(Board0, 0, 0, 3, Board1), % EdgeH = 3, so both 1 and 2 can be behind 3
    set_cell(Board1, 0, 3, 4, Board),
    explicador:visibility_barrier_forced(Puzzle, Board, 0, 1, _Value, 4, _Explanation).

test(explain_cell_deductive_fails_without_direct_rule, [fail]) :-
    blank_puzzle(5, Puzzle),
    blank_board(5, Board),
    explicador:explain_cell_deductive(Puzzle, Board, 2, 2, 3, _, _).

test(explain_cell_provides_general_explanation) :-
    blank_puzzle(5, Puzzle),
    blank_board(5, Board),
    explicador:explain_cell(Puzzle, Board, 2, 2, 3, Explanation),
    once(sub_string(Explanation, _, _, _, "posição (3, 3)")).

:- end_tests(explicador).


blank_puzzle(N, [Top, Bottom, Left, Right, HDots, VDots]) :-
    zero_line(N, Top),
    zero_line(N, Bottom),
    zero_line(N, Left),
    zero_line(N, Right),
    M is N - 1,
    zero_grid(N, M, HDots),
    zero_grid(M, N, VDots).

blank_board(N, Board) :-
    zero_grid(N, N, Board).

zero_line(N, Line) :-
    length(Line, N),
    maplist(=(0), Line).

zero_grid(Rows, Cols, Grid) :-
    zero_line(Cols, Row),
    length(Grid, Rows),
    maplist(=(Row), Grid).

set_row(Board0, RowIndex, Row, Board) :-
    replace_at(RowIndex, Board0, Row, Board).

set_cell(Board0, Row, Col, Value, Board) :-
    nth0(Row, Board0, OldRow),
    replace_at(Col, OldRow, Value, NewRow),
    replace_at(Row, Board0, NewRow, Board).

set_dot([Top, Bottom, Left, Right, HDots0, VDots0],
        Row, Col, OtherRow, OtherCol,
        [Top, Bottom, Left, Right, HDots, VDots]) :-
    (   Row =:= OtherRow
    ->  LeftCol is min(Col, OtherCol),
        nth0(Row, HDots0, OldDots),
        replace_at(LeftCol, OldDots, 1, NewDots),
        replace_at(Row, HDots0, NewDots, HDots),
        VDots = VDots0
    ;   UpperRow is min(Row, OtherRow),
        nth0(UpperRow, VDots0, OldDots),
        replace_at(Col, OldDots, 1, NewDots),
        replace_at(UpperRow, VDots0, NewDots, VDots),
        HDots = HDots0
    ).

replace_at(Index, List, Value, NewList) :-
    nth0(Index, List, _Old, Rest),
    nth0(Index, NewList, Value, Rest).

double_dot_fixture(horizontal, Puzzle, Board, 2, 2) :-
    blank_puzzle(5, Puzzle0),
    set_dot(Puzzle0, 2, 2, 2, 1, Puzzle1),
    set_dot(Puzzle1, 2, 2, 2, 3, Puzzle),
    blank_board(5, Board0),
    set_cell(Board0, 2, 1, 2, Board1),
    set_cell(Board1, 2, 3, 4, Board).
double_dot_fixture(mixed, Puzzle, Board, 2, 2) :-
    blank_puzzle(5, Puzzle0),
    set_dot(Puzzle0, 2, 2, 1, 2, Puzzle1),
    set_dot(Puzzle1, 2, 2, 2, 3, Puzzle),
    blank_board(5, Board0),
    set_cell(Board0, 1, 2, 2, Board1),
    set_cell(Board1, 2, 3, 4, Board).
double_dot_fixture(vertical, Puzzle, Board, 2, 2) :-
    blank_puzzle(5, Puzzle0),
    set_dot(Puzzle0, 2, 2, 1, 2, Puzzle1),
    set_dot(Puzzle1, 2, 2, 3, 2, Puzzle),
    blank_board(5, Board0),
    set_cell(Board0, 1, 2, 2, Board1),
    set_cell(Board1, 3, 2, 4, Board).
double_dot_fixture(equal_neighbors, Puzzle, Board, 2, 2) :-
    blank_puzzle(5, Puzzle0),
    set_dot(Puzzle0, 2, 2, 1, 2, Puzzle1),
    set_dot(Puzzle1, 2, 2, 2, 3, Puzzle),
    blank_board(5, Board0),
    set_cell(Board0, 1, 2, 2, Board1),
    set_cell(Board1, 2, 3, 2, Board).

single_dot_fixture(Direction, Puzzle, Board, 2, 2) :-
    blank_puzzle(5, Puzzle0),
    blank_board(5, Board0),
    single_dot_neighbor(Direction, 2, 2, NeighborRow, NeighborCol),
    set_dot(Puzzle0, 2, 2, NeighborRow, NeighborCol, Puzzle1),
    set_cell(Board0, NeighborRow, NeighborCol, 2, Board1),
    (   (Direction = left ; Direction = right)
    ->  set_cell(Board1, 2, 0, 1, Board),
        (   Direction = left
        ->  set_dot(Puzzle1, 2, 0, 2, 1, Puzzle)
        ;   Puzzle = Puzzle1
        )
    ;   set_cell(Board1, 0, 2, 1, Board),
        (   Direction = above
        ->  set_dot(Puzzle1, 0, 2, 1, 2, Puzzle)
        ;   Puzzle = Puzzle1
        )
    ).

single_dot_boundary_fixture(NeighborValue, Puzzle, Board) :-
    blank_puzzle(5, Puzzle0),
    blank_board(5, Board0),
    set_dot(Puzzle0, 2, 2, 2, 1, Puzzle),
    set_cell(Board0, 2, 1, NeighborValue, Board).

single_dot_neighbor(left, Row, Col, Row, NeighborCol) :- NeighborCol is Col - 1.
single_dot_neighbor(right, Row, Col, Row, NeighborCol) :- NeighborCol is Col + 1.
single_dot_neighbor(above, Row, Col, NeighborRow, Col) :- NeighborRow is Row - 1.
single_dot_neighbor(below, Row, Col, NeighborRow, Col) :- NeighborRow is Row + 1.

edge_minimum_case(top, Puzzle, 0, 2, 5) :- set_test_clue(top, 2, 1, Puzzle).
edge_minimum_case(bottom, Puzzle, 4, 2, 5) :- set_test_clue(bottom, 2, 1, Puzzle).
edge_minimum_case(left, Puzzle, 2, 0, 5) :- set_test_clue(left, 2, 1, Puzzle).
edge_minimum_case(right, Puzzle, 2, 4, 5) :- set_test_clue(right, 2, 1, Puzzle).

edge_maximum_case(top, Puzzle, 2, 1, 3) :- set_test_clue(top, 1, 5, Puzzle).
edge_maximum_case(bottom, Puzzle, 2, 1, 3) :- set_test_clue(bottom, 1, 5, Puzzle).
edge_maximum_case(left, Puzzle, 1, 2, 3) :- set_test_clue(left, 1, 5, Puzzle).
edge_maximum_case(right, Puzzle, 1, 2, 3) :- set_test_clue(right, 1, 5, Puzzle).

set_test_clue(Side, Index, Value, Puzzle) :-
    blank_puzzle(5, Puzzle0),
    set_test_clue(Side, Index, Value, Puzzle0, Puzzle).

set_test_clue(Side, Index, Value, Puzzle0, Puzzle) :-
    Puzzle0 = [Top0, Bottom0, Left0, Right0, HDots, VDots],
    (   Side = top
    ->  replace_at(Index, Top0, Value, Top),
        Puzzle = [Top, Bottom0, Left0, Right0, HDots, VDots]
    ;   Side = bottom
    ->  replace_at(Index, Bottom0, Value, Bottom),
        Puzzle = [Top0, Bottom, Left0, Right0, HDots, VDots]
    ;   Side = left
    ->  replace_at(Index, Left0, Value, Left),
        Puzzle = [Top0, Bottom0, Left, Right0, HDots, VDots]
    ;   Side = right,
        replace_at(Index, Right0, Value, Right),
        Puzzle = [Top0, Bottom0, Left0, Right, HDots, VDots]
    ).
