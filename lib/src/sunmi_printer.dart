import 'package:flutter/services.dart';

import 'package:sunmi_utils/src/enums.dart';

/// API for the built-in thermal printer on Sunmi devices.
///
/// Call [bind] once (e.g. at app startup) before using any other method.
/// The service connection is established asynchronously, so printing
/// immediately after [bind] resolves may still throw a
/// [PlatformException] with code `SERVICE_NOT_FOUND`.
class SunmiPrinter {
  SunmiPrinter._();

  static const MethodChannel _channel = MethodChannel('sunmi_utils/method');

  // ---------------------------------------------------------------- lifecycle

  /// Binds to the Sunmi printer service.
  ///
  /// Throws a [PlatformException] with code `SERVICE_NOT_FOUND` on devices
  /// without the Sunmi printer service.
  static Future<void> bind() => _channel.invokeMethod('BIND_PRINTER');

  /// Unbinds from the Sunmi printer service.
  static Future<void> unbind() => _channel.invokeMethod('UNBIND_PRINTER');

  /// Resets printer style settings (alignment, font, bold) to defaults.
  static Future<void> initPrinter() => _channel.invokeMethod('INIT_PRINTER');

  // --------------------------------------------------------------------- info

  /// Printer device model, e.g. `V2s`.
  static Future<String?> getDeviceModel() =>
      _channel.invokeMethod<String>('GET_DEVICE_MODEL');

  /// Printer firmware version.
  static Future<String?> getPrinterVersion() =>
      _channel.invokeMethod<String>('GET_PRINTER_VERSION');

  /// Printer serial number.
  static Future<String?> getSerialNumber() =>
      _channel.invokeMethod<String>('GET_SERIAL_NUMBER');

  /// Paper size: `58mm` or `80mm`.
  static Future<String?> getPaperSize() =>
      _channel.invokeMethod<String>('GET_PAPER_SIZE');

  // ------------------------------------------------------------------ content

  /// Prints [text] followed by a newline.
  static Future<void> printText(String text) =>
      _channel.invokeMethod('PRINT_TEXT', {'text': text});

  /// Prints [text] with custom styling.
  ///
  /// The bold/underline styles set by this call persist for subsequent
  /// prints until changed again or reset via [initPrinter].
  static Future<void> printCustomText(
    String text, {
    int size = 24,
    bool bold = false,
    bool underline = false,
    String? font,
  }) => _channel.invokeMethod('PRINT_CUSTOM_TEXT', {
    'text': text,
    'size': size,
    'bold': bold,
    'underline': underline,
    'font': font,
  });

  // -------------------------------------------------------------------- style

  /// Sets alignment for subsequent prints.
  static Future<void> setAlignment(SunmiAlign align) =>
      _channel.invokeMethod('SET_ALIGNMENT', {'align': align.value});

  /// Sets font size for subsequent prints. Use [SunmiFontSize] values for
  /// presets, e.g. `setFontSize(SunmiFontSize.lg.value)`.
  static Future<void> setFontSize(int size) =>
      _channel.invokeMethod('SET_FONT_SIZE', {'size': size});

  /// Enables or disables bold for subsequent prints.
  // ignore: avoid_positional_boolean_parameters
  static Future<void> setBold(bool bold) =>
      _channel.invokeMethod('SET_BOLD', {'bold': bold});

  /// Feeds [lines] blank lines.
  static Future<void> lineWrap(int lines) =>
      _channel.invokeMethod('LINE_WRAP', {'lines': lines});

  /// Pushes the paper out to the tear bar (falls back to 3 blank lines on
  /// devices that don't support it).
  static Future<void> feedPaper() => _channel.invokeMethod('FEED_PAPER');

  // ----------------------------------------------------------- barcode & more

  /// Prints a 1D barcode.
  static Future<void> printBarcode(
    String data, {
    SunmiBarcodeType type = SunmiBarcodeType.code128,
    int height = 100,
    int width = 2,
    SunmiBarcodeTextPos textPos = SunmiBarcodeTextPos.textAbove,
  }) => _channel.invokeMethod('PRINT_BARCODE', {
    'data': data,
    'type': type.value,
    'height': height,
    'width': width,
    'textPos': textPos.value,
  });

  /// Prints a QR code.
  static Future<void> printQrCode(
    String data, {
    int moduleSize = 12,
    SunmiQrLevel errorLevel = SunmiQrLevel.h,
  }) => _channel.invokeMethod('PRINT_QRCODE', {
    'data': data,
    'moduleSize': moduleSize,
    'errorLevel': errorLevel.value,
  });

  /// Prints an image from encoded [bytes] (PNG/JPEG). Load assets on the app
  /// side, e.g. `(await rootBundle.load(path)).buffer.asUint8List()`.
  static Future<void> printImage(Uint8List bytes) =>
      _channel.invokeMethod('PRINT_IMAGE', {'bytes': bytes});

  /// Prints one table row described by [columns].
  static Future<void> printTable(List<SunmiColumn> columns) =>
      _channel.invokeMethod('PRINT_TABLE', {
        'texts': columns.map((c) => c.text).toList(),
        'widths': columns.map((c) => c.width).toList(),
        'aligns': columns.map((c) => c.align.value).toList(),
      });

  // -------------------------------------------------------------- transaction

  /// Enters transaction (buffer) mode; content is only printed on
  /// [commitTransaction] / [endTransaction].
  static Future<void> startTransaction({bool clear = true}) =>
      _channel.invokeMethod('START_TRANSACTION', {'clear': clear});

  /// Prints the buffered content and keeps transaction mode active.
  static Future<void> commitTransaction() =>
      _channel.invokeMethod('COMMIT_TRANSACTION');

  /// Exits transaction mode, printing remaining buffered content.
  static Future<void> endTransaction({bool clear = true}) =>
      _channel.invokeMethod('END_TRANSACTION', {'clear': clear});

  /// Prints a small built-in sample page (useful to verify the printer).
  static Future<void> testPrint() => _channel.invokeMethod('TEST_PRINT');
}
