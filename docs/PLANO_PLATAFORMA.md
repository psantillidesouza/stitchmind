# StitchMind — Plano da Plataforma (App + Backend + Painel Web)

> Transformar o StitchMind de um app **local** (Hive + mock) com backend **stateless**
> em uma **plataforma completa**: contas de usuário, CMS de aulas, telemetria por tela,
> contagem de usuários e crash reporting — tudo **self-hosted em Docker** com banco
> relacional **Postgres**.

## ✅ Status de implementação (entregue)

| Área | Status |
|------|--------|
| Infra Docker (Postgres + MinIO + API Bun) | ✅ rodando (`server/docker-compose.yml`) |
| Schema + migrations + seed | ✅ `server/db/migrations/` |
| Auth Firebase (validação de ID token) + **dev-mode** + RBAC | ✅ funciona; Firebase real = plugar projeto |
| CMS de aulas (CRUD cursos/aulas/blocos + upload mídia) | ✅ painel `http://localhost:8000/admin` |
| App: **Painel de Aulas como 1ª tela** (busca do backend) | ✅ rodando no simulador |
| App: detalhe da aula (blocos texto/imagem/vídeo/material) | ✅ (player de vídeo = placeholder, plugar `video_player`) |
| Telemetria: device + sessão + **auto screen_view** | ✅ eventos chegam no painel |
| Crash reporting (handler global → `/v1/crashes`) | ✅ captura e reporta |
| IA migrada p/ Postgres (`analyses`/`feedback`) | ✅ |
| **Pendente do usuário:** criar projeto Firebase real + rotacionar chave vazada | ⏳ |

> **Falta para "produção" de verdade:** (1) criar o projeto Firebase e trocar
> `DevAuthService`→`FirebaseAuthService` (1 arquivo); (2) plugar `video_player`/`chewie`
> no bloco de vídeo; (3) corrigir o vazamento da `ANTHROPIC_API_KEY` (ver §9).

---

## 0. Decisões travadas

| Tema | Decisão |
|------|---------|
| Conteúdo das aulas | **Misto** — vídeo + texto + imagens (blocos) |
| Login | **Firebase Auth** (email + senha) — backend valida o ID token e espelha o usuário no Postgres |
| Infra | **Tudo em Docker** (docker-compose), banco **Postgres** estruturado |
| Métricas/Crash | **Nosso backend** → tabelas Postgres → dashboards no **nosso painel web** |

> **Divisão de responsabilidade da identidade:** o **Firebase** é a fonte da verdade das
> **credenciais** (senha, reset de senha, verificação de email, futuros logins sociais).
> O **Postgres** guarda o **perfil de aplicação** do usuário (`firebase_uid`, role, progresso,
> telemetria) — porque aulas, eventos e crashes precisam de relação relacional com o usuário.
> Os dois ficam ligados pelo `firebase_uid`.

---

## 1. Estado atual (ponto de partida)

**App Flutter** (`lib/`, 37 arquivos)
- Riverpod + go_router + Hive (persistência **local**), dados vêm de `MockData`.
- 5 abas: `Início` · `Pontos` · `Projetos` · `Receitas` · `Você`.
- Única integração de rede: `AnalysisService` → `POST {ServerConfig.url}/analyze` e `/feedback`.
- Sem auth, sem usuários, sem telemetria, sem crash reporting.

**Backend** (`server/`, Bun + Hono)
- Stateless. Endpoints: `/health`, `/analyze`, `/feedback`, e (recém-adicionados) `/` (UI web) + `/metrics`.
- Persistência = arquivos `.jsonl` (sem banco).
- Providers de IA: Anthropic (default) e Gemini.

**Gaps para virar produto:** banco, storage de mídia, auth, CMS de aulas,
ingestão de eventos, ingestão de crashes, painel admin, e a camada de telemetria no app.

---

## 2. Arquitetura alvo

```
                    ┌───────────────────────┐
                    │   Firebase Auth (SaaS) │  ← credenciais (email/senha, reset)
                    └───────────┬────────────┘
                       ID token │ (verificado no backend)
┌─────────────────────────────────────────────────────────────────┐
│                        DOCKER COMPOSE          │                 │
│                                                ▼                 │
│  ┌──────────┐   ┌──────────────────┐   ┌──────────┐  ┌────────┐  │
│  │ Postgres │   │     API (Bun)    │   │  MinIO   │  │ Caddy  │  │
│  │   :5432  │◄──┤ Hono + verify    ├──►│  S3 self │  │ proxy  │  │
│  │ (dados)  │   │ Firebase token   │   │  :9000   │  │ :443   │  │
│  └──────────┘   └──────┬───────────┘   └──────────┘  └───┬────┘  │
│                        │                                  │       │
│                 ┌──────┴───────┐                          │       │
│                 │ Admin Web SPA│  (servida pela API ou container) │
│                 │  /admin      │                          │       │
│                 └──────────────┘                          │       │
└───────────────────────────────────────────────────────────┼──────┘
                                                            │
                  ┌─────────────────────────────────────────┴─────┐
                  │            App Flutter (iOS/Android)           │
                  │ firebase_auth · Painel de Aulas · Player ·     │
                  │ Telemetria · Crash handler                     │
                  └────────────────────────────────────────────────┘
```
> Fluxo: o app autentica via **Firebase Auth SDK** → recebe um **ID token (JWT)** →
> manda no header `Authorization: Bearer <idToken>` → a **API valida** o token com o
> **Firebase Admin SDK** e faz *upsert* do usuário no Postgres pelo `firebase_uid`.

