<!--
  TEMPLATE DO RELATÓRIO DE ENTREGA: Paradigmas de Programação

  Como usar:
  - Copie este arquivo para a raiz do repositório do grupo, com o nome
    RELATORIO.md, e preencha todas as seções.
  - Os textos entre <!- - e - -> (como este) são instruções. Eles não
    aparecem quando o arquivo é visualizado, mas APAGUE-OS antes de entregar.
  - Troque tudo o que estiver entre [colchetes].
  - Seja direto. Frases curtas e listas valem mais que parágrafos longos.
    Um relatório típico cabe em 4 a 8 páginas.
  - O relatório e o código são avaliados juntos. Sempre que possível,
    aponte para o código (arquivo e linha) em vez de descrevê-lo. Os
    critérios de avaliação estão em AVALIACAO.md.
  - ANTES DE ENTREGAR, rode o validador na raiz do repositório:

        uv run scripts/validar_entrega.py

    Ele confere a FORMA do relatório (comentários apagados, colchetes
    preenchidos, tabelas bem formadas, seções presentes, arquivos
    existentes), não o conteúdo. Corrija todos os ERROS apontados.
-->

# Torres Latinas

## 1. Identificação

<!--
  Os grupos têm de 3 a 7 pessoas (5, em média). A tabela abaixo tem 5
  linhas: adicione ou remova linhas conforme o tamanho do seu grupo, aqui e
  na seção 10. Os grupos podem misturar alunos das turmas das 14h e das 16h:
  indique a turma de CADA integrante.
-->

| Nome completo                   | Matrícula | Turma (14h/16h) | Usuário GitHub   |
| ------------------------------- | --------- | --------------- | ---------------- |
| Magno Luiz Vale Vieira          | 180042696 | 16h             | @magnluiz        |
| Maciel Ferreira Custodio Junior | 190100087 | 16h             | @macieljuniormax |
| Eduardo Belarmino Silva         | 221008580 | 16h             | @eduard0803      |

- **Nome do projeto:** Torres Latinas
- **Nome do grupo:** Torres Latinas
  <!--
    O nome do grupo identifica vocês nas planilhas de notas e na chamada
    para a apresentação. Não dá para validar se é único, então caprichem:
    "Grupo 3" vai colidir com o "Grupo 3" da outra turma.
  -->
