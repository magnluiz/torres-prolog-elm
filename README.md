# Torres Latinas (Prolog + Elm)

Um quebra-cabeça lógico jogado no navegador: o Prolog cria, resolve e dá
dicas, e o Elm desenha a interface. O Python só faz a ponte entre os dois.

O jogo é um **remix**: junta o Arranha-céus (pistas de visibilidade) com os
pontos do Kropki, mais uma regra própria sobre a falta de pontos.

```
┌──────────────────────┐   HTTP/JSON   ┌───────────────────┐  janus  ┌──────────────────┐
│ Navegador            │ ────────────▶ │ FastAPI (Python)  │ ──────▶ │ SWI-Prolog       │
│ Elm + daisyUI (Vite) │ ◀──────────── │ backend/app/      │ ◀────── │ backend/prolog/  │
└──────────────────────┘               └───────────────────┘         └──────────────────┘
```

## Regras

A grade tem N × N casas (4×4 no fácil, 5×5 no médio, 6×6 no difícil). Cada
casa recebe a altura de um prédio, de 1 a N.

1. **Quadrado latino.** Cada linha e cada coluna tem todas as alturas de 1 a
   N, sem repetir.
2. **Visibilidade.** Um número na borda diz quantos prédios se veem olhando
   daquele lado. Um prédio esconde todos os mais baixos que estão atrás dele.
   Olhando `2 1 4 3` da esquerda, veem-se 2 prédios (o 2 e o 4).
3. **Pontos (regra própria).** Entre duas casas vizinhas há um ponto **se e
   somente se** as alturas diferem de exatamente 1. Todos os pontos aparecem,
   então a falta de ponto também é informação: ali a diferença não é 1.

Os puzzles gerados têm sempre solução única.

## O que cada parte faz

**Prolog** (`backend/prolog/torres.pl`). Cada regra vira uma restrição de
CLP(FD). O mesmo predicado `visible/2` serve para conferir uma pista e para
calculá-la, e é assim que o gerador descobre as pistas de uma grade
sorteada. Os predicados principais são:

- `solve/2` e `solve/3` resolvem um puzzle (o segundo respeita as casas já
  preenchidas pelo jogador);
- `generate/2` cria um puzzle de solução única, no nível `easy`, `medium` ou
  `hard`;
- `hint/3` revela a altura de uma casa vazia, ou avisa que o tabuleiro está
  completo ou que não tem solução.

