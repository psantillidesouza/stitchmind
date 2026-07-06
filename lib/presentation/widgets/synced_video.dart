import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../pages/painel/lesson_video_player.dart';

/// Um "ponto"/capítulo marcado no vídeo: título + descrição + tempo (s).
class SyncedChapter {
  const SyncedChapter({
    required this.title,
    required this.timeSeconds,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final int timeSeconds;
}

/// Miniatura do vídeo com capítulos. Toca → abre o player full-screen
/// ([LessonVideoPlayerPage]) com pílulas de capítulo sincronizadas.
class SyncedVideo extends StatelessWidget {
  const SyncedVideo({
    required this.url,
    required this.chapters,
    this.posterUrl,
    super.key,
  });

  final String url;
  final String? posterUrl;
  final List<SyncedChapter> chapters;

  void _open(BuildContext context, {int? startAt}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LessonVideoPlayerPage(
          url: url,
          posterUrl: posterUrl,
          chapters: chapters,
          startAt: startAt,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
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
                child: Container(
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
              if (chapters.isNotEmpty)
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.graphic_eq_rounded,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text('${chapters.length} capítulos',
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
