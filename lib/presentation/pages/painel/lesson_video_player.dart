import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../widgets/synced_video.dart';

/// Player full-screen com capítulos sincronizados (estilo YarnPal):
/// vídeo grande em cima, pílulas de capítulo, barra de progresso com
/// tempo decorrido/restante e controles próprios (−5s / play / +5s / velocidade).
class LessonVideoPlayerPage extends StatefulWidget {
  const LessonVideoPlayerPage({
    required this.url,
    required this.chapters,
    this.posterUrl,
    this.startAt,
    super.key,
  });

  final String url;
  final String? posterUrl;
  final List<SyncedChapter> chapters;
  final int? startAt; // segundo inicial (capítulo tocado)

  @override
  State<LessonVideoPlayerPage> createState() => _LessonVideoPlayerPageState();
}

class _LessonVideoPlayerPageState extends State<LessonVideoPlayerPage> {
  VideoPlayerController? _v;
  bool _ready = false;
  bool _error = false;
  bool _muted = false;
  int _active = -1;
  final _speeds = const [1.0, 1.5, 2.0];
  int _speedIdx = 0;

  final _pillsCtrl = ScrollController();
  final _pillKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final v = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await v.initialize();
      v.addListener(_onTick);
      if (!mounted) {
        v.dispose();
        return;
      }
      setState(() {
        _v = v;
        _ready = true;
      });
      if (widget.startAt != null) {
        await v.seekTo(Duration(seconds: widget.startAt!));
      }
      await v.play();
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _onTick() {
    final v = _v;
    if (v == null || !v.value.isInitialized) return;
    final pos = v.value.position.inMilliseconds / 1000.0;
    var idx = -1;
    for (var i = 0; i < widget.chapters.length; i++) {
      if (widget.chapters[i].timeSeconds <= pos + 0.3) {
        idx = i;
      } else {
        break;
      }
    }
    if (idx != _active) {
      _active = idx;
      _scrollActivePill();
    }
    if (mounted) setState(() {});
  }

  void _scrollActivePill() {
    final key = _pillKeys[_active];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          alignment: 0.2,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut);
    }
  }

  Future<void> _seekTo(int seconds) async {
    final v = _v;
    if (v == null) return;
    var t = Duration(seconds: seconds);
    final dur = v.value.duration;
    if (t < Duration.zero) t = Duration.zero;
    if (dur > Duration.zero && t > dur) t = dur;
    await v.seekTo(t);
  }

  /// Tocar numa pílula: pula pro capítulo e já reproduz.
  Future<void> _seekChapter(int seconds) async {
    await _seekTo(seconds);
    await _v?.play();
    setState(() {});
  }

  void _togglePlay() {
    final v = _v;
    if (v == null) return;
    v.value.isPlaying ? v.pause() : v.play();
    setState(() {});
  }

  void _skip(int delta) {
    final v = _v;
    if (v == null) return;
    _seekTo(v.value.position.inSeconds + delta);
  }

  void _cycleSpeed() {
    _speedIdx = (_speedIdx + 1) % _speeds.length;
    _v?.setPlaybackSpeed(_speeds[_speedIdx]);
    setState(() {});
  }

  void _toggleMute() {
    _muted = !_muted;
    _v?.setVolume(_muted ? 0 : 1);
    setState(() {});
  }

  @override
  void dispose() {
    _pillsCtrl.dispose();
    _v?.removeListener(_onTick);
    _v?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _v;
    final pos = v?.value.position ?? Duration.zero;
    final dur = v?.value.duration ?? Duration.zero;
    final playing = v?.value.isPlaying ?? false;
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final vw = (v?.value.size.width ?? 0) <= 0 ? 16.0 : v!.value.size.width;
    final vh = (v?.value.size.height ?? 0) <= 0 ? 9.0 : v!.value.size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Vídeo em TELA CHEIA (cover, sem barras) ──
          Positioned.fill(
            child: GestureDetector(
              onTap: _togglePlay,
              child: _ready && v != null
                  ? FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: vw,
                        height: vh,
                        child: VideoPlayer(v),
                      ),
                    )
                  : _Poster(posterUrl: widget.posterUrl, error: _error),
            ),
          ),

          // ── Topo: voltar + feedback ──
          Positioned(
            top: topPad + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _RoundBtn(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.push('/chat'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.headset_mic_outlined,
                            size: 18, color: AppColors.ink),
                        SizedBox(width: 8),
                        Text('Feedback',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Rodapé: painel de controles sobre o vídeo ──
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.paper,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(top: 18, bottom: bottomPad + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Capítulos (pílulas)
                  if (widget.chapters.isNotEmpty)
                    SizedBox(
                      height: 46,
                      child: SingleChildScrollView(
                        controller: _pillsCtrl,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            for (var i = 0; i < widget.chapters.length; i++)
                              Padding(
                                key: _pillKeys[i] ??= GlobalKey(),
                                padding: const EdgeInsets.only(right: 10),
                                child: _ChapterPill(
                                  label: widget.chapters[i].title,
                                  active: i == _active,
                                  onTap: () => _seekChapter(
                                      widget.chapters[i].timeSeconds),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  // Progresso
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _ProgressBar(
                      position: pos,
                      duration: dur,
                      onSeek: (frac) =>
                          _seekTo((dur.inSeconds * frac).round()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Text(_fmt(pos), style: _timeStyle),
                        const Spacer(),
                        Text('-${_fmt(dur - pos)}', style: _timeStyle),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Controles
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: _toggleMute,
                          icon: Icon(
                            _muted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            size: 26,
                            color: AppColors.ink,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _skip(-5),
                          icon: const Icon(Icons.replay_5_rounded,
                              size: 30, color: AppColors.ink),
                        ),
                        GestureDetector(
                          onTap: _togglePlay,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: AppColors.coral,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.coral.withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _skip(5),
                          icon: const Icon(Icons.forward_5_rounded,
                              size: 30, color: AppColors.ink),
                        ),
                        GestureDetector(
                          onTap: _cycleSpeed,
                          child: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: AppColors.ink, width: 1.6),
                            ),
                            child: Text(
                              '${_speeds[_speedIdx] % 1 == 0 ? _speeds[_speedIdx].toInt() : _speeds[_speedIdx]}x',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _timeStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.walnutMuted);

String _fmt(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

class _ChapterPill extends StatelessWidget {
  const _ChapterPill({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active ? AppColors.coral : AppColors.linen,
            width: active ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active) ...[
              const Icon(Icons.graphic_eq_rounded,
                  size: 15, color: AppColors.coral),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? AppColors.coral : AppColors.walnut,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.position,
    required this.duration,
    required this.onSeek,
  });
  final Duration position;
  final Duration duration;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final frac = duration.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, c) {
        void seek(double dx) => onSeek((dx / c.maxWidth).clamp(0.0, 1.0));
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => seek(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => seek(d.localPosition.dx),
          child: SizedBox(
            height: 18,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.linen,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: frac,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.coral,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment(frac * 2 - 1, 0),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: AppColors.coral,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.paper,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: AppColors.ink),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.posterUrl, required this.error});
  final String? posterUrl;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (posterUrl != null && posterUrl!.isNotEmpty)
          Image.network(posterUrl!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: AppColors.peach))
        else
          Container(color: AppColors.peach),
        if (!error)
          const Center(
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
          )
        else
          const Center(
            child: Text('Não foi possível carregar o vídeo',
                style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
      ],
    );
  }
}
