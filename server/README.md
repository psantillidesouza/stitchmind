# StitchMind — Backend & Painel

Plataforma self-hosted: **Bun + Hono** (API), **Postgres** (dados), **MinIO** (mídia),
**painel admin** web. Tudo orquestrado por **Docker Compose**.

## Subir tudo (Docker)

```bash
cd server
cp .env.example .env        # ajuste ANTHROPIC_API_KEY etc.
docker compose up -d --build
```

Sobe: `db` (Postgres), `storage` (MinIO + buckets), `api` (Bun) — que roda as
**migrations** automaticamente no boot. Depois:

- **Painel admin:** http://localhost:8000/admin
  - Token de dev (campo na barra lateral): `dev:dev-admin:admin@stitchmind.local`
- **Health:** http://localhost:8000/health
- **MinIO console:** http://localhost:9001 (user/pass do `.env`)

## Rodar a API sem Docker (dev)

```bash
cd server
bun install
# precisa de um Postgres acessível em DATABASE_URL
DATABASE_URL=postgres://stitchmind:stitchmind@localhost:5432/stitchmind bun run dev
```

## Autenticação

- **Produção:** Firebase Auth. Defina `FIREBASE_PROJECT_ID` e `AUTH_DEV_MODE=false`.
  A API valida o **ID token** do Firebase (Bearer) e espelha o usuário no Postgres.
- **Dev:** com `AUTH_DEV_MODE=true`, aceita tokens `dev:<uid>:<email>` — sem precisar
  de Firebase real. O app usa isso por padrão (`DevAuthService`).

## Mapa de endpoints (`/v1`)

| Grupo | Endpoints |
|-------|-----------|
| Auth | `POST /auth/sync`, `GET /auth/me` |
| Aulas (app) | `GET /courses`, `GET /lessons`, `GET /lessons/:slug`, `POST /lessons/:id/progress` |
| Telemetria | `POST /devices/register`, `POST /sessions/start\|end`, `POST /events` |
| Crashes | `POST /crashes` |
| IA | `POST /analyze`, `POST /feedback` (também sem `/v1`, p/ compat) |
| Admin | `GET /admin/overview\|users\|analytics/*\|crashes`, CRUD `/admin/courses\|lessons\|blocks`, `POST /admin/assets` |

## Banco

Schema em `db/migrations/*.sql` (versionado, idempotente). Tabelas principais:
`users`, `devices`, `app_sessions`, `courses`, `lessons`, `lesson_blocks`, `assets`,
`lesson_progress`, `events`, `crashes`, `analyses`, `feedback`.

## Storage

MinIO com buckets `videos`, `images`, `materials`. Upload via painel
(`POST /admin/assets`); o app recebe **URLs assinadas** (temporárias).

## App Flutter ↔ backend

- URL padrão: `http://localhost:8000` (simulador iOS/web). Android emulador: `10.0.2.2:8000`.
  Device físico: **Perfil → URL do servidor** com o IP da máquina.
- O app registra device, abre sessão, faz auto `screen_view` em cada navegação,
  reporta crashes e busca as aulas publicadas — tudo aparece no painel.
