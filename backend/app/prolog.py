"""Ponte entre Python e Prolog usando a biblioteca janus.

janus (pacote `janus-swi`) embute o SWI-Prolog dentro do processo Python.
Não há servidor Prolog separado nem troca de mensagens: chamamos predicados
diretamente e recebemos as respostas como dicionários Python.

Conversão automática de tipos (Python -> Prolog):
    int          -> inteiro
    str          -> string  (use janus.Term / átomos com cuidado, veja abaixo)
    list         -> lista

Para mais detalhes: https://www.swi-prolog.org/pldoc/man?section=janus

Este é o ÚNICO arquivo do projeto que conhece o janus. O resto do backend
só chama as funções abaixo.
"""

from pathlib import Path

import janus_swi as janus

Grid = list[list[int]]

# Um puzzle, como torres.pl o representa: [Top, Bottom, Left, Right, HDots, VDots].
# As quatro primeiras são listas de pistas; as duas últimas, grades de 0/1.
PrologPuzzle = list

PROLOG_FILE = Path(__file__).parent.parent / "prolog" / "torres.pl"

# consult/1 carrega o arquivo .pl, como `?- [torres].` no terminal do swipl.
janus.consult(str(PROLOG_FILE))


class NoSolution(Exception):
    """O tabuleiro enviado não tem solução."""


class BoardComplete(Exception):
    """O tabuleiro não tem casas vazias: não há dica para dar."""


def solve(puzzle: PrologPuzzle, board: Grid) -> Grid:
    # query_once executa a consulta e devolve um dict com as variáveis da
    # consulta e a chave 'truth', que diz se a consulta teve sucesso.
    result = janus.query_once(
        "torres:solve(Puzzle, Board, Solution)", {"Puzzle": puzzle, "Board": board}
    )
    if not result["truth"]:
        raise NoSolution
    return result["Solution"]


def generate(difficulty: str) -> PrologPuzzle:
    # generate/2 espera um ÁTOMO (easy, medium, hard); atom_string/2 converte
    # a string que veio do Python.
    result = janus.query_once(
        "atom_string(D, Name), torres:generate(D, Puzzle)", {"Name": difficulty}
    )
    return result["Puzzle"]


def hint(puzzle: PrologPuzzle, board: Grid) -> tuple[int, int, int]:
    result = janus.query_once(
        "torres:hint(Puzzle, Board, Result)", {"Puzzle": puzzle, "Board": board}
    )["Result"]
    # hint/3 sempre tem sucesso: Result é [Linha, Coluna, Altura] ou um dos
    # átomos `complete` e `unsolvable` (que chegam como strings).
    match result:
        case "complete":
            raise BoardComplete
        case "unsolvable":
            raise NoSolution
        case [row, col, value, explanation]:
            return row, col, value, explanation
    raise ValueError(f"resultado inesperado de hint/3: {result!r}")
