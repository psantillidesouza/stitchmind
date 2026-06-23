# StitchMind — Crochê, Tricô & Knit

> App companheiro para quem faz crochê e tricô. Inspirado no fluxo do YarnPal, mas com identidade própria: editorial, artesanal, calorosa.

---

## 1. Visão

**Uma frase:** _O app que te acompanha do primeiro fio à última carreira — biblioteca de pontos, contador inteligente, gerenciador de projetos e receitas, tudo num só lugar._

**Tom:** artesanal, acolhedor, sem infantilização. Tipografia editorial + paleta de lã natural. Não parece app de produtividade.

**Idiomas:** PT-BR (principal), EN, ES (futuro).

---

## 2. Público

- Iniciantes que estão aprendendo pontos e precisam de visualização clara.
- Intermediários que querem organizar projetos paralelos e não perder a conta.
- Avançados que querem catalogar receitas próprias e compartilhar.

Diferenciais vs. YarnPal:
- UI editorial / "soft skill" (lã, papel, sépia) em vez de visual genérico de app.
- Modo crochê **e** tricô no mesmo app, com troca contextual.
- Contador de carreiras com **gestos** (tap em qualquer lugar, shake para desfazer).
- Modo "mãos ocupadas": comando de voz para incrementar carreira.
- Biblioteca de pontos com **vídeo + diagrama + abreviação PT/EN** lado a lado.

---

## 3. Features (MVP — tudo)

### 3.1 Biblioteca de Pontos (Stitches)
- Catálogo de pontos de crochê e tricô.
- Cada ponto: nome PT/EN, abreviação, dificuldade, vídeo curto (loop), diagrama, descrição passo-a-passo.
- Filtros: técnica (crochê/tricô), dificuldade, categoria (base, textura, decorativo).
- Favoritar pontos.

### 3.2 Contador de Carreiras (Row Counter)
- Múltiplos contadores nomeados, salvos por projeto.
- Tap grande na tela inteira incrementa; long-press decrementa.
- Marcadores (markers) intermediários: "diminuir nas carreiras 12, 18, 24".
- Som / vibração / haptic feedback configurável.
- Mantém tela acesa enquanto ativo.

### 3.3 Projetos (Projects)
- Lista de projetos em andamento, pausados e concluídos.
- Cada projeto: nome, foto de capa, técnica, linha (marca/cor/peso), agulha, data de início, progresso (%), notas, fotos.
- Linkado ao contador e à receita (opcional).
- Linha do tempo: foto a cada N carreiras.

### 3.4 Receitas (Patterns)
- Biblioteca de receitas (próprias e da comunidade futuramente).
- Receita = sequência de seções (cabeça, corpo, braço…) com pontos e contagens.
- Modo "seguir receita": destaca a carreira atual, marca conclusão.
- Estimativa de linha necessária e tempo médio.
- Importar de PDF (futuro) / colar texto e parsear (V1.5).

### 3.5 Perfil / Configurações
- Tema claro/escuro, idioma, unidades (cm/in), tamanho de agulha (mm/US).
- Backup local (Hive) + export JSON.
- Conta opcional para sincronizar (V2).

---

## 4. Arquitetura

Seguindo o padrão do projeto **mamaco**: Clean Architecture + Riverpod + Hive + go_router.

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── theme/          # AppTheme, cores, tipografia
│   ├── router/         # go_router config
│   ├── constants/      # strings, dimensões
│   ├── extensions/     # BuildContext, DateTime helpers
│   ├── utils/          # formatters, validators
│   └── errors/         # Failure types, error presenter
├── domain/
│   ├── entities/       # Stitch, Project, Pattern, RowCounter
│   ├── repositories/   # interfaces
│   └── usecases/       # IncrementRow, CreateProject…
├── data/
│   ├── models/         # Hive adapters
│   ├── datasources/    # local (Hive), remote (futuro)
│   └── repositories/   # implementações
└── presentation/
    ├── pages/
    │   ├── home/
    │   ├── stitches/
    │   ├── counter/
    │   ├── projects/
    │   ├── patterns/
    │   └── profile/
    ├── widgets/        # componentes compartilhados
    ├── providers/      # Riverpod providers
    └── main_shell.dart # bottom nav
```

---

## 5. Modelo de Dados (esboço)

```dart
class Stitch {
  String id;
  String namePt;
  String nameEn;
  String abbrev;          // ex: "pa", "dc"
  StitchTechnique tech;   // crochet | knit
  Difficulty difficulty;  // beginner | intermediate | advanced
  List<String> categories;
  String videoPath;
  String diagramPath;
  String description;
}

class Project {
  String id;
  String name;
  String coverPath;
  StitchTechnique tech;
  Yarn yarn;              // brand, color, weight
  Needle needle;
  DateTime startedAt;
  DateTime? finishedAt;
  ProjectStatus status;
  String? patternId;
  List<String> photoPaths;
  String notes;
}