**Serviços Docker**
| Serviço | Imagem | Função |
|---------|--------|--------|
| `db` | `postgres:16` | Banco relacional (fonte da verdade) |
| `storage` | `minio/minio` | Object storage S3-compatível p/ vídeos e imagens |
| `api` | build do `server/` (Bun) | REST: valida token Firebase, aulas, telemetria, crashes, IA |
| `admin` | build do painel (SPA) | CMS de aulas + dashboards (pode ser servido pela `api`) |
| `proxy` | `caddy:2` | TLS automático + roteamento (produção) |
| `migrate` | job one-shot | Roda migrations no boot |
| _(opcional)_ `redis` | `redis:7` | Cache / rate-limit / fila de eventos |

---

## 3. Banco de dados (Postgres — schema estruturado)

Migrations versionadas (ex.: `server/db/migrations/00x_*.sql`). Tudo com `uuid` PK,
`created_at`/`updated_at`, e índices nos campos de busca/telemetria.

### 3.1 Identidade & sessões
```
users          (id, firebase_uid UNIQUE, email UNIQUE, name, photo_url?,
                role[user|admin], status[active|blocked], email_verified,
                created_at, updated_at, last_seen_at)
devices        (id, user_id?, platform[ios|android], model, os_version,
                app_version, push_token?, first_seen_at, last_seen_at)
app_sessions   (id, user_id?, device_id, started_at, ended_at?, duration_s,
                app_version, platform)
```
> **Sem `password_hash` nem `refresh_tokens`** — quem cuida de senha, reset e refresh
> é o **Firebase**. A tabela `users` guarda só o espelho de aplicação, ligado pelo
> `firebase_uid`. `role` (user/admin) é definido por nós (claim custom no Firebase
> **ou** coluna no Postgres — usaremos a coluna como fonte da verdade do RBAC).
> `devices` permite **contar usuários/aparelhos mesmo antes do login**; ao logar,
> o device é vinculado ao `user_id`.

### 3.2 Aulas (conteúdo misto)
```
courses        (id, title, slug UNIQUE, description, cover_asset_id?, technique,
                level[beginner|intermediate|advanced], published, order_index,
                created_by, created_at, updated_at)
lessons        (id, course_id?, title, slug, description, technique, difficulty,
                duration_min, cover_asset_id?, status[draft|published],
                order_index, published_at?, created_by, created_at, updated_at)
lesson_blocks  (id, lesson_id, position, type[text|image|video|material],
                content jsonb, asset_id?)          -- blocos = conteúdo "misto"
assets         (id, kind[video|image|pdf], filename, mime, size_bytes,
                storage_key, width?, height?, duration_s?, uploaded_by, created_at)
```

### 3.3 Progresso & engajamento das aulas
```
lesson_progress (id, user_id, lesson_id, status[not_started|in_progress|completed],
                 progress_pct, last_position_s, completed_at?, updated_at,
                 UNIQUE(user_id, lesson_id))
lesson_views    (id, user_id?, device_id, lesson_id, started_at, watched_s)
```

### 3.4 Telemetria (o "o que o usuário tá fazendo")
```
events   (id, user_id?, device_id, session_id?, name, screen?, props jsonb,
          app_version, platform, ts)              -- evento genérico + screen_view
crashes  (id, user_id?, device_id, app_version, platform, os_version,
          error_type, message, stack_trace, is_fatal, breadcrumbs jsonb,
          fingerprint, ts)                         -- fingerprint agrupa crashes iguais
```

### 3.5 IA (migrar do `.jsonl` p/ o banco)
```
analyses (id, user_id?, provider, model, latency_ms, image_key?, result jsonb, created_at)
feedback (id, analysis_id, user_id?, section, rating[correct|partial|wrong], note?, created_at)
```

---

## 4. API (REST sob `/v1`, JWT)

**Auth (Firebase)**
- O **login/registro/reset acontecem no app via Firebase SDK** — não há endpoint nosso
  de senha. O app envia o **ID token** em `Authorization: Bearer <idToken>` em todas as chamadas.
