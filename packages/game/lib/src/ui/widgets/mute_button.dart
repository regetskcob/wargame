import 'package:flutter/material.dart';

import '../../audio_service.dart';

class MuteButton extends StatelessWidget {
  const MuteButton({super.key});

  @override
  Widget build(BuildContext context) {
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
