/// Strings shared by more than one screen or widget.
///
/// File-specific copy lives in a `XStrings` const class next to the widget
/// that uses it; this file holds the few strings used across the whole app.
class Strings {
  Strings._();

  static const safe = 'Safe';
  static const moderate = 'Moderate';
  static const advanced = 'Advanced';

  static const confirm = 'Confirm';
  static const cancel = 'Cancel';

  static const monospace = 'monospace';
}