- `POST /v1/auth/sync` → backend valida o ID token (Firebase Admin SDK) e faz *upsert*
  do usuário no Postgres (`firebase_uid`, email, name). Chamado no 1º login e quando o perfil muda.
- `GET  /v1/me` → perfil de aplicação + role + progresso resumido (a partir do token).
- **Middleware `requireAuth`**: valida o ID token (cacheia chaves públicas do Firebase),
  injeta `req.user`. **Middleware `requireAdmin`**: exige `role=admin` no Postgres.

**Devices & sessões** (telemetria pré/pós-login)
- `POST /v1/devices/register` `{platform, model, os_version, app_version}` → `device_id`
- `POST /v1/sessions/start` · `POST /v1/sessions/heartbeat` · `POST /v1/sessions/end`

**Aulas (app — leitura)**
- `GET /v1/courses` · `GET /v1/courses/:slug`
- `GET /v1/lessons` (filtros: technique, level) · `GET /v1/lessons/:slug` (com blocos)
- `POST /v1/lessons/:id/progress` `{status, progress_pct, last_position_s}`

**Aulas (admin — escrita, role=admin)**
- `POST/PATCH/DELETE /v1/admin/courses` · `.../lessons` · `.../lessons/:id/blocks`
- `POST /v1/admin/assets` → **upload** (multipart) → MinIO → retorna `asset_id` + URL
- `POST /v1/admin/lessons/:id/publish` | `/unpublish` | reorder

**Telemetria & crash (ingestão)**
- `POST /v1/events` `{events: [...]}` (batch) — auto screen_view + eventos custom
- `POST /v1/crashes` `{error_type, message, stack_trace, is_fatal, breadcrumbs}`

**Dashboards (admin)**
- `GET /v1/admin/overview` → usuários totais, DAU/WAU/MAU, sessões, crashes 24h
- `GET /v1/admin/users` (lista/busca) · `GET /v1/admin/users/:id` (timeline)
- `GET /v1/admin/analytics/screens` · `/events` · `/funnel`
- `GET /v1/admin/crashes` (agrupado por fingerprint) · `/crashes/:fingerprint`
- `GET /v1/admin/lessons/:id/metrics` (views, conclusão, retenção)

**IA (existente, agora autenticado + grava no banco)**
- `POST /v1/analyze` · `POST /v1/feedback`

Segurança transversal: autenticação via **Firebase ID token** validado no backend
(Firebase Admin SDK), **RBAC** (user vs admin via coluna no Postgres), validação **zod**
em todo input, rate-limit, CORS restrito, **URLs assinadas** do MinIO para mídia.
O **Service Account** do Firebase (JSON) é injetado na API por variável de ambiente/secret
do Docker — **nunca** commitado.

---

## 5. Storage de mídia (MinIO)
- Buckets: `videos`, `images`, `materials`.
- Upload pelo painel → API valida tipo/tamanho → grava no MinIO → cria `assets`.
- App recebe **URL assinada** (expira) para vídeo/imagem; vídeo servido por range-request
  (seek funciona). Fase 2 opcional: transcodificar p/ **HLS** (ffmpeg) p/ streaming adaptativo.

---

## 6. Painel Web Admin (CMS + Dashboards)

SPA (servida pela API em `/admin`, protegida por login admin). Evolução do `public/`
atual. Seções:

1. **Visão geral** — cards: usuários totais, DAU/WAU/MAU, sessões hoje, crashes 24h,
   top telas, aulas mais vistas. Gráficos de linha (uso ao longo do tempo).
2. **Aulas** — CRUD de cursos/aulas, **upload de vídeo/imagens**, editor de blocos
   (texto/imagem/vídeo/material), reordenar, publicar/despublicar; por aula:
   views, % de conclusão, tempo médio.
3. **Usuários** — lista + busca; detalhe = sessões, timeline de eventos, aulas
   concluídas, crashes do usuário, device/app version.
4. **Analytics** — explorador de eventos, breakdown por tela ("o que fazem em cada tela"),
   funil (ex.: abriu aula → assistiu → concluiu), retenção D1/D7/D30.
5. **Crashes** — lista agrupada por assinatura, nº de ocorrências, usuários/versões
   afetadas, stack trace + breadcrumbs.
6. **IA** — log de análises + ratings de feedback (migra o `/metrics` atual).

---

## 7. App Flutter — mudanças

### 7.1 Nova **primeira tela = Painel de Aulas**
- Aba `Início` vira o **Painel**: lista de cursos/aulas vindas de `GET /v1/lessons`
  (cache local em Hive para offline), com destaque, "continuar de onde parou"
  (via `lesson_progress`) e filtros por técnica/nível.
- Demais abas (Pontos, Projetos, Receitas, Você) permanecem.

