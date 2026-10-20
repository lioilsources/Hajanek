import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../player/player_controller.dart' show playerProvider;
import 'recording_text.dart';
import 'voice_api.dart';
import 'voice_controller.dart';

/// Audio service limits: 5–30 s of speech.
const minRecordSeconds = 5;
const maxRecordSeconds = 30;

/// Mono AAC at 48 kHz with all voice processing off: noise suppression and
/// AGC change the timbre the clone is supposed to learn. On Android the
/// VOICE_RECOGNITION source is required by the CDD to have AGC and noise
/// reduction disabled, and unlike UNPROCESSED it exists on every device.
const recordConfig = RecordConfig(
  encoder: AudioEncoder.aacLc,
  bitRate: 128000,
  sampleRate: 48000,
  numChannels: 1,
  autoGain: false,
  echoCancel: false,
  noiseSuppress: false,
  androidConfig: AndroidRecordConfig(audioSource: AndroidAudioSource.voiceRecognition),
);

final recordingScriptProvider = FutureProvider<String>(
  (ref) => rootBundle.loadString('assets/voice/recording_script.md'),
);

class RecordVoiceScreen extends ConsumerStatefulWidget {
  const RecordVoiceScreen({super.key});

  @override
  ConsumerState<RecordVoiceScreen> createState() => _RecordVoiceScreenState();
}

class _RecordVoiceScreenState extends ConsumerState<RecordVoiceScreen> {
  final _name = TextEditingController();
  bool _consent = false;

  // Created on first use so the screen builds without platform plugins.
  AudioRecorder? _recorder;
  AudioPlayer? _preview;
  StreamSubscription<PlayerState>? _previewSub;
  Timer? _ticker;
  final _clock = Stopwatch();
  bool _recording = false;
  bool _previewPlaying = false;
  String? _path;
  String? _error;

  int get _seconds => _clock.elapsed.inSeconds;

  @override
  void dispose() {
    _ticker?.cancel();
    if (_recording) _recorder?.cancel();
    _recorder?.dispose();
    _previewSub?.cancel();
    _preview?.dispose();
    _name.dispose();
    final path = _path;
    if (path != null) File(path).delete().ignore();
    // The recorder switched the session to play-and-record; restore playback.
    AudioSession.instance.then((s) => s.configure(const AudioSessionConfiguration.music())).ignore();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      await ref.read(playerProvider.notifier).stop();
      await _preview?.stop();
      final rec = _recorder ??= AudioRecorder();
      if (!await rec.hasPermission()) {
        setState(() => _error = S.recNoMic);
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice-sample-${DateTime.now().millisecondsSinceEpoch}.m4a';
      await rec.start(recordConfig, path: path);
      _clock
        ..reset()
        ..start();
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted) return;
        if (_seconds >= maxRecordSeconds) {
          _stop();
        } else {
          setState(() {});
        }
      });
      final old = _path;
      if (old != null) File(old).delete().ignore();
      setState(() {
        _recording = true;
        _path = null;
      });
    } on Object {
      setState(() => _error = S.recFailed);
    }
  }

  Future<void> _stop() async {
    if (!_recording) return;
    _ticker?.cancel();
    _clock.stop();
    _recording = false;
    try {
      final path = await _recorder!.stop();
      if (!mounted) return;
      if (path == null || !File(path).existsSync()) {
        setState(() => _error = S.recFailed);
        return;
      }
      setState(() => _path = path);
    } on Object {
      if (mounted) setState(() => _error = S.recFailed);
    }
  }

  Future<void> _togglePreview() async {
    final path = _path;
    if (path == null) return;
    final p = _preview ??= AudioPlayer();
    _previewSub ??= p.playerStateStream.listen((s) {
      final playing = s.playing && s.processingState != ProcessingState.completed;
      if (mounted && playing != _previewPlaying) setState(() => _previewPlaying = playing);
    });
    if (_previewPlaying) {
      await p.stop();
      return;
    }
    await p.setFilePath(path);
    unawaited(p.play());
  }

  Future<void> _upload(RecordingText text) async {
    final path = _path;
    if (path == null) return;
    await _preview?.stop();
    setState(() => _error = null);
    try {
      await ref.read(voiceProvider.notifier).upload(
            samplePath: path,
            name: _name.text.trim(),
            consentText: text.consent,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(S.voicePending)));
      context.pop();
    } on VoiceApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(recordingScriptProvider).value ?? '';
    final text = parseRecordingScript(source, name: _name.text);
    final busy = ref.watch(voiceProvider.select((s) => s.busy));
    final canRecord = _name.text.trim().isNotEmpty && _consent && !busy;
    final canStop = _recording && _seconds >= minRecordSeconds;

    return Scaffold(
      appBar: AppBar(title: const Text(S.recTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          TextField(
            key: const ValueKey('rec-name'),
            controller: _name,
            enabled: !_recording,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: S.recName, hintText: S.recNameHint),
            onChanged: (_) => setState(() {}),
          ),
          if (text.tips.isNotEmpty) ...[
            const SectionLabel(S.recTips),
            for (final t in text.tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $t', style: const TextStyle(color: Night.textDim)),
              ),
          ],
          const SectionLabel(S.recRead),
          Text(text.consent, style: const TextStyle(fontSize: 20, height: 1.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final l in text.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(l, style: const TextStyle(fontSize: 20, height: 1.5)),
            ),
          const SizedBox(height: 16),
          CheckboxListTile(
            key: const ValueKey('rec-consent'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _consent,
            onChanged: _recording ? null : (v) => setState(() => _consent = v ?? false),
            title: const Text(S.recConsent),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _recording ? (canStop ? S.recReadyHint : S.recMinHint(minRecordSeconds)) : '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Night.textDim),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${_fmt(_seconds)} / ${_fmt(maxRecordSeconds)}',
              style: const TextStyle(fontSize: 22, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
          const SizedBox(height: 16),
          if (_path == null)
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(Night.tap)),
              icon: Icon(_recording ? Icons.stop : Icons.mic),
              label: Text(_recording ? S.recStop : S.recStart, style: const TextStyle(fontSize: 18)),
              onPressed: _recording ? (canStop ? _stop : null) : (canRecord ? _start : null),
            )
          else ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(Night.tap)),
              icon: Icon(_previewPlaying ? Icons.stop : Icons.play_arrow),
              label: Text(_previewPlaying ? S.recPause : S.recPlay),
              onPressed: busy ? null : _togglePreview,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(Night.tap)),
              icon: const Icon(Icons.replay),
              label: const Text(S.recAgain),
              onPressed: busy || !canRecord ? null : _start,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(Night.tap)),
              icon: busy
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(busy ? S.recUploading : S.recUpload, style: const TextStyle(fontSize: 18)),
              onPressed: busy || !canRecord ? null : () => _upload(text),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Night.textDim)),
            ),
        ],
      ),
    );
  }
}
