# StitchMind — Crochê, Tricô & Knit

App Flutter de companhia para crochê e tricô — biblioteca de pontos, contador
de carreiras, gerenciador de projetos e receitas.

> Estado atual: **Fase 1 — UI Prototype**. Navegação e telas com mock data.

## Como rodar

```bash
flutter create . --project-name stitchmind --platforms=ios,android
flutter pub get
flutter run
```

> O `flutter create` em cima do projeto existente vai gerar os arquivos
> nativos (`ios/`, `android/`, etc.) sem sobrescrever o `lib/` nem o
> `pubspec.yaml`. Confirme antes de aceitar mudanças no `pubspec.yaml`.

## Fontes

Coloque os arquivos `.ttf` em `assets/fonts/`:

- `Fraunces-Regular.ttf`, `Fraunces-Medium.ttf`, `Fraunces-SemiBold.ttf`,
  `Fraunces-Bold.ttf` (Google Fonts)
- `Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-SemiBold.ttf`
  (Google Fonts)

Sem elas, o Flutter cai no fallback do sistema — funciona, mas perde a
identidade editorial planejada.

## Estrutura

```
lib/
├── main.dart                       # bootstrap + ProviderScope
├── app.dart                        # MaterialApp.router
├── core/
│   ├── theme/                      # AppColors, AppTheme
│   └── router/                     # go_router config
├── domain/entities/                # Stitch, Project, Pattern
├── data/mock/                      # MockData (pontos, projetos, receitas)
└── presentation/
    ├── main_shell.dart             # bottom nav
    ├── pages/                      # home, stitches, projects, counter,
    │                               # patterns, profile
    └── widgets/                    # YarnSwatch, SectionHeader
```

## Próximas fases

Ver [PLAN.md](PLAN.md) — milestones 2 a 7 (persistência Hive, contador
real com haptics, seed de pontos, modo "seguir receita", polimento,
build TestFlight).
# stitchmind
