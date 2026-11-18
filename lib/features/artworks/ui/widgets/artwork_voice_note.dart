import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../state/artwork_voice_player.dart';

String _clock(int ms) {
  final total = (ms / 1000).round();
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// 一处定点点评的语音：墨色圆形播放键加时长，和页面上其他语音共用一个播放器。
class ArtworkVoiceNoteButton extends ConsumerWidget {
  const ArtworkVoiceNoteButton({
    required this.playKey,
    required this.source,
    required this.seconds,
    super.key,
  });

  /// 在共用播放器里区分这一段语音。
  final String playKey;
  final String source;
  final int seconds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(artworkVoicePlayerProvider);
    final active = playback.isActive(playKey);
    final playing = active && playback.playing;
    final loading = active && playback.loading;
    final failed = active && playback.failed;
    final label = failed
        ? '语音暂时无法播放'
        : active && (playing || playback.positionMs > 0)
        ? '${_clock(playback.positionMs)} / ${_clock(playback.durationMs)}'
        : seconds > 0
        ? '语音 $seconds 秒'
        : '语音';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppPressable(
          onTap: loading
              ? null
              : () => ref
                    .read(artworkVoicePlayerProvider.notifier)
                    .toggle(playKey, source, seconds: seconds),
          semanticLabel: playing
              ? '暂停语音'
              : (seconds > 0 ? '播放语音，$seconds 秒' : '播放语音'),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.ink,
                  shape: BoxShape.circle,
                ),
                child: loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onBrand,
                        ),
                      )
                    : Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 20,
                        color: AppColors.onBrand,
                      ),
              ),
            ),
          ),
        ),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption12.copyWith(
              color: failed ? AppColors.danger : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// 点评语音：外观与 `HomeworkVoiceCommentBubble` 相同（品牌紫圆键、进度条、时长），
/// 但走页面共用的播放器，和定点点评的语音不会同时响。
class ArtworkVoiceNoteBar extends ConsumerWidget {
  const ArtworkVoiceNoteBar({
    required this.playKey,
    required this.source,
    required this.seconds,
    super.key,
  });

  final String playKey;
  final String source;
  final int seconds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(artworkVoicePlayerProvider);
    final active = playback.isActive(playKey);
    final playing = active && playback.playing;
    final loading = active && playback.loading;
    final durationMs = active && playback.durationMs > 0
        ? playback.durationMs
        : seconds * 1000;
    final positionMs = active ? playback.positionMs : 0;
    final progress = durationMs > 0
        ? (positionMs / durationMs).clamp(0.0, 1.0)
        : 0.0;
    // 36 的圆键外面留出 44 的点击区域，整条仍是 56 高、左边距 12。
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      decoration: const BoxDecoration(
        color: AppColors.brandWash,
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: Row(
        children: [
          AppPressable(
            onTap: loading
                ? null
                : () => ref
                      .read(artworkVoicePlayerProvider.notifier)
                      .toggle(playKey, source, seconds: seconds),
            semanticLabel: playing ? '暂停语音评语' : '播放语音评语',
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.brand,
                    shape: BoxShape.circle,
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onBrand,
                          ),
                        )
                      : Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: AppColors.onBrand,
                          size: 22,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: AppColors.brand.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.brand,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(
                      Icons.graphic_eq_rounded,
                      size: 14,
                      color: AppColors.brand,
                    ),
                    Text(
                      playing || positionMs > 0
                          ? '${_clock(positionMs)} / ${_clock(durationMs)}'
                          : _clock(durationMs),
                      style: AppText.number(
                        size: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
