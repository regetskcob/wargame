import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'audio_backend.dart';

AudioBackend createAudioBackend() => _WebAudioBackend();

/// One shared AudioContext, every sound decoded once and started as a cheap
/// buffer source. Browsers keep the context suspended until the page has seen
/// a click or key press, so it is resumed on those events.
class _WebAudioBackend implements AudioBackend {
  _WebAudioBackend() {
    for (final event in const ['pointerdown', 'keydown', 'touchstart']) {
      web.document.addEventListener(event, ((web.Event _) => _resume()).toJS);
    }
  }

  final web.AudioContext _context = web.AudioContext();
  final _buffers = <String, web.AudioBuffer>{};
  web.AudioBufferSourceNode? _loop;
  web.GainNode? _loopGain;

  void _resume() {
    if (_context.state != 'running') {
      _context.resume();
    }
  }

  @override
  bool get hasLoop => _loop != null;

  @override
  Future<void> load(Map<String, Uint8List> files) async {
    for (final entry in files.entries) {
      final copy = Uint8List.fromList(entry.value);
      _buffers[entry.key] = await _context
          .decodeAudioData(copy.buffer.toJS)
          .toDart;
    }
    debugPrint(
      'Audio ready: ${_buffers.length} sounds, context ${_context.state}',
    );
  }

  web.AudioBufferSourceNode _source(String name, double volume, bool loop) {
    final source = _context.createBufferSource()
      ..buffer = _buffers[name]
      ..loop = loop;
    final gain = _context.createGain()..gain.value = volume;
    source.connect(gain);
    gain.connect(_context.destination);
    if (loop) {
      _loopGain = gain;
    }
    return source;
  }

  @override
  void play(String name, double volume) {
    if (!_buffers.containsKey(name)) {
      return;
    }
    _resume();
    _source(name, volume, false).start();
  }

  @override
  Future<void> startLoop(String name, double volume) async {
    if (!_buffers.containsKey(name)) {
      return;
    }
    await stopLoop();
    _resume();
    final source = _source(name, volume, true)..start();
    _loop = source;
  }

  @override
  Future<void> adjustLoop({
    required double volume,
    required double rate,
  }) async {
    _loopGain?.gain.value = volume;
    _loop?.playbackRate.value = rate;
  }

  @override
  Future<void> stopLoop() async {
    final source = _loop;
    _loop = null;
    _loopGain = null;
    source?.stop();
    source?.disconnect();
  }
}
