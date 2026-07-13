import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/lesson.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/gradient_bg.dart';

/// Aba "Vídeo" da aula: vários vídeos ordenados no painel, com os títulos
/// em linha (chips). O selecionado toca no centro, com pause e ±5s.
class LessonVideosPage extends StatefulWidget {
  const LessonVideosPage({
    required this.lessonTitle,
    required this.videos,
    super.key,
  });

  final String lessonTitle;
  final List<LessonBlock> videos; // blocos type == 'video', já ordenados

  @override
  State<LessonVideosPage> createState() => _LessonVideosPageState();
}

class _LessonVideosPageState extends State<LessonVideosPage> {
  VideoPlayerController? _v;
  int _current = 0;
  bool _error = false;
  bool _switching = false;
  int _loadSeq = 0; // invalida carregamentos antigos em toques rápidos

  @override
  void initState() {
    super.initState();
    _load(0);
  }

  /// Troca de vídeo sem piscar: o player atual continua na tela enquanto o
  /// próximo inicializa em segundo plano; no final há um único swap.
  Future<void> _load(int index) async {
    final seq = ++_loadSeq;
    setState(() {
      _current = index;
      _switching = true;
      _error = false;
    });
    _v?.pause();

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
    setState(() {
      _v = next;
      _switching = false;
    });
    old?.removeListener(_onTick);
    old?.dispose();
    await next.play();
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

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final v = _v;
    final playing = v != null && v.value.isInitialized && v.value.isPlaying;

    return GradientBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // ── Cabeçalho: voltar + título da aula ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 24, 0),
                child: Row(
                  children: [
                    Material(
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
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.l10n.tr('lesson_cta_video'),
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                          Text(widget.lessonTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Vídeo no centro ──
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _error
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  size: 42, color: AppColors.coral),
                              const SizedBox(height: 10),
                              Text(context.l10n.tr('lesson_video_error'),
                                  textAlign: TextAlign.center,
                                  style:
                                      Theme.of(context).textTheme.bodyLarge),
                            ],
                          )
                        : v == null
                            // Só no primeiro carregamento (sem vídeo na tela).
                            ? const CircularProgressIndicator(
                                color: AppColors.coral)
                            // Na troca, o vídeo atual fica visível com um
                            // indicador discreto por cima — nada some.
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: AspectRatio(
                                  aspectRatio: v.value.aspectRatio == 0
                                      ? 16 / 9
                                      : v.value.aspectRatio,
                                  child: GestureDetector(
                                    onTap: _togglePlay,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        VideoPlayer(v),
                                        AnimatedOpacity(
                                          opacity: _switching ? 1 : 0,
                                          duration: const Duration(
                                              milliseconds: 200),
                                          child: Container(
                                            color: Colors.black26,
                                            child: const Center(
                                              child: SizedBox(
                                                width: 34,
                                                height: 34,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 3,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                  ),
                ),
              ),

              // ── Títulos em linha (ordenados), embaixo do vídeo ──
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  itemCount: widget.videos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final sel = i == _current;
                    return Center(
                      child: Material(
                        color: sel ? AppColors.coral : AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            if (i != _current) _load(i);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: sel
                                      ? AppColors.coral
                                      : AppColors.linen),
                            ),
                            child: Text(
                              _titleOf(i),
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: sel
                                    ? Colors.white
                                    : AppColors.walnutSoft,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),

              // ── Progresso + controles: -5s | play/pause | +5s ──
              // Presos ao controller vigente: seguem visíveis durante a
              // troca de vídeo (sem sumir/piscar).
              if (v != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: VideoProgressIndicator(
                      v,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: AppColors.coral,
                        bufferedColor: AppColors.linen,
                        backgroundColor: AppColors.card,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _CtrlBtn(
                        icon: Icons.replay_5_rounded,
                        onTap: () => _skip(-5),
                      ),
                      const SizedBox(width: 20),
                      // Play/pause maior, no centro
                      Material(
                        color: AppColors.coral,
                        shape: const CircleBorder(),
                        elevation: 3,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _togglePlay,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 34,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      _CtrlBtn(
                        icon: Icons.forward_5_rounded,
                        onTap: () => _skip(5),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  const _CtrlBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, size: 26, color: AppColors.walnut),
        ),
      ),
    );
  }
}
