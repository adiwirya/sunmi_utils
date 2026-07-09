/// Text/element alignment on the printer.
enum SunmiAlign {
  left(0),
  center(1),
  right(2);

  const SunmiAlign(this.value);

  /// Raw value passed to the Sunmi printer service.
  final int value;
}

/// QR code error-correction level (low → high).
enum SunmiQrLevel {
  l(0),
  m(1),
  q(2),
  h(3);

  const SunmiQrLevel(this.value);

  /// Raw value passed to the Sunmi printer service.
  final int value;
}

/// Barcode symbology supported by the Sunmi printer.
enum SunmiBarcodeType {
  upcA(0),
  upcE(1),
  jan13(2),
  jan8(3),
  code39(4),
  itf(5),
  codabar(6),
  code93(7),
  code128(8);

  const SunmiBarcodeType(this.value);

  /// Raw value passed to the Sunmi printer service.
  final int value;
}

/// Where the human-readable text is printed relative to a barcode.
enum SunmiBarcodeTextPos {
  noText(0),
  textAbove(1),
  textUnder(2),
  both(3);

  const SunmiBarcodeTextPos(this.value);

  /// Raw value passed to the Sunmi printer service.
  final int value;
}

/// Font size presets, in printer font units.
enum SunmiFontSize {
  xs(14),
  sm(18),
  md(24),
  lg(36),
  xl(42);

  const SunmiFontSize(this.value);

  /// Font size value usable with [SunmiPrinter.setFontSize].
  final int value;
}

/// Hardware scanner model reported by the Sunmi scanner service.
enum SunmiScannerModel {
  none(100),
  p2Lite(101),
  l2Newland(102),
  l2ZebraSe4710(103),
  l2HoneywellN3601(104),
  l2HoneywellN6603(105),
  l2ZebraSe4750(106),
  l2ZebraEm1350(107);

  const SunmiScannerModel(this.value);

  /// Raw model code reported by the scanner service.
  final int value;

  /// Resolves a raw model code; unknown codes map to [none].
  static SunmiScannerModel fromValue(int value) =>
      values.firstWhere((model) => model.value == value, orElse: () => none);
}

/// Key event action for [SunmiScanner.sendKeyEvent].
enum KeyAction {
  /// Simulates key press down (KeyEvent.ACTION_DOWN).
  actionDown(0),

  /// Simulates key release (KeyEvent.ACTION_UP).
  actionUp(1);

  const KeyAction(this.value);

  /// Android KeyEvent action value.
  final int value;
}

/// One column of a table row for [SunmiPrinter.printTable].
class SunmiColumn {
  /// Creates a column with [text] content, a relative [width], and an
  /// optional [align] (defaults to [SunmiAlign.left]).
  const SunmiColumn(
    this.text, {
    required this.width,
    this.align = SunmiAlign.left,
  });

  /// Cell content.
  final String text;

  /// Relative column width (proportion, like flex).
  final int width;

  /// Cell alignment.
  final SunmiAlign align;
}