- **Repositório:** [torres-prolog-elm](https://github.com/magnluiz/torres-prolog-elm)
- **Commit ou tag entregue:** [`a1b2c3d` ou `v1.0`]
  <!--
    O avaliador vai olhar exatamente esta versão. Para criar uma tag:
      git tag v1.0 && git push origin v1.0
  -->
- **Ponto de partida:** Remix original
  <!--
    Escolha UMA faixa. Ela define o ajuste de escopo da nota do grupo
    (AVALIACAO.md, seção 1.5). O professor confirma a faixa na apresentação.
  -->
- **Slides da apresentação oral:** [`docs/apresentacao.pdf` | link externo | não há]
  <!--
    No final do semestre, cada grupo faz uma apresentação oral de 15
    minutos. Slides são opcionais; se o grupo usar, coloque o arquivo no
    repositório (de preferência em PDF) e indique o caminho aqui.
  -->

## 2. Resumo

<!--
  De 3 a 5 linhas: o que o sistema faz, para quem, e qual problema o
  Prolog resolve nele. Quem ler só esta seção deve entender o projeto.
-->

O Torres Latinas é um jogo de lógica executado no navegador, voltado para pessoas que gostam de desafios e quebra-cabeças. O objetivo é preencher uma grade com alturas de prédios, respeitando as regras de quadrado latino, visibilidade e pontos entre casas vizinhas. O Prolog é responsável por representar as regras como restrições lógicas, gerar puzzles com solução única, resolver tabuleiros e fornecer dicas ao jogador. A interface é desenvolvida em Elm, enquanto o Python realiza a comunicação entre o frontend e o Prolog.

[Resumo do projeto.]

![Captura de tela do sistema](docs/torres-latinas.png)

<!-- Uma ou duas capturas de tela da interface. Crie a pasta docs/ se precisar. -->

## 3. Como executar

<!--
  Teste estas instruções numa máquina "limpa" (ou peça a um colega de
  outro grupo). Se o avaliador não conseguir rodar o sistema, o resto do
  trabalho não pode ser verificado.
-->

**Requisitos** (com as versões que o grupo usou):

- SWI-Prolog [11.0.0]
- Node.js [20.20.0]
- [uv / Python 3.10.12, se usar]

**Instalação e execução:**

```sh
make install
make dev
```

**Testes:**

```sh
make test
```

**Testado em:** [Linux / Windows / macOS, navegador]

## 4. Arquitetura

<!--
  Um diagrama simples (pode ser em texto) mostrando as partes do sistema e
  como elas se comunicam. Diga em uma frase a responsabilidade de cada parte.
-->

```
[Elm] --HTTP/JSON--> [Python] --janus--> [Prolog]
```

| Parte      | Responsabilidade                                                     | Arquivos principais                                                                                       |
| ---------- | -------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Prolog     | Define as regras, resolve e gera puzzles e produz dicas              | `backend/prolog/torres.pl`, `backend/prolog/explicador.pl`                                                |
| Python     | Valida o formato dos pedidos HTTP e encaminha as chamadas ao Prolog  | `backend/app/main.py`, `backend/app/prolog.py`                                                            |
| Elm        | Mantém o estado da partida, validações visuais e interface           | `frontend/src/Main.elm`, `frontend/src/Towers.elm`, `frontend/src/Api.elm`, `frontend/src/Statistics.elm` |
| JavaScript | Inicializa o Elm e lê e grava tema e recordes no armazenamento local | `frontend/src/main.js`                                                                                    |

## 5. Parte em Prolog

### 5.1 Predicados principais

<!--
  Os predicados mais importantes, com o local no código. Use a notação
  nome/aridade e indique entradas (+) e saídas (-), como na documentação
  do SWI-Prolog.
-->

| Predicado                                                                                                           | Local                             | O que faz                                                                                 |
| ------------------------------------------------------------------------------------------------------------------- | --------------------------------- | ----------------------------------------------------------------------------------------- |
| `towers/2` - `towers(?Puzzle, ?Rows)`                                                                               | `backend/prolog/torres.pl:79`     | Relaciona o puzzle à grade e impõe as restrições do jogo.                                 |
| `visible/2` - `visible(?Line, ?Count)`                                                                              | `backend/prolog/torres.pl:143`    | Relaciona uma sequência de alturas à quantidade de prédios visíveis.                      |
| `line_dots/2` - `line_dots(?Line, ?Dots)`                                                                           | `backend/prolog/torres.pl:162`    | Relaciona alturas vizinhas aos pontos, considerando também a ausência deles.              |
| `solve/2` - `solve(+Puzzle, -Solution)`                                                                             | `backend/prolog/torres.pl:176`    | Encontra uma solução para o puzzle.                                                       |
| `solve/3` - `solve(+Puzzle, +Board, -Solution)`                                                                     | `backend/prolog/torres.pl:188`    | Resolve o puzzle respeitando as alturas já colocadas no tabuleiro.                        |
| `count_solutions/3` - `count_solutions(+Puzzle, +Limit, -Count)`                                                    | `backend/prolog/torres.pl:196`    | Conta soluções até o limite informado; é usado para verificar se a solução é única.       |
| `generate/2` - `generate(+Difficulty, -Puzzle)`                                                                     | `backend/prolog/torres.pl:239`    | Gera um puzzle para a dificuldade informada.                                              |
| `hint/3` - `hint(+Puzzle, +Board, -Result)`                                                                         | `backend/prolog/torres.pl:348`    | Escolhe uma altura para sugerir e retorna uma explicação.                                 |
| `explain_cell/6` - `explain_cell(+Puzzle, +Board, +Row, +Col, +Value, -Explanation)`                                | `backend/prolog/explicador.pl:11` | Produz uma explicação para a altura sugerida.                                             |
| `explain_cell_deductive/7` - `explain_cell_deductive(+Puzzle, +Board, +Row, +Col, +Value, -Priority, -Explanation)` | `backend/prolog/explicador.pl:26` | Procura uma regra dedutiva que justifique a altura e retorna sua prioridade e explicação. |

### 5.2 Conceitos do paradigma lógico utilizados

<!--
  Marque o que o projeto usa DE FATO e indique onde. Não é preciso usar
  tudo; é preciso explicar bem o que foi usado.
-->

- [x] Fatos e regras como base de conhecimento: `difficulty/3` e `towers/2` (`backend/prolog/torres.pl:79, 234–236`)
- [x] Unificação e casamento de padrões: `visible_flags/3` e `line_dots/2` (`backend/prolog/torres.pl:150–166`)
- [x] Recursão (inclusive sobre listas): `visible_flags/3`, `line_dots/2` e `dig_clues/4` (`backend/prolog/torres.pl:150–166, 297–304`)
- [x] Backtracking e múltiplas soluções: `labeling/2` e `count_solutions/3` (`backend/prolog/torres.pl:176–202`)
- [x] `findall/3`, `bagof/3`, `setof/3` ou similares: `findall/3` em `torres.pl:197, 265, 289, 354, 366, 369, 387` e `explicador.pl:107, 124, 140, 162, 541, 608`
- [x] Corte (`!`) ou negação (`\+`), e por que foram necessários: cortes em `torres.pl:180, 211, 246, 257` controlam a busca; negações em `explicador.pl:105, 113, 128, 231, 543–544, 611–612` eliminam candidatos
- [x] Programação por restrições (CLP(FD) ou outra): `latin_square/2`, `visible/2` e `line_dots/2` (`backend/prolog/torres.pl:104–111, 143–166`)
- [x] Predicados de ordem superior (`maplist`, `foldl`, `include`...): `maplist/…` e `foldl/…` (`backend/prolog/torres.pl:86–111, 315`)

### 5.3 Trecho em destaque

<!--
  Escolha o trecho de Prolog de que o grupo mais se orgulha (ou o mais
  difícil). Cole o código e explique como ele funciona: o que é declarado,
  como o Prolog chega à resposta, e por que essa solução é "lógica" e não
  uma tradução de um algoritmo imperativo.
-->

```prolog
[trecho]
```

[Explicação.]

## 6. Parte em Elm

### 6.1 Modelo e mensagens

<!--
  Os tipos centrais do programa: o Model, o tipo Msg e os custom types do
  domínio. Explique as escolhas: por que um custom type e não um Bool, por
  que Maybe ou Result, etc.
-->

```elm
type alias Model =
    { game : Maybe Game
    , difficulty : Difficulty
    , mode : InputMode
    , status : Status
    , darkTheme : Bool
    , bestTimes : Statistics.BestTimes
    , showVictoryModal : Bool
    }


type alias Game =
    { puzzle : Puzzle
    , board : Board
    , history : History
    , selected : Maybe Position
    , difficulty : Difficulty
    , startedAt : Maybe Time.Posix
    , elapsedSeconds : Int
    , hintsUsed : Int
    , solverUsed : Bool
    , finished : Bool
    , newRecord : Bool
    }


type alias History =
    { past : List Board
    , future : List Board
    }


type Status
    = Idle
    | Thinking
    | HintGiven String
    | Failed String


type InputMode
    = Heights
    | Candidates


type Msg
    = NewGame Difficulty
    | GotPuzzle (Result String Puzzle)
    | CellClicked Position
    | HeightPressed Int
    | ErasePressed
    | ModeToggled
    | ThemeToggled Bool
    | MoveSelection Int Int
    | UndoPressed
    | RedoPressed
    | HintRequested
    | GotHint (Result String Api.Hint)
    | SolveRequested
    | GotSolution (Result String (List (List Int)))
    | ResetRequested
    | ErrorDismissed
    | ClockStarted Time.Posix
    | Tick Time.Posix
    | GameCompleted Time.Posix
    | VictoryModalDismissed

type Clue
    = NoClue
    | Sees Int


type Side
    = Top
    | Bottom
    | Left
    | Right


type Cell
    = Placed Int
    | Revealed Int
    | Marks (Set Int)
    | Empty


type Board
    = Board Int (Array Cell)


type ClueStatus
    = Unchecked
    | Satisfied
    | Violated


type Difficulty
    = Easy
    | Medium
    | Hard
```

O `Model` reúne o estado necessário para desenhar e atualizar a interface e a partida. Alguns campos são registros naturalmente binários, como `darkTheme` e `finished`, então `Bool` é adequado para eles. Para situações com mais de dois estados, usamos custom types.

Por exemplo, `Status` distingue `Idle`, `Thinking`, `HintGiven` e `Failed`. Um único `Bool` não representaria esses estados; vários booleanos poderiam permitir combinações inválidas, como o jogo estar carregando e exibindo um erro ao mesmo tempo. `InputMode` também usa `Heights` e `Candidates` para nomear o modo atual, em vez de deixar o significado de um `Bool` implícito.

`Cell` distingue uma altura colocada pelo jogador (`Placed`), uma revelada pelo Prolog (`Revealed`), candidatos anotados (`Marks`) e uma casa vazia (`Empty`). Isso permite tratar cada tipo de conteúdo de forma explícita. `Clue` diferencia `NoClue` de `Sees Int`, evitando usar o número `0` como um valor especial dentro do domínio. `Difficulty`, `Side` e `ClueStatus` também representam conjuntos específicos de opções, e seus construtores tornam o código mais claro e permitem ao compilador verificar se todos os casos foram tratados.

Usamos `Maybe` quando um valor pode estar ausente: `Maybe Game` representa que o puzzle ainda não chegou; `Maybe Position`, que não há casa selecionada; e `Maybe Time.Posix`, que o cronômetro ainda não começou. Isso evita inventar valores especiais para representar ausência. Nas respostas da API, `Result` representa os dois resultados possíveis de uma operação: sucesso ou erro. Por exemplo, `GotPuzzle (Result String Puzzle)` pode receber um puzzle válido ou uma mensagem de erro.

`Puzzle` é um custom type opaco: outros módulos não podem criá-lo diretamente. Os dados recebidos da API passam por `fromRaw`, que confere as dimensões antes de construir o puzzle. `Board` guarda o tamanho junto com as células, e `Cell` descreve o conteúdo de cada casa. `History` mantém as listas de tabuleiros anteriores e desfeitos para permitir desfazer e refazer.

Por fim, `Msg` enumera os eventos que o `update` pode receber, como jogadas, respostas da API, teclas e atualizações do cronômetro. Como cada evento é um construtor do tipo, o `case` do `update` pode tratar cada situação explicitamente.

### 6.2 Conceitos do paradigma funcional utilizados

- [ ] Arquitetura Elm (Model, update, view): [onde]
- [ ] Custom types e `case` exaustivo: [onde]
- [ ] `Maybe` e `Result` no lugar de null e exceções: [onde]
- [ ] Funções de ordem superior e aplicação parcial: [onde]
- [ ] Composição (`|>`, `>>`): [onde]
- [ ] Decoders e encoders JSON: [onde]
- [ ] Comandos e subscriptions (efeitos controlados): [onde]
- [ ] Imutabilidade e atualização de records: [onde]
- [ ] Outro: [...]

### 6.3 Trecho em destaque

```elm
[trecho]
```

[Explicação.]

## 7. Integração

<!--
  Curto: a parte Python não é avaliada. Liste as rotas ou a forma de
  comunicação e o formato dos dados trocados. Se o grupo não usou Python,
  explique como Elm e Prolog se comunicam.
-->

| Rota / chamada       | Entrada                                  | Saída                                           | Predicado Prolog |
| -------------------- | ---------------------------------------- | ----------------------------------------------- | ---------------- |
| `POST /api/generate` | Dificuldade (`easy`, `medium` ou `hard`) | Pistas e pontos do puzzle                       | `generate/2`     |
| `POST /api/solve`    | Puzzle e tabuleiro atual                 | Tabuleiro resolvido ou erro 422                 | `	solve/3`        |
| `POST /api/hint`     | Puzzle e tabuleiro atual                 | Linha, coluna, altura e explicação, ou erro 422 | `hint/3`         |

## 8. Testes e validação

<!--
  Como o grupo sabe que o sistema funciona? Testes automatizados (plunit,
  pytest, elm-test), roteiros de teste manual, casos de borda verificados.
-->

O projeto reúne testes PlUnit para as regras e o gerador (`backend/prolog/test_torres.pl`), testes do explicador (`backend/prolog/test_explicador.pl`), testes pytest para as rotas da API (`backend/tests/test_api.py`) e testes Elm para estatísticas (`frontend/tests/StatisticsTest.elm`). O alvo `make test` executa essas quatro suítes. Também usamos `npm run build` para compilar o frontend e make validar para verificar a estrutura dos arquivos de entrega.

Os testes cobrem regras do tabuleiro, geração e solução de puzzles, deduções explicadas, formato das respostas HTTP e cálculo de tempos e recordes. Foram verificados manualmente:

- geração de puzzles nos três níveis
- seleção e preenchimento de casas;
- modo de candidatos
- uso de dicas e do Resolver;
- desfazer e refazer jogadas
- cronômetro durante a partida;
- e conclusão do tabuleiro, incluindo a exibição do modal de vitória e o bloqueio das ações após a conclusão.

## 9. Limitações e problemas conhecidos

<!--
  Seja honesto. Um problema conhecido e bem descrito vale mais que um
  problema escondido que o avaliador descobre sozinho.
-->

- Os níveis são gerados automaticamente. “Fácil”, “médio” e “difícil” correspondem principalmente ao tamanho da grade e à proporção de pistas de borda mantidas; o gerador não mede a dificuldade lógica de cada puzzle (torres.pl:230–250). A unicidade da solução é verificada, mas isso não garante que o puzzle possa ser resolvido somente com as deduções ensinadas pelo explicador.
- Quando não encontra uma dedução direta coberta por suas regras, o explicador usa a solução do Prolog e apresenta uma explicação genérica (torres.pl:348–380). Portanto, nem toda dica representa uma cadeia de raciocínio humano passo a passo.
- O tema e os recordes são guardados no navegador. O progresso da partida não é persistido; fechar ou recarregar a página perde o tabuleiro atual.

## 10. Contribuição de cada integrante

<!--
  O que cada pessoa fez. Deve ser coerente com o histórico de commits do
  repositório. Todos os integrantes precisam concordar com esta tabela.
-->

| Integrante      | Principais contribuições                                                                                                                                                |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Maciel Custódio | Explicador de dicas em Prolog, desfazer/refazer, cronômetro e recordes por dificuldade, modal de vitória, testes do explicador e das estatísticas, melhorias no design. |
| [Nome]          | [...]                                                                                                                                                                   |
| [Nome]          | [...]                                                                                                                                                                   |

<!--
  Além desta tabela, que é do grupo, cada integrante entrega uma avaliação
  360 graus individual no SEU repositório do GitHub Classroom, em
  avaliacao-360/<matricula>.md. Veja o modelo em avaliacao-360/TEMPLATE.md.
-->

## 11. Fontes, código de terceiros e uso de IA

<!--
  Declare tudo o que não foi escrito pelo grupo. Declarar não tira pontos;
  deixar de declarar pode anular o trabalho.
-->

**Código reaproveitado.** Partimos do template de Sudoku da disciplina. Reaproveitamos a integração Python e a estrutura inicial do frontend, que foram adaptadas ao jogo Torres Latinas. As regras, o gerador, o resolvedor e as funcionalidades específicas do jogo foram desenvolvidos pelo grupo.

**Referências.** Documentação oficial do SWI-Prolog, incluindo CLP(FD) e Janus; guia oficial do Elm; documentação do FastAPI.

- https://www.swi-prolog.org/pldoc/man?section=clpfd
- https://www.swi-prolog.org/pldoc/man?section=janus
- https://guide.elm-lang.org/
- https://fastapi.tiangolo.com/

**Uso de ferramentas de IA.**

- **Faixa de uso no código:** [nenhum | pontual | auxiliar | intensivo]
  <!--
    nenhum: não usou. pontual: autocompletar, dúvidas, explicar erros.
    auxiliar: trechos gerados pela IA e revisados pelo grupo. intensivo: a
    IA escreveu a maior parte do código. Veja o efeito em AVALIACAO.md,
    seção 1.5. Não declarar anula o trabalho; declarar não tira pontos.
  -->

| Ferramenta    | Para que foi usada                                                                                                                                                  | Como o grupo verificou o resultado                                                             |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| ChatGPT/Codex | Apoio na criação de testes unitários, discussão de regras e deduções para as dicas, sugestões e complementação de código, explicação de erros e revisão de trechos. | O grupo revisou e adaptou as sugestões, executou os testes e conferiu o comportamento do jogo. |

## 12. Apresentação oral

<!--
  A apresentação tem 15 minutos e acontece no final do semestre. Uma
  divisão que costuma funcionar: 2 min de contexto, 5 min de demonstração
  do sistema funcionando, 6 min mostrando o código Prolog e Elm mais
  interessante, 2 min de limitações e aprendizados. Todos os integrantes
  devem falar.

  Preencha esta seção antes da apresentação.
-->

- **Slides:** [mesmo caminho indicado na seção 1, ou "não há"]
- **Roteiro:**

| Parte                       | Duração | Quem apresenta |
| --------------------------- | :-----: | -------------- |
| [Contexto e objetivo]       | [2 min] | [Nome]         |
| [Demonstração]              | [5 min] | [Nome]         |
| [Código Prolog]             | [3 min] | [Nome]         |
| [Código Elm]                | [3 min] | [Nome]         |
| [Limitações e aprendizados] | [2 min] | [Nome]         |

## 13. Reflexão sobre os paradigmas

<!--
  De 1 a 3 parágrafos. Perguntas que podem ajudar:
  - O que ficou mais simples em Prolog do que seria numa linguagem
    imperativa? E o que ficou mais difícil?
  - O que o compilador do Elm impediu que desse errado?
  - Como a forma de pensar mudou entre as duas linguagens?
-->

[Reflexão.]

---

<!--
  CHECKLIST ANTES DE ENTREGAR (apague esta seção depois de conferir)

  - [ ] `uv run scripts/validar_entrega.py` termina sem erros.
  - [ ] Todos os integrantes, com matrícula e turma, estão na seção 1.
  - [ ] O commit ou tag da seção 1 existe no repositório e é a versão final.
  - [ ] As instruções da seção 3 funcionam numa máquina sem nada instalado
        além dos requisitos listados.
  - [ ] Os locais indicados (arquivo:linha) conferem com o commit entregue.
  - [ ] As seções 10 e 11 foram revisadas por todo o grupo.
  - [ ] Se há slides, o arquivo está no repositório e o caminho da seção 1
        está certo.
  - [ ] Cada integrante entregou a própria avaliação 360 graus no seu
        repositório individual, em avaliacao-360/<matricula>.md.
  - [ ] Nenhum texto entre [colchetes] ou comentário de instrução sobrou.
-->
