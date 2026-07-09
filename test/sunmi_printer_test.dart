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

  test('printBarcode maps enums and passes geometry', () async {
    await SunmiPrinter.printBarcode('12345678',
        type: SunmiBarcodeType.code39,
        height: 80,
        width: 3,
        textPos: SunmiBarcodeTextPos.textUnder);
    expect(log.single.method, 'PRINT_BARCODE');
    expect(log.single.arguments, {
      'data': '12345678',
      'type': 4,
      'height': 80,
      'width': 3,
      'textPos': 2,
    });
  });

  test('printBarcode defaults to code128 / textAbove', () async {
    await SunmiPrinter.printBarcode('X');
    expect(log.single.arguments, {
      'data': 'X',
      'type': 8,
      'height': 100,
      'width': 2,
      'textPos': 1,
    });
  });

  test('printQrCode maps error level', () async {
    await SunmiPrinter.printQrCode('https://example.com',
        moduleSize: 8, errorLevel: SunmiQrLevel.m);
    expect(log.single.method, 'PRINT_QRCODE');
    expect(log.single.arguments, {
      'data': 'https://example.com',
      'moduleSize': 8,
      'errorLevel': 1,
    });
  });

  test('printImage passes raw bytes', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    await SunmiPrinter.printImage(bytes);
    expect(log.single.method, 'PRINT_IMAGE');
    expect(log.single.arguments, {'bytes': bytes});
  });

  test('printTable flattens columns into parallel lists', () async {
    await SunmiPrinter.printTable(const [
      SunmiColumn('Item', width: 2),
      SunmiColumn('Qty', width: 1, align: SunmiAlign.center),
      SunmiColumn('Price', width: 1, align: SunmiAlign.right),
    ]);
    expect(log.single.method, 'PRINT_TABLE');
    expect(log.single.arguments, {
      'texts': ['Item', 'Qty', 'Price'],
      'widths': [2, 1, 1],
      'aligns': [0, 1, 2],
    });
  });

  test('transaction methods', () async {
    await SunmiPrinter.startTransaction();
    await SunmiPrinter.commitTransaction();
    await SunmiPrinter.endTransaction(clear: false);
    expect(log[0].method, 'START_TRANSACTION');
    expect(log[0].arguments, {'clear': true});
    expect(log[1].method, 'COMMIT_TRANSACTION');
    expect(log[2].method, 'END_TRANSACTION');
    expect(log[2].arguments, {'clear': false});
  });

  test('testPrint', () async {
    await SunmiPrinter.testPrint();
    expect(log.single.method, 'TEST_PRINT');
  });
}
