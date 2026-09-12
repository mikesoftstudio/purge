import 'package:flutter/material.dart';

Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  String? description,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  bool hideCancel = false,
  bool confirmDisabled = false,
  String? acknowledgeLabel,
  Widget? child,
}) async {
  var ack = acknowledgeLabel == null;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description != null) Text(description),
                    if (child != null) ...[
                      if (description != null) const SizedBox(height: 12),
                      child,
                    ],
                    if (acknowledgeLabel != null) ...[
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: ack,
                        onChanged: (v) => setState(() => ack = v ?? false),
                        title: Text(acknowledgeLabel, style: const TextStyle(fontSize: 13)),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              if (!hideCancel)
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(cancelLabel),
                ),
              FilledButton(
                onPressed: (!ack || confirmDisabled)
                    ? null
                    : () => Navigator.pop(context, true),
                style: destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      )
                    : null,
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      );
    },
  );
  return result ?? false;
}
