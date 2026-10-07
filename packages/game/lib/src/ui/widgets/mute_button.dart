import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../audio_service.dart';

/// Sound on and off, in the browser only. The apps follow the silent switch
/// and the volume keys of the device instead.
class MuteButton extends StatelessWidget {
  const MuteButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<bool>(
      valueListenable: AudioService.muted,
      builder: (context, muted, _) => IconButton(
        tooltip: muted ? 'Ton an' : 'Ton aus',
        onPressed: () => AudioService.muted.value = !muted,
        icon: Icon(muted ? Icons.volume_off : Icons.volume_up),
      ),
    );
  }
}
