/// Text/element alignment on the printer.
enum SunmiAlign {
  /// Align to the left edge of the paper.
  left(0),

  /// Center on the paper.
  center(1),

  /// Align to the right edge of the paper.
  right(2);

  const SunmiAlign(this.value);

  /// Raw value passed to the Sunmi printer service.
  final int value;
}

/// QR code error-correction level (low → high).
enum SunmiQrLevel {
  /// Low — recovers up to ~7% of data.
  l(0),

  /// Medium — recovers up to ~15% of data.
  m(1),

  /// Quartile — recovers up to ~25% of data.
  q(2),

  /// High — recovers up to ~30% of data.
  h(3);

  const SunmiQrLevel(this.value);

  /// Raw value passed to the Sunmi printer service.
  final int value;
}

/// Barcode symbology supported by the Sunmi printer.
enum SunmiBarcodeType {
  /// UPC-A.
  upcA(0),

  /// UPC-E.
  upcE(1),

  /// JAN13 (EAN13).
  jan13(2),

  /// JAN8 (EAN8).
  jan8(3),

  /// Code 39.
  code39(4),

  /// ITF (Interleaved 2 of 5).
  itf(5),

  /// Codabar.
  codabar(6),

  /// Code 93.
  code93(7),

  /// Code 128.
  code128(8);

  const SunmiBarcodeType(this.value);

  /// Raw value passed to the Sunmi printer service.
  final int value;
}

/// Where the human-readable text is printed relative to a barcode.
enum SunmiBarcodeTextPos {
  /// Do not print the text.
  noText(0),

  /// Print the text above the barcode.
  textAbove(1),

  /// Print the text under the barcode.
  textUnder(2),

  /// Print the text both above and under the barcode.
  both(3);

  const SunmiBarcodeTextPos(this.value);

  /// Raw value passed to the Sunmi printer service.
  final int value;
}

/// Font size presets, in printer font units.
enum SunmiFontSize {
  /// Extra small (14).
  xs(14),

  /// Small (18).
  sm(18),

  /// Medium (24) — the printer default.
  md(24),

  /// Large (36).
  lg(36),

  /// Extra large (42).
  xl(42);

  const SunmiFontSize(this.value);

  /// Font size value usable with `SunmiPrinter.setFontSize`.
  final int value;
}

/// Hardware scanner model reported by the Sunmi scanner service.
enum SunmiScannerModel {
  /// No hardware scanner present.
  none(100),

  /// P2Lite/V2Pro/P2Pro (EM1365/BSM1825).
  p2Lite(101),

  /// L2 Newland (EM2096).
  l2Newland(102),

  /// L2 Zebra (SE4710).
  l2ZebraSe4710(103),

  /// L2 Honeywell (N3601).
  l2HoneywellN3601(104),

  /// L2 Honeywell (N6603).
  l2HoneywellN6603(105),

  /// L2 Zebra (SE4750).
  l2ZebraSe4750(106),

  /// L2 Zebra (EM1350).
  l2ZebraEm1350(107);

  const SunmiScannerModel(this.value);

  /// Raw model code reported by the scanner service.
  final int value;

  /// Resolves a raw model code; unknown codes map to [none].
  static SunmiScannerModel fromValue(int value) =>
      values.firstWhere((model) => model.value == value, orElse: () => none);
}

/// Key event action for `SunmiScanner.sendKeyEvent`.
enum KeyAction {
  /// Simulates key press down (KeyEvent.ACTION_DOWN).
  actionDown(0),

  /// Simulates key release (KeyEvent.ACTION_UP).
  actionUp(1);

  const KeyAction(this.value);

  /// Android KeyEvent action value.
  final int value;
}

/// One column of a table row for `SunmiPrinter.printTable`.
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
