# Plano da Comunidade — StitchMind

> Decisões tomadas: **pós-moderação + denúncia/bloqueio**; escopo **completo (Fases 1+2+3)**.
> Backend único = **Bun** (`server/`). Identidade real = **Firebase**. O feed é **UGC** → exige moderação para passar na App Store (Apple Guideline 1.2).

---

## 0. Diagnóstico (estado atual)

A comunidade hoje só aparece na **home** (`lib/presentation/pages/inicio/inicio_page.dart`): carrossel de dicas + feed de fotos + publicar.

O app aponta feed/publicar/curtir para um backend **Fastify que não existe mais** → tudo retorna 404 em produção. Só as dicas (`/v1/tips`, Bun) funcionam.

O Bun **já tem** a comunidade certa e autenticada (`server/src/routes/community.ts`): `GET /v1/posts`, `POST /v1/posts` (multipart), `POST /v1/posts/:id/like` (toggle), + moderação no admin. O app só não está ligado nela; os formatos divergem.

**Conclusão:** reconectar o app no Bun e matar o caminho Fastify/`dev-login`, depois empilhar segurança e engajamento.

---

## 1. Fase 1 — Reconectar e funcionar (app-side; backend já pronto)

### App (`lib/`)
- **Reescrever** `data/repositories/community_repository.dart` para usar o `ApiClient` (Bun, com token Firebase).
- **Apagar** `data/services/core_api_client.dart`, `coreApiClientProvider` (`presentation/providers/platform_providers.dart`) e `coreUrl` (`core/config/server_config.dart`).
- Alinhar parsing de `Post` ao formato do Bun: `{posts:[...]}`, campos `likes`, `liked`, `author`, `author_photo`, `created_at`. Incluir `user_id` do autor (para bloquear/perfil/apagar-meu).
- `publish()` → **um** multipart `POST /v1/posts` (campo `image` + `caption`). Estender `ApiClient.postFile` para aceitar campos extras (caption).
- `toggleLike()` → ler `{liked}` da resposta e atualizar a UI **otimisticamente** (com rollback em erro).
- Empty state real no feed ("seja a primeira a publicar").

### Backend
- Nada novo para funcionar. **Melhoria:** corrigir `posts.likes_count` denormalizado com trigger (ver migração na Fase 2).

---

## 2. Fase 2 — Segurança e conformidade de loja

### Migração `server/db/migrations/016_community_safety.sql`
```sql
-- denúncias
CREATE TABLE post_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  reporter_id uuid REFERENCES users(id) ON DELETE SET NULL,
  reason text NOT NULL CHECK (reason IN ('spam','offensive','nudity','harassment','other')),
  note text,
  created_at timestamptz DEFAULT now(),
  UNIQUE (post_id, reporter_id)        -- 1 denúncia por usuário por post
);
CREATE INDEX idx_post_reports_post ON post_reports(post_id);

-- bloqueio entre usuários
CREATE TABLE user_blocks (
  blocker_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id)
);

-- soft delete do post (estende o CHECK existente)
ALTER TABLE posts DROP CONSTRAINT IF EXISTS posts_status_check;
ALTER TABLE posts ADD CONSTRAINT posts_status_check
  CHECK (status IN ('pending','approved','hidden','deleted'));

-- corrige likes_count (denormalizado) com trigger
CREATE OR REPLACE FUNCTION sync_likes_count() RETURNS trigger AS $$
BEGIN
  UPDATE posts SET likes_count = (SELECT count(*) FROM post_likes WHERE post_id =
    COALESCE(NEW.post_id, OLD.post_id)) WHERE id = COALESCE(NEW.post_id, OLD.post_id);
  RETURN NULL;
END; $$ LANGUAGE plpgsql;
CREATE TRIGGER trg_likes_count AFTER INSERT OR DELETE ON post_likes
  FOR EACH ROW EXECUTE FUNCTION sync_likes_count();
```

### Rotas novas (`server/src/routes/community.ts`)
| Método | Rota | Auth | O quê |
|---|---|---|---|
| POST | `/v1/posts/:id/report` | requireAuth | grava denúncia; se ≥ **3** denúncias distintas e `status='approved'` → vira `hidden` + `pushLiveEvent` p/ admin |
| DELETE | `/v1/posts/:id` | requireAuth | autor apaga o próprio (`status='deleted'`); senão 403 |
| POST/DELETE | `/v1/users/:id/block` | requireAuth | bloquear/desbloquear |
| GET | `/v1/posts` | optionalAuth | passa a **excluir** autores bloqueados pelo viewer + paginação (ver Fase 3) |

