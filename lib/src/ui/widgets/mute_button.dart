import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../audio/audio_service.dart';
import '../../l10n/l10n.dart';
import '../theme.dart';

/// Sound on and off, in the browser and on the Mac. The phone, tablet,
/// watch and television apps follow the silent switch and the volume keys
/// of the device instead; a Mac has neither for one app.
class MuteButton extends StatelessWidget {
  const MuteButton({this.overWorld = false, super.key});

  /// Over the running round: a dark disc under the icon, as under the leave
  /// button beside it, or it vanished on snow and sand.
  final bool overWorld;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.macOS) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<bool>(
      valueListenable: AudioService.muted,
      builder: (context, muted, _) => IconButton(
        tooltip: muted ? tr('Ton an', 'Sound on') : tr('Ton aus', 'Sound off'),
        style: overWorld
            ? IconButton.styleFrom(
                backgroundColor: GameColors.bg.withValues(alpha: 0.5),
              )
            : null,
        onPressed: () => AudioService.muted.value = !muted,
        icon: Icon(
          muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
        ),
      ),
    );
  }
}
