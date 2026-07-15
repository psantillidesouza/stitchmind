import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/lesson.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/gradient_bg.dart';
import '../../widgets/lesson_feedback_sheet.dart';

/// Aba "Vídeo" da aula: vídeo colado no topo, descrição, chips com os
/// títulos, barra de progresso com tempos e controles (mute, ±5s, play
/// grande, velocidade).
class LessonVideosPage extends StatefulWidget {
  const LessonVideosPage({
    required this.lesson,
    required this.videos,
    super.key,
  });

  final Lesson lesson;
  final List<LessonBlock> videos; // blocos type == 'video', já ordenados

  @override
  State<LessonVideosPage> createState() => _LessonVideosPageState();
}

class _LessonVideosPageState extends State<LessonVideosPage> {
  VideoPlayerController? _v;
  int _current = 0;
  bool _error = false;
  bool _switching = false;
  bool _introDone = false; // loading só sai da tela ao chegar em 100%
  bool _muted = false;
  final _speeds = const [1.0, 1.5, 2.0];
  int _speedIdx = 0;
  int _loadSeq = 0; // invalida carregamentos antigos em toques rápidos

  final _chipsCtrl = ScrollController();
  final _chipKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    // O primeiro vídeo carrega em background durante o loading e
    // entra PAUSADO na tela do player.
    _load(0, autoplay: false);
  }

  /// Troca de vídeo sem piscar: o player atual continua na tela enquanto o
  /// próximo inicializa em segundo plano; no final há um único swap.
  Future<void> _load(int index, {bool autoplay = true}) async {
    final seq = ++_loadSeq;
    setState(() {
      _current = index;
      _switching = true;
      _error = false;
    });
    _v?.pause();
    _scrollChipIntoView(index);

    final url = widget.videos[index].url;
    if (url == null || url.isEmpty) {
      setState(() {
        _error = true;
        _switching = false;
      });
      return;
    }

    final next = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await next.initialize();
    } catch (_) {
      next.dispose();
      if (mounted && seq == _loadSeq) {
        setState(() {
          _error = true;
          _switching = false;
        });
      }
      return;
    }
    // Se a tela fechou ou o usuário já tocou em outro título, descarta.
    if (!mounted || seq != _loadSeq) {
      next.dispose();
      return;
    }

    final old = _v;
    next.addListener(_onTick);
    // Mantém as preferências atuais no vídeo novo.
    await next.setVolume(_muted ? 0 : 1);
    await next.setPlaybackSpeed(_speeds[_speedIdx]);
    setState(() {
      _v = next;
      _switching = false;
    });
    old?.removeListener(_onTick);
    old?.dispose();
    if (autoplay) await next.play();
  }

  void _scrollChipIntoView(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _chipKeys[index]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            alignment: 0.15,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  Future<void> _skip(int seconds) async {
    final v = _v;
    if (v == null || !v.value.isInitialized) return;
    var t = v.value.position + Duration(seconds: seconds);
    if (t < Duration.zero) t = Duration.zero;
    if (v.value.duration > Duration.zero && t > v.value.duration) {
      t = v.value.duration;
    }
    await v.seekTo(t);
  }

  void _togglePlay() {
    final v = _v;
    if (v == null || !v.value.isInitialized) return;
    v.value.isPlaying ? v.pause() : v.play();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _v?.setVolume(_muted ? 0 : 1);
  }

  void _cycleSpeed() {
    setState(() => _speedIdx = (_speedIdx + 1) % _speeds.length);
    _v?.setPlaybackSpeed(_speeds[_speedIdx]);
  }

  @override
  void dispose() {
    _chipsCtrl.dispose();
    _v?.removeListener(_onTick);
    _v?.dispose();
    super.dispose();
  }

  String _titleOf(int i) {
    final t = widget.videos[i].videoTitle;
    return t.isNotEmpty
        ? t
        : context.l10n.tr('lesson_video_n', {'n': '${i + 1}'});
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return "$m:${s.toString().padLeft(2, '0')}";
  }

  void _openFeedback() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LessonFeedbackSheet(lesson: widget.lesson),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = _v;
    final playing = v != null && v.value.isInitialized && v.value.isPlaying;

    // Tela de "Preparando seu tutorial…": fica até o loading chegar a 100%
    // E o vídeo estar pronto (carregando em background nesse meio-tempo).
    if (!_error && (v == null || !_introDone)) {
      return _VideoLoadingScreen(
        coverUrl: widget.lesson.coverUrl,
        onComplete: () => setState(() => _introDone = true),
      );
    }

    final topPad = MediaQuery.of(context).padding.top;
    final desc = _error ? '' : widget.videos[_current].videoDescription;
    final pos = v != null && v.value.isInitialized ? v.value.position : Duration.zero;
    final dur = v != null && v.value.isInitialized ? v.value.duration : Duration.zero;
    final remaining = dur > pos ? dur - pos : Duration.zero;

    return GradientBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Vídeo no centro, ocupando o meio da tela, com degradê
            // branco em cima (em direção aos botões) e embaixo (em direção
            // aos chips/controles).
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_error)
                    Container(
                      color: AppColors.card,
                      alignment: Alignment.center,
                      padding: EdgeInsets.only(top: topPad),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 42, color: AppColors.coral),
                          const SizedBox(height: 10),
                          Text(context.l10n.tr('lesson_video_error'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge),
                        ],
                      ),
                    )
                  else if (v != null)
                    GestureDetector(
                      onTap: _togglePlay,
                      // Topo maior desce o vídeo na tela; o recuo de 2px na
                      // base evita a textura "vazar" 1px do recorte em alguns
                      // aparelhos (vazamento cai na faixa branca do degradê).
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40, bottom: 2),
                        // O degradê fica DENTRO da área do vídeo, então
                        // acompanha o posicionamento dele: fade branco na
                        // borda de cima e na de baixo do próprio vídeo.
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRect(
                              child: FittedBox(
                                fit: BoxFit.cover,
                                clipBehavior: Clip.hardEdge,
                                child: SizedBox(
                                  width: v.value.size.width > 0
                                      ? v.value.size.width
                                      : 16,
                                  height: v.value.size.height > 0
                                      ? v.value.size.height
                                      : 9,
                                  child: VideoPlayer(v),
                                ),
                              ),
                            ),
                            const IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  // Fecha no branco antes das bordas pra
                                  // cobrir qualquer fresta do recorte.
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: [0.0, 0.2, 0.78, 0.98],
                                    colors: [
                                      AppColors.background,
                                      Colors.transparent,
                                      Colors.transparent,
                                      AppColors.background,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Véu de carregamento na troca de vídeo.
                  AnimatedOpacity(
                    opacity: _switching ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      child: Container(
                        color: Colors.black26,
                        child: const Center(
                          child: SizedBox(
                            width: 34,
                            height: 34,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Voltar (esq.) e Feedback (dir.) por cima do vídeo.
                  Positioned(
                    top: topPad + 8,
                    left: 16,
                    child: _RoundIconBtn(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Positioned(
                    top: topPad + 8,
                    right: 16,
                    child: Material(
                      color: AppColors.paper.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(24),
                      elevation: 2,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: _openFeedback,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.headset_mic_rounded,
                                  size: 19, color: AppColors.walnut),
                              const SizedBox(width: 8),
                              Text(
                                context.l10n.tr('lesson_video_feedback'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.walnut,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Descrição do vídeo atual (se cadastrada no painel) ──
            if (desc.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 110),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                  child: Text(
                    desc,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(height: 1.45),
                  ),
                ),
              ),

            // ── Chips com os títulos dos vídeos ──
            SizedBox(
              height: 46,
              child: ListView.separated(
                controller: _chipsCtrl,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: widget.videos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final sel = i == _current;
                  return Center(
                    key: _chipKeys.putIfAbsent(i, GlobalKey.new),
                    child: Material(
                      color: sel ? AppColors.coralSoft : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () {
                          if (i != _current) _load(i);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 9),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: sel ? AppColors.coral : AppColors.linen,
                              width: sel ? 1.4 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (sel) ...[
                                const Icon(Icons.bar_chart_rounded,
                                    size: 15, color: AppColors.coral),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                _titleOf(i),
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: sel
                                      ? AppColors.coral
                                      : AppColors.walnutSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // ── Barra de progresso + tempos ──
            if (v != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: VideoProgressIndicator(
                    v,
                    allowScrubbing: true,
                    padding: EdgeInsets.zero,
                    colors: const VideoProgressColors(
                      playedColor: AppColors.coral,
                      bufferedColor: AppColors.linen,
                      backgroundColor: AppColors.linen,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(pos), style: _timeStyle),
                    Text('-${_fmt(remaining)}', style: _timeStyle),
                  ],
                ),
              ),

              // ── Controles: mute | -5s | play | +5s | velocidade ──
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 10, 28, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _FlatIconBtn(
                      icon: _muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      onTap: _toggleMute,
                    ),
                    _FlatIconBtn(
                      icon: Icons.replay_5_rounded,
                      onTap: () => _skip(-5),
                    ),
                    // Play/pause grande coral no centro.
                    Material(
                      color: AppColors.coral,
                      shape: const CircleBorder(),
                      elevation: 3,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _togglePlay,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    _FlatIconBtn(
                      icon: Icons.forward_5_rounded,
                      onTap: () => _skip(5),
                    ),
                    // Velocidade (1x → 1.5x → 2x)
                    InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: _cycleSpeed,
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.walnut, width: 1.6),
                        ),
                        child: Text(
                          _speeds[_speedIdx] == 1.0
                              ? '1x'
                              : _speeds[_speedIdx] == 1.5
                                  ? '1.5x'
                                  : '2x',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.walnut,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  static const _timeStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.walnutMuted,
  );
}

// Ícone "flat" dos controles (sem fundo).
class _FlatIconBtn extends StatelessWidget {
  const _FlatIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 30, color: AppColors.walnut),
      ),
    );
  }
}

// Botão redondo claro (voltar) sobre o vídeo.
class _RoundIconBtn extends StatelessWidget {
  const _RoundIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paper.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, size: 18, color: AppColors.walnut),
        ),
      ),
    );
  }
}

// ─── Tela de loading: thumb da aula + novelo andando na linha ───────
class _VideoLoadingScreen extends StatefulWidget {
  const _VideoLoadingScreen({required this.onComplete, this.coverUrl});
  final String? coverUrl;
  final VoidCallback onComplete; // chamado quando o progresso chega a 100%

  @override
  State<_VideoLoadingScreen> createState() => _VideoLoadingScreenState();
}

class _VideoLoadingScreenState extends State<_VideoLoadingScreen>
    with TickerProviderStateMixin {
  // Progresso cenográfico com duração fixa: SEMPRE vai até 100%, enquanto
  // o vídeo real carrega em background.
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onComplete();
    })
    ..forward();
  late final Animation<double> _p =
      CurvedAnimation(parent: _progress, curve: Curves.easeOutCubic);

  // Sobe-e-desce da ilustração (fallback sem thumb).
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _progress.dispose();
    _bob.dispose();
    super.dispose();
  }

  Widget _bobbingIllustration() {
    // Tenta empty.png → premium.png → chat.png (a que existir).
    Widget img(String name, Widget Function() fallback) => Image.asset(
          'assets/illustrations/$name',
          height: 180,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => fallback(),
        );
    return AnimatedBuilder(
      animation: _bob,
      builder: (_, child) {
        final t = Curves.easeInOut.transform(_bob.value);
        return Transform.translate(offset: Offset(0, -12 + 24 * t), child: child);
      },
      child: img('empty.png',
          () => img('premium.png', () => img('chat.png', SizedBox.shrink))),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = AppColors.background; // mesmo fundo do GradientBg
    final hasCover = (widget.coverUrl ?? '').isNotEmpty;

    return GradientBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Column(
              children: [
                // ── Topo: thumb da aula com fade, ou ilustração flutuando ──
                Expanded(
                  flex: 11,
                  child: hasCover
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              widget.coverUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Align(
                                  alignment: const Alignment(0, 0.7),
                                  child: _bobbingIllustration()),
                            ),
                            // Fade da foto pro fundo da tela.
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: [0.55, 1.0],
                                  colors: [Colors.transparent, bg],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Align(
                          alignment: const Alignment(0, 0.7),
                          child: _bobbingIllustration()),
                ),

                // ── Base: texto + linha ondulada com novelo + % ──
                Expanded(
                  flex: 8,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.tr('lesson_video_loading'),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 28),
                        AnimatedBuilder(
                          animation: _p,
                          builder: (_, __) {
                            final p = _p.value;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _YarnWave(progress: p),
                                const SizedBox(height: 14),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '${(p * 100).round()}%',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.walnutMuted,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Botão voltar por cima de tudo.
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              child: Material(
                color: AppColors.paper,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: AppColors.walnut),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Linha ondulada com o novelo 🧶 marcando o progresso ────────────
class _YarnWave extends StatelessWidget {
  const _YarnWave({required this.progress});
  final double progress; // 0..1

  static const _amplitude = 8.0;
  static const _height = 48.0;

  double _yAt(double x, double width) =>
      _height / 2 + _amplitude * math.sin(2 * math.pi * x / (width / 2.2));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final w = c.maxWidth;
        final x = (progress * w).clamp(0.0, w);
        return SizedBox(
          height: _height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                size: Size(w, _height),
                painter: _YarnWavePainter(progress: progress),
              ),
              Positioned(
                left: x - 16,
                top: _yAt(x, w) - 16,
                child: const Text('🧶', style: TextStyle(fontSize: 26)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _YarnWavePainter extends CustomPainter {
  _YarnWavePainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, _YarnWave._height / 2);
    for (double x = 0; x <= size.width; x += 2) {
      path.lineTo(
          x,
          _YarnWave._height / 2 +
              _YarnWave._amplitude *
                  math.sin(2 * math.pi * x / (size.width / 2.2)));
    }

    final done = Paint()
      ..color = AppColors.coral
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final todo = Paint()
      ..color = AppColors.linen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Divide o traçado no ponto do progresso: coral atrás, cinza na frente.
    for (final metric in path.computeMetrics()) {
      final cut = metric.length * progress.clamp(0.0, 1.0);
      canvas.drawPath(metric.extractPath(0, cut), done);
      canvas.drawPath(metric.extractPath(cut, metric.length), todo);
    }
  }

  @override
  bool shouldRepaint(_YarnWavePainter old) => old.progress != progress;
}
