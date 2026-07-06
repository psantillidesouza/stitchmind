import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';

/// Player de vídeo de tutorial (aula / ponto), no estilo YarnPal.
///
/// Mostra o poster + botão ▶ e só carrega o vídeo quando o usuário toca
/// (economiza dados). Ao tocar, abre o player com controles e fullscreen.
class LessonVideo extends StatefulWidget {
  const LessonVideo({
    required this.url,
    this.posterUrl,
    this.aspectRatio = 16 / 9,
    this.borderRadius = 16,
    super.key,
  });

  final String url;
  final String? posterUrl;
  final double aspectRatio;
  final double borderRadius;

  @override
  State<LessonVideo> createState() => _LessonVideoState();
}

class _LessonVideoState extends State<LessonVideo> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  bool _loading = false;
  bool _error = false;

  Future<void> _start() async {
    if (_loading || _chewie != null) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final v = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await v.initialize();
      final ratio = v.value.aspectRatio == 0 ? widget.aspectRatio : v.value.aspectRatio;
      final c = ChewieController(
        videoPlayerController: v,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        aspectRatio: ratio,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.coral,
          handleColor: AppColors.coral,
          bufferedColor: AppColors.peach,
          backgroundColor: AppColors.linen,
        ),
      );
      if (!mounted) {
        await c.videoPlayerController.dispose();
        c.dispose();
        return;
      }
      setState(() {
        _video = v;
        _chewie = c;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: _chewie != null
            ? Chewie(controller: _chewie!)
            : _Poster(
                posterUrl: widget.posterUrl,
                loading: _loading,
                error: _error,
                onPlay: _start,
              ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({
    required this.posterUrl,
    required this.loading,
    required this.error,
    required this.onPlay,
  });

  final String? posterUrl;
  final bool loading;
  final bool error;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onPlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (posterUrl != null && posterUrl!.isNotEmpty)
            Image.network(posterUrl!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: AppColors.peach))
          else
            Container(color: AppColors.peach),
          Container(color: Colors.black.withValues(alpha: 0.18)),
          Center(
            child: loading
                ? const SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  )
                : Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.coral,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 36),
                  ),
          ),
          if (error)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Text('Não foi possível carregar o vídeo',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