**Python** (`backend/app/`). `prolog.py` carrega o `.pl` com o
[janus](https://www.swi-prolog.org/pldoc/man?section=janus); `main.py`
expõe os predicados como rotas HTTP com o FastAPI e confere só as dimensões
do JSON.

**Elm** (`frontend/src/`), na Arquitetura Elm:

- `Towers.elm` é o domínio puro: tipos do puzzle e do tabuleiro, e as
  verificações instantâneas (alturas repetidas, pontos e pistas de linhas
  completas). Não faz HTTP nem HTML.
- `Api.elm` faz as requisições e converte JSON em valores Elm.
- `Main.elm` cuida do estado, do teclado e da tela.

O visual fica em `frontend/src/style.css` (completo) ou
`frontend/src/style-simples.css` (minimalista). Para trocar de um para o
outro, mude o `import` em `frontend/src/main.js`.

## Requisitos

- [SWI-Prolog](https://www.swi-prolog.org/Download.html) 9.2 ou mais novo
  (o comando `swipl` precisa estar no PATH);
- [uv](https://docs.astral.sh/uv/) para o Python (ele instala o Python certo
  sozinho);
- [Node.js](https://nodejs.org) 20 ou mais novo, com `npm`.

O projeto fixa o Python 3.14 (`backend/.python-version`), porque é a versão
para a qual o `janus-swi` tem pacote pré-compilado no Windows. Com outra
versão, o `uv sync` tenta compilar o pacote e exige o compilador C++ da
Microsoft.

No Windows, sem `make`, os comandos estão logo abaixo. Para instalar as
ferramentas: `winget install SWI-Prolog.SWI-Prolog astral-sh.uv OpenJS.NodeJS.LTS`.

## Como rodar

```sh
make install    # instala as dependências (uma vez só)
make dev        # sobe backend e frontend
```

Abra http://localhost:5173. A documentação interativa da API fica em
http://localhost:8000/docs.

Sem `make`, abra dois terminais:

```sh
# terminal 1
cd backend
uv sync
uv run fastapi dev app/main.py

# terminal 2
cd frontend
npm install
npm run dev
```

## Jogando

- Clique numa casa (ou use as setas) e digite a altura, ou use o teclado da tela.
- `N` ou o botão "✎ Candidatos" liga o modo de anotação: os números viram
  candidatos no canto da casa. Ao colocar uma altura, esse candidato some
  das casas da mesma linha e coluna.
- Casas com altura repetida ou incompatível com um ponto ficam listradas de
  vermelho. Uma pista fica verde quando a linha completa a cumpre e vermelha
  quando não cumpre.
- "Dica" pede ao Prolog a altura de uma casa vazia; "Resolver" mostra a
  solução inteira.

## Brincando com o Prolog direto no terminal

```
$ swipl backend/prolog/torres.pl
?- example_puzzle(P), solve(P, S), print_grid(S).
?- generate(medium, P), print_puzzle(P).
?- visible([2,1,4,3], K).
?- length(L, 4), L ins 1..4, all_distinct(L), visible(L, 3), label(L).
```

A última consulta roda `visible/2` "ao contrário": lista as linhas de 4
prédios em que se veem exatamente 3.

## Testes

```sh
make test           # tudo
make test-prolog    # só os testes em Prolog (plunit)
make test-backend   # só os testes da API (pytest)
```

Sem `make`:

```sh
swipl -g run_tests -t halt backend/prolog/test_torres.pl
cd backend && uv run pytest
```

## API

Todas as rotas recebem e devolvem JSON. Um tabuleiro é uma lista de N linhas
com N inteiros, e 0 é casa vazia. Um puzzle é:

```json
{
  "top": [0, 3, 0, 0, 1],      "bottom": [0, 0, 0, 2, 0],
  "left": [3, 0, 0, 0, 2],     "right": [0, 0, 4, 3, 0],
  "hdots": [[1, 0, 0, 0], ...],
  "vdots": [[1, 1, 1, 0, 1], ...]
}
```

Nas pistas, 0 é "sem pista". `hdots` tem N linhas com N−1 valores (1 = ponto
entre a casa e a vizinha da direita); `vdots` tem N−1 linhas com N valores
(1 = ponto entre a casa e a de baixo).

| Rota                 | Corpo enviado                 | Resposta                           |
| -------------------- | ----------------------------- | ---------------------------------- |
| `POST /api/generate` | `{"difficulty": "medium"}`    | `{"puzzle": {...}}`                |
| `POST /api/solve`    | `{"puzzle": {...}, "board": [[...]]}` | `{"board": [[...], ...]}`  |
| `POST /api/hint`     | `{"puzzle": {...}, "board": [[...]]}` | `{"row": 0, "col": 4, "value": 3}` |

Quando o tabuleiro não tem solução, `solve` e `hint` respondem com status 422
e `{"detail": "mensagem"}`. `hint` também responde 422 quando o tabuleiro já
está completo.

## Problemas comuns

**`Microsoft Visual C++ 14.0 or greater is required`** no `uv sync`
(Windows). O `uv` está tentando compilar o `janus-swi`. Confira se o
Python usado é o 3.14 (`uv run python --version`).

**`ImportError: libswipl.so.9`** (Linux). O `janus-swi` foi compilado
contra outra versão do SWI-Prolog. Recompile:

```sh
cd backend
uv sync --reinstall-package janus-swi --no-binary-package janus-swi --no-cache
```

## Estrutura

```
backend/
  prolog/torres.pl        regras, resolvedor, gerador e dica
  prolog/test_torres.pl   testes plunit
  app/prolog.py           ponte Python → Prolog (janus)
  app/main.py             rotas HTTP (FastAPI)
  tests/test_api.py       testes da API
frontend/
  src/Main.elm            Arquitetura Elm: estado, eventos, tela
  src/Towers.elm          tipos e verificações do jogo (puro)
  src/Api.elm             HTTP e JSON
  src/main.js             inicia o Elm e lembra o tema escolhido
  src/style.css           visual completo
  src/style-simples.css   visual minimalista (mesmas classes)
Makefile                  atalhos (install, dev, test, validar)
RELATORIO.md              relatório de entrega
AVALIACAO.md              critérios de avaliação da disciplina
scripts/                  validador da entrega e ferramentas do professor
```

## Origem

Projeto do trabalho final de Paradigmas de Programação, a partir do
template do Sudoku da disciplina. A integração Python, a estrutura do
frontend e o visual vieram do template; as regras, o Prolog e os módulos Elm
do jogo foram reescritos. Os critérios de entrega estão em `AVALIACAO.md`.
