# StitchMind — Rastreabilidade em Tempo Real (estilo Clarity)

> Evolução da telemetria atual (eventos em batch) para um sistema **ao vivo**:
> WebSocket mostrando **quantos usuários estão em cada tela agora**, feed de eventos
> em tempo real, **session replay**, **heatmaps de toque** e **sinais de frustração**
> (rage tap, dead tap, quick-back) — o equivalente do Microsoft Clarity para um app Flutter.

## ✅ Status

| Fase | Status |
|------|--------|
| **A — Presença WebSocket** | ✅ **ENTREGUE** — Redis no compose, WS `/v1/rt/app` + `/v1/rt/admin`, app conecta, aba **"Ao vivo"** mostra usuários por tela + feed ao vivo |
| **B — Feed de eventos ao vivo** | ✅ **ENTREGUE** (junto da Fase A) |
| **C — Heatmaps + rage/dead tap** | ✅ **ENTREGUE** — `Listener` global captura toques, tabela `taps`, aba **Heatmaps** (amarelo=normal, vermelho=rage) |
| **D — Session replay (timeline)** | ✅ **ENTREGUE** — aba **Replay**: lista de sessões + timeline reconstruída (telas/toques/crash com timestamps) |
| **F — Insights / funis / retenção** | ✅ **ENTREGUE** — aba **Insights**: funil de conversão, retenção D1/D7/D30, tempo por tela, rage por tela, quick-backs |
| E — Replay visual (frames) | ⏳ opcional (pesado + privacidade) — timeline (D) já cobre "assistir a jornada" |

**Como ver:** painel http://localhost:8000/admin → abas **● Ao vivo**, **Heatmaps**, **Replay**, **Insights**.
Tudo testado com dados reais do app no simulador + seeds.

---

## 0. O que já existe (base)

- Telemetria por **batch** (`/v1/events`): device, sessão, `screen_view` automático.
- Tabelas `events`, `app_sessions`, `devices`, `crashes` no Postgres.
- Painel admin com Analytics por tela (agregado, **não** ao vivo).

**Faltam:** canal em tempo real (WebSocket), presença por tela, replay, heatmaps, insights.

---

## 1. Arquitetura alvo

```
   App Flutter ──WS──┐                         ┌──WS── Painel "Ao vivo"
   (RealtimeService) │                         │       (live presence + feed)
                     ▼                         ▼
        ┌────────────────────────────────────────────────┐
        │              API (Bun + Hono)                   │
        │  /v1/rt/app   (clientes do app)                 │
        │  /v1/rt/admin (dashboards)                      │
        │   ├─ presença em memória + Redis                │
        │   └─ pub/sub p/ broadcast entre instâncias      │
        └───────────────┬───────────────┬────────────────┘
                        │               │
                   ┌────▼────┐     ┌────▼─────┐
                   │  Redis  │     │ Postgres │
                   │presence │     │ eventos, │
                   │ pub/sub │     │ taps,    │
                   └─────────┘     │ frames   │
                                   └──────────┘
```

- **Redis** vira peça central: guarda **presença** (efêmera, com TTL) e faz **pub/sub**
  para que qualquer instância da API envie atualizações a todos os sockets admin.
  (Já temos um container Redis; será formalizado no `docker-compose`.)
- **WebSocket** via `hono/bun` (`createBunWebSocket`) — o `export default` da API passa
  a expor `{ port, fetch, websocket }`. Pelo proxy Caddy, WS faz upgrade nativo.

---

## 2. Presença em tempo real (o coração do pedido)

### Backend
- Endpoints WS: `/v1/rt/app?token=...` (app) e `/v1/rt/admin?token=...` (admin, exige role).
- **Estado por conexão** (Redis):
  - `presence:conn:<connId>` = hash `{user_id, device_id, screen, since, platform, app_version}` com **TTL ~30s** (renovado por heartbeat).
  - `presence:screen:<screen>` = set de `connId`.
  - `presence:online` = set de todos os `connId`.
- **Mensagens do app → API:**
  - `hello` `{device_id, app_version, platform}` no connect.
  - `screen` `{name}` a cada troca de tela (entra/sai do set da tela).
  - `ping` a cada ~10s (renova TTL).
- **Broadcast API → admin** (em mudança + a cada ~2s, throttled):
  - `presence` `{ total_online, by_screen: { painel: 3, aula_detalhe: 1, ... } }`.
- **Expiração**: TTL vencido (app fechou/caiu) remove a conexão e recalcula contagem.

### App (`RealtimeService`)
- Abre WS, manda `hello`, reconecta com backoff exponencial.
- Hook no `TelemetryNavigatorObserver`: cada `screen_view` também envia `screen` pelo WS.
- Heartbeat `ping` por timer; fecha no `detached`.

### Painel — nova aba **"Ao vivo"**
- **Usuários online agora** (número grande, pulsa a cada update).
- **Usuários por tela** (barras que sobem/descem em tempo real).
- **Mapa de telas** do app com a contagem em cada nó.
- **Feed de eventos ao vivo** (rolando): "usuário X abriu Aula 1", "tap em Concluir", "crash".

---