### 7.2 Tela de **detalhe da aula** (conteúdo misto)
- Player de vídeo (`video_player` + `chewie`) + blocos de texto/imagem/material
  renderizados na ordem (`lesson_blocks`).
- Reporta progresso (`last_position_s`, `progress_pct`, `completed`).

### 7.3 **Auth** (Firebase)
- `firebase_core` + `firebase_auth`. Telas de login/registro/"esqueci a senha" usando
  o **Firebase SDK** (email/senha; estrutura já pronta p/ Google/Apple depois).
- O Firebase guarda a sessão e renova o ID token sozinho; um **interceptor (dio)** pega
  o token atual (`currentUser.getIdToken()`) e injeta em todo request.
- No 1º login o app chama `POST /v1/auth/sync` para criar/atualizar o usuário no Postgres.
- Onboarding atual passa a desembocar em login/registro; o go_router faz **redirect**
  para `/login` enquanto não houver `currentUser`.

### 7.4 **Telemetria** (SDK interno)
- `TelemetryService`: enfileira eventos e envia em **batch** para `/v1/events`
  (com retry/offline-buffer).
- **Auto screen tracking**: `NavigatorObserver` no go_router dispara `screen_view`
  a cada navegação → cobre "métrica em cada tela".
- Eventos custom: `lesson_play`, `lesson_complete`, `analysis_run`,
  `project_created`, `counter_used`, etc.
- **Sessões**: start/heartbeat/end via `WidgetsBindingObserver` (lifecycle).
- **Device**: registra no 1º launch (`device_info_plus` + `package_info_plus`).

### 7.5 **Crash reporting**
- `FlutterError.onError` + `PlatformDispatcher.instance.onError` +
  `runZonedGuarded` capturam erros → `POST /v1/crashes` com stack + breadcrumbs
  (últimas N telas/eventos). Buffer offline para enviar no próximo boot.

### 7.6 Novas dependências
`firebase_core`, `firebase_auth`, `video_player`, `chewie`, `dio` (interceptors),
`device_info_plus`, `package_info_plus`, `connectivity_plus`.
Config Firebase via **FlutterFire CLI** (`firebase_options.dart`); `GoogleService-Info.plist`
(iOS) e `google-services.json` (Android) **fora do git**.

---

## 8. Roadmap por fases

| Fase | Entrega | Resultado visível |
|------|---------|-------------------|
| **0 — Infra** | docker-compose (db, minio, api, migrate), schema base, health | `docker compose up` sobe tudo |
| **1 — Auth** | Projeto Firebase + `firebase_auth` no app + `/v1/auth/sync` e middleware no backend; RBAC | Usuário cria conta/loga via Firebase; espelhado no Postgres; **contagem de usuários** começa |
| **2 — Aulas** | CMS no painel (CRUD + upload) + Painel de aulas e player no app | Sobe aula no web → **aparece no app** |
| **3 — Telemetria** | SDK no app + ingestão + dashboards de uso | "O que o usuário faz em cada tela" no painel |
| **4 — Crashes** | handler no app + ingestão + dashboard de crashes | Crash no app → aparece no painel |
| **5 — IA + polish** | Migra analyses/feedback p/ DB; segurança, backups, deploy | Plataforma fechada e observável |

---

## 9. Riscos & pendências de segurança

- 🔴 **VAZAMENTO DE CHAVE**: `server/.env` com `ANTHROPIC_API_KEY` real **foi commitado
  e está no repositório remoto** (`server/.env`, 252 bytes). Ações:
  1. **Rotacionar** a API key na Anthropic (a atual deve ser considerada comprometida).
  2. Adicionar `server/.env` e `server/node_modules/` ao `.gitignore`.
  3. Remover do histórico (`git filter-repo` / BFG) e force-push, ou recriar o repo.
- `server/node_modules/` também foi commitado (peso desnecessário) — remover.
- Vídeo self-hosted cresce storage rápido → definir limite de tamanho e, se necessário, HLS.
- **Firebase Service Account** (JSON do Admin SDK) e os arquivos `google-services.json` /
  `GoogleService-Info.plist` **não podem ir pro git** — injetar via secret do Docker e
  `.gitignore`. (Mesma classe do vazamento do `.env` abaixo.)
- LGPD: telemetria com contas exige aviso de privacidade + endpoint de exclusão de dados
  (apagar no Postgres **e** no Firebase via Admin SDK).
- Custos de IA por usuário: adicionar rate-limit/quota por conta em `/v1/analyze`.

---

## 10. Próximo passo sugerido
Começar pela **Fase 0** (infra Docker + Postgres + schema base + migrations) e
**Fase 1** (auth), que destravam "salvar usuários e tudo mais". Em seguida o CMS de
aulas (Fase 2), que é o coração do pedido (subir aula no web → aparecer no app).
