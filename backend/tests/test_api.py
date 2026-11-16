"""Testes da API HTTP (pytest).

Usamos o TestClient do FastAPI: ele chama a aplicação diretamente, sem subir
um servidor nem abrir porta.

Rodar: `uv run pytest` (na pasta backend) ou `make test-backend` (na raiz).

As regras do jogo são testadas em Prolog (prolog/test_torres.pl). Aqui
conferimos só a "cola": rotas, formato do JSON e códigos de status.
"""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)

# O mesmo puzzle de example_puzzle/1 em torres.pl.
EXAMPLE = {
    "top": [4, 3, 2, 1],
    "bottom": [1, 2, 2, 2],
    "left": [4, 3, 2, 1],
    "right": [1, 2, 2, 2],
    "hdots": [[1, 1, 1], [1, 1, 0], [1, 0, 1], [0, 1, 1]],
    "vdots": [[1, 1, 1, 0], [1, 1, 0, 1], [1, 0, 1, 1]],
}
SOLUTION = [[1, 2, 3, 4], [2, 3, 4, 1], [3, 4, 1, 2], [4, 1, 2, 3]]
EMPTY = [[0] * 4 for _ in range(4)]


def test_solve():
    response = client.post("/api/solve", json={"puzzle": EXAMPLE, "board": EMPTY})
    assert response.status_code == 200
    assert response.json()["board"] == SOLUTION


def test_solve_with_wrong_height():
    board = [row[:] for row in EMPTY]
    board[0][0] = 4  # a solução tem 1 aqui
    response = client.post("/api/solve", json={"puzzle": EXAMPLE, "board": board})
    assert response.status_code == 422


def test_rejects_board_of_wrong_size():
    response = client.post("/api/solve", json={"puzzle": EXAMPLE, "board": [[0] * 5] * 5})
    assert response.status_code == 422


def test_rejects_malformed_puzzle():
    puzzle = {**EXAMPLE, "hdots": [[1, 1]]}
    response = client.post("/api/solve", json={"puzzle": puzzle, "board": EMPTY})
    assert response.status_code == 422


def test_generate():
    response = client.post("/api/generate", json={"difficulty": "easy"})
    assert response.status_code == 200
    puzzle = response.json()["puzzle"]
    assert len(puzzle["top"]) == 4
    assert len(puzzle["hdots"]) == 4 and len(puzzle["vdots"]) == 3


def test_hint():
    response = client.post("/api/hint", json={"puzzle": EXAMPLE, "board": EMPTY})
    assert response.status_code == 200
    hint = response.json()
    assert SOLUTION[hint["row"]][hint["col"]] == hint["value"]


def test_hint_on_complete_board():
    response = client.post("/api/hint", json={"puzzle": EXAMPLE, "board": SOLUTION})
    assert response.status_code == 422
    assert response.json()["detail"] == "O tabuleiro já está completo."
