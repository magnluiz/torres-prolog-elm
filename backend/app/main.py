"""API HTTP das Torres Latinas.

Esta camada é só "cola": recebe JSON, valida o formato com Pydantic, chama o
Prolog (via app/prolog.py) e devolve JSON. Nenhuma regra do jogo mora aqui.

Rodar em modo de desenvolvimento (recarrega ao salvar):
    uv run fastapi dev app/main.py

Documentação interativa gerada automaticamente: http://localhost:8000/docs
"""

from typing import Annotated, Literal

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field, model_validator

from app import prolog

app = FastAPI(title="Torres Latinas (Prolog + Elm)")

MIN_SIZE, MAX_SIZE = 4, 6

Height = Annotated[int, Field(ge=0, le=MAX_SIZE)]
Line = Annotated[list[Height], Field(min_length=1, max_length=MAX_SIZE)]
Grid = Annotated[list[Line], Field(min_length=MIN_SIZE, max_length=MAX_SIZE)]
Dot = Annotated[int, Field(ge=0, le=1)]


class Puzzle(BaseModel):
    """Pistas de borda (0 = sem pista) e pontos entre casas vizinhas."""

    top: list[Height]
    bottom: list[Height]
    left: list[Height]
    right: list[Height]
    hdots: list[list[Dot]]  # N linhas com N-1 valores
    vdots: list[list[Dot]]  # N-1 linhas com N valores

    @model_validator(mode="after")
    def check_shape(self) -> "Puzzle":
        # Só confere as DIMENSÕES, para o Prolog não receber listas
        # desencontradas. As regras do jogo ficam todas no Prolog.
        n = len(self.top)
        shapes_ok = (
            MIN_SIZE <= n <= MAX_SIZE
            and all(len(c) == n for c in (self.bottom, self.left, self.right))
            and len(self.hdots) == n
            and all(len(row) == n - 1 for row in self.hdots)
            and len(self.vdots) == n - 1
            and all(len(row) == n for row in self.vdots)
        )
        if not shapes_ok:
            raise ValueError("dimensões do puzzle inconsistentes")
        return self

    def to_prolog(self) -> prolog.PrologPuzzle:
        return [self.top, self.bottom, self.left, self.right, self.hdots, self.vdots]

    @classmethod
    def from_prolog(cls, p: prolog.PrologPuzzle) -> "Puzzle":
        top, bottom, left, right, hdots, vdots = p
        return cls(top=top, bottom=bottom, left=left, right=right, hdots=hdots, vdots=vdots)


class GenerateRequest(BaseModel):
    difficulty: Literal["easy", "medium", "hard"] = "medium"


class GenerateResponse(BaseModel):
    puzzle: Puzzle


class BoardRequest(BaseModel):
    puzzle: Puzzle
    board: Grid

    @model_validator(mode="after")
    def board_matches_puzzle(self) -> "BoardRequest":
        n = len(self.puzzle.top)
        if len(self.board) != n or any(len(row) != n for row in self.board):
            raise ValueError("o tabuleiro não tem o tamanho do puzzle")
        return self


class BoardResponse(BaseModel):
    board: Grid


class HintResponse(BaseModel):
    row: int
    col: int
    value: int
    explanation: str


# Mensagens que o Elm mostra na tela quando a resposta é 422.
NO_SOLUTION = "Não há solução com essas alturas. Confira os prédios colocados."
BOARD_COMPLETE = "O tabuleiro já está completo."


@app.post("/api/generate")
def generate(request: GenerateRequest) -> GenerateResponse:
    return GenerateResponse(puzzle=Puzzle.from_prolog(prolog.generate(request.difficulty)))


@app.post("/api/solve")
def solve(request: BoardRequest) -> BoardResponse:
    try:
        return BoardResponse(board=prolog.solve(request.puzzle.to_prolog(), request.board))
    except prolog.NoSolution:
        raise HTTPException(status_code=422, detail=NO_SOLUTION) from None


@app.post("/api/hint")
def hint(request: BoardRequest) -> HintResponse:
    try:
        row, col, value, explanation = prolog.hint(request.puzzle.to_prolog(), request.board)
    except prolog.NoSolution:
        raise HTTPException(status_code=422, detail=NO_SOLUTION) from None
    except prolog.BoardComplete:
        raise HTTPException(status_code=422, detail=BOARD_COMPLETE) from None
    return HintResponse(row=row, col=col, value=value, explanation=explanation)
