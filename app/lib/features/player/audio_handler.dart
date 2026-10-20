import 'package:audio_service/audio_service.dart';

/// Lock screen / notification bridge. The player controller registers the
/// callbacks and pushes state back via [show].
class HajanekAudioHandler extends BaseAudioHandler {
  Future<void> Function()? onPlay;
  Future<void> Function()? onPause;
  Future<void> Function()? onStop;

  @override
  Future<void> play() async => onPlay?.call();

  @override
  Future<void> pause() async => onPause?.call();

  @override
  Future<void> stop() async {
    await onStop?.call();
    await super.stop();
  }

  void show({required String title, required bool playing, required bool active, Duration? duration}) {
    if (!active) {
      playbackState.add(PlaybackState(processingState: AudioProcessingState.idle));
      return;
    }
    mediaItem.add(MediaItem(id: title, title: title, album: 'Hajánek', duration: duration));
    playbackState.add(PlaybackState(
      processingState: AudioProcessingState.ready,
      playing: playing,
      controls: [playing ? MediaControl.pause : MediaControl.play, MediaControl.stop],
      androidCompactActionIndices: const [0, 1],
      systemActions: const {MediaAction.play, MediaAction.pause, MediaAction.stop},
    ));
  }
}