class RowCounter {
  String id;
  String projectId;
  String label;
  int current;
  int? target;
  List<Marker> markers;
}

class Marker {
  int row;
  String note;
  bool reached;
}

class Pattern {
  String id;
  String name;
  String authorName;
  String coverPath;
  StitchTechnique tech;
  Difficulty difficulty;
  List<PatternSection> sections;
  YarnRequirement yarn;
  Duration estimatedTime;
}
```

Persistência: **Hive** (mesmos adapters do mamaco). Receitas pré-populadas via JSON seed em `assets/data/`.

---

## 6. Design System — "Soft Wool Editorial"

### Paleta
| Token | Hex | Uso |
|---|---|---|
| `cream` | `#F7F1E7` | background principal |
| `paper` | `#FAF6F0` | superfície de cards |
| `walnut` | `#3E2A1F` | texto primário |
| `walnut-soft` | `#6B5544` | texto secundário |
| `terracotta` | `#C75D3C` | accent / CTAs |
| `terracotta-deep` | `#9D4225` | hover / pressed |
| `sage` | `#7C9A6A` | sucesso / progresso |
| `linen` | `#E8DCC9` | divisores / chips |
| `ink` | `#1F1610` | overlays escuros |

### Tipografia
- **Headings:** `Fraunces` (serif editorial, soft optical)
- **Body:** `Inter` (sans-serif legível)
- **Numerals (contador):** `Fraunces` tabular, peso 600

Escala: 12 / 14 / 16 / 20 / 28 / 40 / 64 (contador).

### Espaçamento
Base 4: 4 / 8 / 12 / 16 / 24 / 32 / 48 / 64.

### Forma
- Cards: radius 16, sem sombra pesada — borda 1px `linen`.
- Botões primários: radius 12, peso 500, padding 16x24.
- Imagens: radius 8 (cantos suaves).

### Princípios
1. **Espaço respira.** Padding generoso, never apertado.
2. **Cor com economia.** Terracotta só em CTA e estados ativos.
3. **Tipo conta a história.** Headings grandes em serif. Sem all-caps gratuito.
4. **Sem ícone genérico de Material.** Iconografia line-only, peso 1.5px, custom set.
5. **Microinterações táteis.** Haptic em incremento de carreira, animação suave em transições (200-280ms, easeOutCubic).

---

## 7. Telas (MVP)

| # | Rota | Tela | Estado |
|---|---|---|---|
| 1 | `/` | Home (dashboard) | Protótipo |
| 2 | `/stitches` | Biblioteca de pontos | Protótipo |
| 3 | `/stitches/:id` | Detalhe de ponto | Protótipo |
| 4 | `/projects` | Lista de projetos | Protótipo |
| 5 | `/projects/:id` | Detalhe de projeto | Protótipo |
| 6 | `/projects/new` | Criar projeto | Backlog |
| 7 | `/counter/:id` | Contador ativo | Protótipo |
| 8 | `/patterns` | Receitas | Protótipo |
| 9 | `/patterns/:id` | Detalhe de receita | Backlog |
| 10 | `/profile` | Perfil & ajustes | Protótipo |

Bottom nav (5 itens): Home · Pontos · Contador · Projetos · Receitas.

---

## 8. Milestones

| Fase | Entregável | Duração est. |
|---|---|---|
| **0. Setup** | Projeto Flutter, theme, router, bottom nav | meio dia |
| **1. UI Prototype** ⬅ _aqui_ | 5 telas principais navegáveis com mock data | 1 dia |
| **2. Persistência** | Hive adapters, repositórios, CRUD de projetos | 2 dias |
| **3. Contador real** | Lógica do contador, markers, haptics, keep awake | 1 dia |
| **4. Biblioteca de pontos** | Seed de 30+ pontos PT/EN, player de vídeo, filtros | 3 dias |
| **5. Receitas** | Modelo de receita, modo "seguir", linkagem com contador | 3 dias |
| **6. Polimento** | Animações, onboarding, vazios, erros, splash | 2 dias |
| **7. Beta TestFlight** | Build iOS, ícone, screenshots, App Store Connect | 1 dia |

Total MVP: **~2 semanas** de foco.

---

## 9. Stack

- Flutter 3.24+ / Dart 3.5+
- `flutter_riverpod`, `freezed`, `hive`, `go_router`, `intl`
- `video_player` para vídeos curtos de pontos
- `wakelock_plus` para manter tela acesa no contador
- `flutter_haptic_feedback` (ou `HapticFeedback` nativo)
- `share_plus`, `image_picker`, `path_provider`

---

## 10. Decisões em aberto

- [ ] Vídeos de pontos: bundle no app (peso) ou stream de CDN?
- [ ] Conta de usuário: skip no MVP (só local) ou já entrar com Sign in with Apple?
- [ ] Monetização: paywall pós-onboarding (ex: 5 projetos free) ou tudo grátis no V1?
- [ ] Ícone do app: encomendar ou gerar?
