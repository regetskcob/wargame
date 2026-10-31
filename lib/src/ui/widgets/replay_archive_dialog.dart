import 'dart:async';

import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../../game/map_theme.dart';
import '../../game/tank_game.dart';
import '../../l10n/l10n.dart';
import '../../net/replay_store.dart';
import '../theme.dart';
import 'game_dialog.dart';

/// The commander's battles on this device, to watch again or to delete.
void showReplayArchive(BuildContext context, TankGame game) {
  unawaited(
    showGameDialog<void>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text(tr('EINSATZARCHIV', 'BATTLE ARCHIVE')),
        content: _ArchiveList(game: game),
        actions: [
          horizontDialogAction(
            context,
            label: tr('SCHLIESSEN', 'CLOSE'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ),
  );
}

class _ArchiveList extends StatefulWidget {
  const _ArchiveList({required this.game});

  final TankGame game;

  @override
  State<_ArchiveList> createState() => _ArchiveListState();
}

class _ArchiveListState extends State<_ArchiveList> {
  List<ArchivedReplay>? _entries;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final entries = await widget.game.replayStore?.list() ?? const [];
    if (mounted) {
      setState(() => _entries = entries);
    }
  }

  Future<void> _delete(ArchivedReplay entry) async {
    await widget.game.replayStore?.delete(entry);
    await _load();
  }

  void _watch(ArchivedReplay entry) {
    Navigator.of(context).pop();
    unawaited(widget.game.watchArchived(entry));
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    if (entries == null) {
      return const SizedBox(height: HzSpace.s24);
    }
    if (entries.isEmpty) {
      return Text(
        tr(
          'Noch nichts archiviert. Deine nächsten Gefechte landen hier.',
          'Nothing archived yet. Your next battles land here.',
        ),
        style: GameType.callout,
      );
    }
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in entries)
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => _watch(entry),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(archiveLabel(entry), maxLines: 2),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: tr('Löschen', 'Delete'),
                  onPressed: () => unawaited(_delete(entry)),
                  icon: const Icon(HorizontSymbols.delete),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// A line for the list: when, on which ground, how long.
String archiveLabel(ArchivedReplay entry) {
  final at = DateTime.fromMillisecondsSinceEpoch(entry.startedAt);
  String two(int n) => n.toString().padLeft(2, '0');
  final seconds = entry.lengthMs ~/ 1000;
  final kind = switch (entry.kind) {
    'd' => tr('Verteidigung', 'Defense'),
    'f' => tr('Fahnenraub', 'Capture the flag'),
    _ => tr('Gefecht', 'Battle'),
  };
  return '${two(at.day)}.${two(at.month)}. ${two(at.hour)}:${two(at.minute)}'
      '$horizontMetaSeparator$kind'
      '$horizontMetaSeparator${MapTheme.forSeed(entry.seed).name}'
      '$horizontMetaSeparator${seconds ~/ 60}:${two(seconds % 60)}';
}
