import 'package:flutter/material.dart';

import '../../tv/tv_input.dart';

/// Shows a dialog built from `AlertDialog.adaptive` and
/// `horizontDialogAction`: native on iOS and macOS as Horizont asks, but on a
/// television always in Material, since Apple TV reports iOS and the remote
/// moves the focus frame only between Material buttons.
Future<T?> showGameDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  if (!onTv) {
    return showAdaptiveDialog<T>(context: context, builder: builder);
  }
  return showDialog<T>(
    context: context,
    builder: (context) => Theme(
      data: Theme.of(context).copyWith(platform: TargetPlatform.android),
      child: Builder(builder: builder),
    ),
  );
}
