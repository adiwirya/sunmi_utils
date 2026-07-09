import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunmi_utils/src/enums.dart';
import 'package:sunmi_utils/src/sunmi_printer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('sunmi_utils/method');
  final log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      log.add(call);
      return switch (call.method) {
        'GET_DEVICE_MODEL' => 'V2s',
        'GET_PRINTER_VERSION' => '1.05',
        'GET_SERIAL_NUMBER' => 'SN123',
        'GET_PAPER_SIZE' => '58mm',
        _ => null,
      };
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('lifecycle methods invoke the right channel methods', () async {
    await SunmiPrinter.bind();
    await SunmiPrinter.unbind();
    await SunmiPrinter.initPrinter();
    expect(log.map((c) => c.method).toList(),
        ['BIND_PRINTER', 'UNBIND_PRINTER', 'INIT_PRINTER']);
  });

  test('info getters return native values', () async {
    expect(await SunmiPrinter.getDeviceModel(), 'V2s');
    expect(await SunmiPrinter.getPrinterVersion(), '1.05');
    expect(await SunmiPrinter.getSerialNumber(), 'SN123');
    expect(await SunmiPrinter.getPaperSize(), '58mm');
    expect(log.map((c) => c.method).toList(), [
      'GET_DEVICE_MODEL',
      'GET_PRINTER_VERSION',
      'GET_SERIAL_NUMBER',
      'GET_PAPER_SIZE',
    ]);
  });

  test('printText passes the text', () async {
    await SunmiPrinter.printText('Hello');
    expect(log.single.method, 'PRINT_TEXT');
    expect(log.single.arguments, {'text': 'Hello'});
  });

  test('printCustomText passes all style arguments', () async {
    await SunmiPrinter.printCustomText('Big', size: 36, bold: true, underline: true, font: 'custom.ttf');
    expect(log.single.method, 'PRINT_CUSTOM_TEXT');
    expect(log.single.arguments, {
      'text': 'Big',
      'size': 36,
      'bold': true,
      'underline': true,
      'font': 'custom.ttf',
    });
  });

  test('printCustomText defaults', () async {
    await SunmiPrinter.printCustomText('Plain');
    expect(log.single.arguments, {
      'text': 'Plain',
      'size': 24,
      'bold': false,
      'underline': false,
      'font': null,
    });
  });

  test('setAlignment maps enum to int', () async {
    await SunmiPrinter.setAlignment(SunmiAlign.right);
    expect(log.single.method, 'SET_ALIGNMENT');
    expect(log.single.arguments, {'align': 2});
  });

  test('setFontSize / setBold / lineWrap / feedPaper', () async {
    await SunmiPrinter.setFontSize(SunmiFontSize.lg.value);
    await SunmiPrinter.setBold(true);
    await SunmiPrinter.lineWrap(2);
    await SunmiPrinter.feedPaper();
    expect(log[0].method, 'SET_FONT_SIZE');
    expect(log[0].arguments, {'size': 36});
    expect(log[1].method, 'SET_BOLD');
    expect(log[1].arguments, {'bold': true});
    expect(log[2].method, 'LINE_WRAP');
    expect(log[2].arguments, {'lines': 2});
    expect(log[3].method, 'FEED_PAPER');
  });
}
