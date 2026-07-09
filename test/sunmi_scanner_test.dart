import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunmi_utils/src/enums.dart';
import 'package:sunmi_utils/src/sunmi_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('sunmi_utils/method');
  final log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          log.add(call);
          if (call.method == 'GET_SCANNER_MODEL') return 103;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('scan invokes SCAN', () async {
    await SunmiScanner.scan();
    expect(log.single.method, 'SCAN');
  });

  test('stop invokes STOP_SCAN', () async {
    await SunmiScanner.stop();
    expect(log.single.method, 'STOP_SCAN');
  });

  test('getModel maps raw code to enum', () async {
    final model = await SunmiScanner.getModel();
    expect(log.single.method, 'GET_SCANNER_MODEL');
    expect(model, SunmiScannerModel.l2ZebraSe4710);
  });

  test('sendKeyEvent passes action value and key code', () async {
    await SunmiScanner.sendKeyEvent(KeyAction.actionUp, 88);
    expect(log.single.method, 'SEND_KEY_EVENT');
    expect(log.single.arguments, {'action': 1, 'code': 88});
  });

  test('onBarcodeScanned forwards events from the event channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          const EventChannel('sunmi_utils/scan_events'),
          MockStreamHandler.inline(
            onListen: (arguments, events) {
              events.success('8991234567890');
              events.endOfStream();
            },
          ),
        );
    expect(await SunmiScanner.onBarcodeScanned.first, '8991234567890');
  });
}
