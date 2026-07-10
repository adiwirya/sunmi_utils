import 'package:flutter/services.dart';

import 'package:sunmi_utils/src/enums.dart';

/// API for the built-in hardware barcode scanner on Sunmi devices.
class SunmiScanner {
  SunmiScanner._();

  static const MethodChannel _channel = MethodChannel('sunmi_utils/method');
  static const EventChannel _eventChannel = EventChannel(
    'sunmi_utils/scan_events',
  );

  static Stream<String>? _barcodeStream;

  /// Starts a scan (turns on the scanner head).
  static Future<void> scan() => _channel.invokeMethod('SCAN');

  /// Stops an ongoing scan.
  static Future<void> stop() => _channel.invokeMethod('STOP_SCAN');

  /// Returns the hardware scanner model of this device.
  static Future<SunmiScannerModel> getModel() async {
    final value = await _channel.invokeMethod<int>('GET_SCANNER_MODEL');
    return SunmiScannerModel.fromValue(value ?? SunmiScannerModel.none.value);
  }

  /// Sends a key event to the scanner service, e.g. to customize the
  /// physical trigger key.
  static Future<void> sendKeyEvent(KeyAction action, int keyCode) =>
      _channel.invokeMethod('SEND_KEY_EVENT', {
        'action': action.value,
        'code': keyCode,
      });

  /// Broadcast stream of scanned barcodes.
  ///
  /// The native broadcast receiver is only registered while this stream has
  /// listeners. Cancel your subscription when done.
  static Stream<String> get onBarcodeScanned => _barcodeStream ??= _eventChannel
      .receiveBroadcastStream()
      .map((dynamic event) => event as String);
}
