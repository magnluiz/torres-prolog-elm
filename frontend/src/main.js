// Ponto de entrada JavaScript. O Vite começa por aqui (veja index.html).
// Escolha UM dos dois estilos (as classes são as mesmas nos dois):
//   style.css          visual completo: temas próprios, fontes, gradientes,
//                      animações e várias técnicas de CSS moderno
//   style-simples.css  visual minimalista, quase só com @apply do Tailwind;
//                      um ponto de partida mais fácil de entender e modificar
import "./style.css";
// import "./style-simples.css";

// O vite-plugin-elm permite importar um módulo Elm como se fosse JS: ele
// compila src/Main.elm e recompila a cada alteração (hot reload).
import { Elm } from "./Main.elm";

// Tema inicial: a última escolha do jogador (guardada no localStorage do
// navegador) ou, na primeira visita, a preferência do sistema operacional.
const THEME_KEY = "torres-theme";
const savedTheme = localStorage.getItem(THEME_KEY);
const systemIsDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
const darkTheme = savedTheme ? savedTheme === "dark" : systemIsDark;
const BEST_TIMES_KEY = "torres-best-times";
const MATCH_STATS_KEY = "torres_latinas_match_stats";

function loadBestTimes() {
  try {
    const saved = JSON.parse(localStorage.getItem(BEST_TIMES_KEY) || "{}") || {};
    const validSeconds = (value) =>
      Number.isInteger(value) && value >= 0 ? value : null;

    return {
      easy: validSeconds(saved.easy),
      medium: validSeconds(saved.medium),
      hard: validSeconds(saved.hard),
    };
  } catch {
    return { easy: null, medium: null, hard: null };
  }
}

function loadMatchStats() {
  const emptyStats = {
    easyGamesPlayed: 0,
    easyWins: 0,
    mediumGamesPlayed: 0,
    mediumWins: 0,
    hardGamesPlayed: 0,
    hardWins: 0,
  };

  try {
    const raw = localStorage.getItem(MATCH_STATS_KEY);
    if (!raw) {
      return emptyStats;
    }
    const parsed = JSON.parse(raw) || {};
    const validCount = (value) =>
      typeof value === "number" && Number.isFinite(value) && value >= 0
        ? Math.floor(value)
        : 0;

    return {
      easyGamesPlayed: validCount(parsed.easyGamesPlayed),
      easyWins: validCount(parsed.easyWins),
      mediumGamesPlayed: validCount(parsed.mediumGamesPlayed),
      mediumWins: validCount(parsed.mediumWins),
      hardGamesPlayed: validCount(parsed.hardGamesPlayed),
      hardWins: validCount(parsed.hardWins),
    };
  } catch {
    return emptyStats;
  }
}

// `flags` é entregue à função `init` do Elm (veja o tipo Flags em Main.elm).
const app = Elm.Main.init({
  node: document.getElementById("app"),
  flags: {
    darkTheme,
    bestTimes: loadBestTimes(),
    matchStats: loadMatchStats(),
  },
});

app.ports.saveBestTimes.subscribe((bestTimes) => {
  localStorage.setItem(BEST_TIMES_KEY, JSON.stringify(bestTimes));
});

if (app.ports && app.ports.saveMatchStats) {
  app.ports.saveMatchStats.subscribe((stats) => {
    try {
      localStorage.setItem(MATCH_STATS_KEY, JSON.stringify(stats));
    } catch {
      // Ignora falhas de armazenamento (ex.: modo privado ou cota excedida)
    }
  });
}

// Guarda a escolha quando o botão de tema muda. Ouvimos o evento no
// `document` inteiro ("delegação de eventos") porque o checkbox é criado pelo
// Elm e pode ser recriado a qualquer momento.
//
// Isto poderia ser feito com uma PORT do Elm (um canal de mensagens entre Elm
// e JavaScript), mas para algo tão simples o JavaScript sozinho basta.
document.addEventListener("change", (event) => {
  if (event.target.matches(".theme-controller")) {
    localStorage.setItem(THEME_KEY, event.target.checked ? "dark" : "light");
  }
});