## 3. Features estilo Clarity (por fase)

### 3.1 Feed de eventos ao vivo
- Cada evento ingerido publica em `rt:events` (Redis pub/sub) → admin recebe stream throttled.
- Filtros: por tela, plataforma, versão, "só erros".

### 3.2 Heatmaps de toque
- App captura **taps** com coordenada **normalizada** (`x/largura`, `y/altura`) + tela + label do widget tocado.
- Nova tabela `taps (id, session_id, user_id, device_id, screen, x, y, label, is_rage, is_dead, ts)`.
- Admin renderiza **heatmap** sobreposto a uma **imagem de referência** da tela
  (capturada pelo app 1× por tela, "limpa", ou enviada manualmente).
- Tipos: mapa de cliques, mapa de área tocada.

### 3.3 Sinais de frustração (smart events do Clarity)
- **Rage tap**: ≥3 toques na mesma região em <1s → marca a sessão e o ponto.
- **Dead tap**: toque que não gera navegação nem mudança de estado (toca em algo "morto").
- **Quick-back**: entra numa tela e sai em <2s (tela confusa/errada).
- **Excessive scroll**: rolagem longa sem parar (procurando algo).
- **Error session**: sessão que contém crash.
- Detecção leve no app (heurística) + confirmação/agregação no backend.

### 3.4 Session replay
Duas fidelidades (escolher; podem coexistir):

**(A) Replay por linha do tempo (recomendado p/ começar — barato, sem privacidade pesada)**
- Reconstrói a sessão como **timeline ordenada**: telas, toques (com x,y e label),
  scrolls, inputs (mascarados), chamadas de API, erros.
- "Player" no admin = scrubber que avança a timeline desenhando os toques sobre a
  imagem de referência da tela. Mostra *o que* o usuário fez, sem gravar pixels.

**(B) Replay visual por frames (opcional, fiel ao Clarity — mais pesado + privacidade)**
- App captura **screenshots downscaled e MASCARADOS** (via `RepaintBoundary`), só em
  interação/intervalo, com **texto e inputs borrados por padrão**.
- Upload p/ MinIO; tabela `replay_frames (session_id, ts, asset_id, screen)`.
- Player remonta os frames numa "gravação". Exige revisão de privacidade/LGPD.

### 3.5 Insights, funis e retenção
- **Dwell time** por tela (tempo médio), telas de "saída".
- **Funis**: painel → abriu aula → assistiu → concluída (taxa de conversão por passo).
- **Retenção** D1/D7/D30; **segmentos** (plataforma, versão, "tem crash", "fez rage tap").
- Dashboard de insights: "telas com mais rage tap", "telas com mais quick-back".

---

## 4. Modelo de dados (novidades)

```
taps          (id, session_id, user_id, device_id, screen, x, y, label,
               is_rage, is_dead, ts)                      -- heatmap + frustração
replay_frames (id, session_id, ts, asset_id, screen)      -- replay visual (fase B)
screen_time   (derivado de events: enter/leave por tela)  -- dwell time
```
- `events` ganha índice em `session_id` (replay/timeline).
- **Redis** (efêmero, não vai pro Postgres): presença e pub/sub.

---

## 5. Infra

- Adicionar **`redis:7`** ao `docker-compose` (presença + pub/sub).
- API passa a exportar `websocket` (Bun) além de `fetch`.
- **Caddy** (produção): WebSocket faz upgrade nativo; só garantir `/v1/rt/*` roteado.
- Escala horizontal: presença no Redis + pub/sub deixa N instâncias da API consistentes.

---

## 6. Privacidade (Clarity mascara por padrão — nós também)

- **Mascarar todo texto/input** em qualquer captura de frame (fase B), por padrão.
- **Allowlist de telas** sensíveis nunca capturadas (ex.: pagamento, login).
- Consentimento + **opt-out**; endpoint de **exclusão de dados** (LGPD) que limpa
  events/taps/frames/replay do usuário.
- Coordenada de toque é anônima; nada de PII em `props`.

---

## 7. Roadmap por fases

| Fase | Entrega | Resultado |
|------|---------|-----------|
| **A — Presença WS** | Redis no compose, WS app+admin, aba "Ao vivo" | **Quantos usuários em cada tela, ao vivo** |
| **B — Feed ao vivo** | pub/sub de eventos + dwell time | Stream de ações em tempo real |
| **C — Heatmaps** | captura de taps + tabela `taps` + overlay | Mapa de cliques por tela + rage/dead tap |
| **D — Replay (timeline)** | timeline por sessão + player scrubber | "Assistir" o que o usuário fez |
| **E — Replay visual** | frames mascarados + MinIO + player | Gravação fiel (opt-in, privacidade) |
| **F — Insights** | funis, retenção, segmentos, sinais | Dashboard analítico completo |

---

## 8. Decisão pendente
- **Fidelidade do replay**: começar por **(A) timeline** (rápido, leve, sem privacidade
  pesada) e deixar **(B) frames visuais** como fase opcional? — **recomendado**.
- Próximo passo natural: implementar a **Fase A (presença WebSocket)** já, que é
  exatamente "quantos usuários em cada tela em tempo real".