Rate-limit (anti-spam) por usuário em `POST /posts` e `POST /posts/:id/report`.

### Admin (`server/src/routes/admin.ts`)
- `GET /admin/reports` → posts denunciados agrupados (contagem, motivos, status).
- Reaproveitar `/admin/posts` (aprovar/ocultar/excluir) para resolver denúncias.

### App (`lib/`)
- Menu **⋯** em cada post: **Denunciar** (motivos), **Bloquear autor**, **Apagar** (se for meu).
- Esconder posts de autores bloqueados.
- **Aceite de diretrizes de conteúdo/EULA** antes da 1ª publicação (exigência Apple). Guardar flag em `shared_preferences` + termo no backend.
- Links de Termos/Privacidade já existem (`paywall`/perfil) — reaproveitar.

---

## 3. Fase 3 — Engajamento

### Migração `server/db/migrations/017_community_social.sql`
```sql
CREATE TABLE post_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  body text NOT NULL,
  status text DEFAULT 'visible' CHECK (status IN ('visible','hidden','deleted')),
  created_at timestamptz DEFAULT now()
);
CREATE INDEX idx_comments_post ON post_comments(post_id, created_at);
ALTER TABLE posts ADD COLUMN comments_count integer DEFAULT 0;

CREATE TABLE follows (
  follower_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  followee_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (follower_id, followee_id)
);
```

### Rotas novas
| Método | Rota | Auth | O quê |
|---|---|---|---|
| GET | `/v1/posts?cursor=<iso>&limit=20` | optionalAuth | **paginação** (cursor por `created_at`) — hoje é `LIMIT 60` fixo |
| GET | `/v1/posts/:id/comments` | optionalAuth | lista comentários |
| POST | `/v1/posts/:id/comments` | requireAuth | comenta (rate-limit) |
| DELETE | `/v1/comments/:id` | requireAuth | apaga próprio comentário |
| POST/DELETE | `/v1/users/:id/follow` | requireAuth | seguir/parar |
| GET | `/v1/users/:id/profile` | optionalAuth | dados públicos + posts do autor |

### Push (FCM — infra já existe em `server/src/push/`)
- Notificar autor ao receber **curtida/comentário** (se tiver token e não for ele mesmo).

### App
- **Tela dedicada de Comunidade** (`lib/presentation/pages/community/`) no shell de navegação, em vez de espremida na home; manter um *teaser* (últimos N) na home reusando o mesmo provider.
- **Detalhe do post** com comentários (sheet), **scroll infinito** (provider paginado / `Notifier`).
- **Perfil leve** (toque no autor → grade de posts) e botão **Seguir**.
- Entidades novas: `Comment`, `Profile`; estender `Post` com `userId`, `commentsCount`, `createdAt`.

---

## 4. Ordem de execução (backend antes, app depois)

1. **Backend Fase 2** (migração 016 + rotas report/block/delete + trigger likes) → deploy. *Compatível: o app antigo continua quebrado igual, nada piora.*
2. **Backend Fase 3** (migração 017 + comentários/follows/perfil/paginação/push) → deploy.
3. **App** (reescrita do repositório p/ Bun + remoção do Fastify + telas novas + moderação + gate de diretrizes).
4. QA end-to-end → **nova versão na loja**.

> Importante: tudo de app só chega ao usuário via **release na loja**. O backend pode ir primeiro (é retrocompatível).

---

## 5. Checklist de conformidade (App Store / Play — UGC)
- [x] Denunciar conteúdo (`/posts/:id/report`)
- [x] Bloquear usuário (`/users/:id/block`)
- [x] Apagar o próprio conteúdo (`DELETE /posts/:id`)
- [x] Moderação + remoção em tempo hábil (auto-hide ≥3 denúncias + fila no admin)
- [x] Aceite de diretrizes/EULA antes de publicar
- [x] Contato/Termos/Privacidade (páginas já existem)

---

## 6. Riscos & notas
- **Feed vazio no lançamento** → semear alguns posts iniciais ou empty state convidativo.
- **Carga operacional de moderação** → auto-hide por limite + fila no admin reduzem trabalho manual.
- **`likes_count`** passa a ser mantido por trigger (fim do drift).
- App-side só chega via loja; planejar a build/submissão junto.
