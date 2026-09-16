import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sunmi_utils/sunmi_utils.dart';

void main() {
  runApp(const SunmiUtilsExampleApp());
}

class SunmiUtilsExampleApp extends StatelessWidget {
  const SunmiUtilsExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: 'sunmi_utils example', home: HomePage());
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  StreamSubscription<String>? _scanSubscription;
  String _lastBarcode = '-';
  String _printerInfo = '-';

  @override
  void initState() {
    super.initState();
    _scanSubscription = SunmiScanner.onBarcodeScanned.listen((code) {
      setState(() => _lastBarcode = code);
    });
  }

  @override
  void dispose() {
    unawaited(_scanSubscription?.cancel());
    super.dispose();
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    try {
      await action();
      _showMessage('$label: OK');
    } on PlatformException catch (e) {
      _showMessage('$label failed: [${e.code}] ${e.message}');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadPrinterInfo() async {
    try {
      final model = await SunmiPrinter.getDeviceModel();
      final version = await SunmiPrinter.getPrinterVersion();
      final serial = await SunmiPrinter.getSerialNumber();
      final paper = await SunmiPrinter.getPaperSize();
      setState(() {
        _printerInfo =
            'Model: $model\nVersion: $version\nSN: $serial\nPaper: $paper';
      });
    } on PlatformException catch (e) {
      setState(() => _printerInfo = 'Failed: [${e.code}] ${e.message}');
    }
  }

  static const _divider = '--------------------------------';

  Future<void> _printSampleReceipt() async {
    await SunmiPrinter.startTransaction();
    await SunmiPrinter.setAlignment(SunmiAlign.center);
    await SunmiPrinter.printCustomText(
      'SUNMI UTILS STORE',
      size: SunmiFontSize.lg.value,
      bold: true,
    );
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printText('Jl. Contoh No. 123, Jakarta');
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.setAlignment(SunmiAlign.left);
    await SunmiPrinter.printText(_divider);
    await SunmiPrinter.printTable(const [
      SunmiColumn('Item', width: 2),
      SunmiColumn('Qty', width: 1, align: SunmiAlign.center),
      SunmiColumn('Price', width: 1, align: SunmiAlign.right),
    ]);
    await SunmiPrinter.printText(_divider);
    await SunmiPrinter.printTable(const [
      SunmiColumn('Coffee', width: 2),
      SunmiColumn('2', width: 1, align: SunmiAlign.center),
      SunmiColumn('30k', width: 1, align: SunmiAlign.right),
    ]);
    await SunmiPrinter.printTable(const [
      SunmiColumn('Croissant', width: 2),
      SunmiColumn('1', width: 1, align: SunmiAlign.center),
      SunmiColumn('25k', width: 1, align: SunmiAlign.right),
    ]);
    await SunmiPrinter.printTable(const [
      SunmiColumn('Latte', width: 2),
      SunmiColumn('1', width: 1, align: SunmiAlign.center),
      SunmiColumn('28k', width: 1, align: SunmiAlign.right),
    ]);
    await SunmiPrinter.printText(_divider);
    await SunmiPrinter.setAlignment(SunmiAlign.right);
    await SunmiPrinter.printCustomText('Total: 83k', bold: true);
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.setAlignment(SunmiAlign.center);
    await SunmiPrinter.printText('Thank you for your purchase!');
    await SunmiPrinter.feedPaper();
    await SunmiPrinter.commitTransaction();
    await SunmiPrinter.endTransaction();
  }

  Future<void> _printSampleQrCode() async {
    await SunmiPrinter.setAlignment(SunmiAlign.center);
    await SunmiPrinter.printQrCode('https://pub.dev/packages/sunmi_utils');
    await SunmiPrinter.commitTransaction();
    await SunmiPrinter.feedPaper();
  }

  Future<void> _printSampleBarcode() async {
    await SunmiPrinter.setAlignment(SunmiAlign.center);
    await SunmiPrinter.printBarcode('1234567890');
    await SunmiPrinter.commitTransaction();
    await SunmiPrinter.feedPaper();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('sunmi_utils example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Scanner', style: Theme.of(context).textTheme.titleLarge),
          Text('Last barcode: $_lastBarcode'),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: () => _run('Scan', SunmiScanner.scan),
                child: const Text('Scan'),
              ),
              ElevatedButton(
                onPressed: () => _run('Stop', SunmiScanner.stop),
                child: const Text('Stop'),
              ),
              ElevatedButton(
                onPressed: () => _run('Scanner model', () async {
                  final model = await SunmiScanner.getModel();
                  _showMessage('Scanner: ${model.name}');
                }),
                child: const Text('Model'),
              ),
            ],
          ),
          const Divider(height: 32),
          Text('Printer', style: Theme.of(context).textTheme.titleLarge),
          Text(_printerInfo),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: () => _run('Bind', SunmiPrinter.bind),
                child: const Text('Bind'),
              ),
              ElevatedButton(
                onPressed: () => _run('Unbind', SunmiPrinter.unbind),
                child: const Text('Unbind'),
              ),
              ElevatedButton(
                onPressed: () => _run('Init', SunmiPrinter.initPrinter),
                child: const Text('Init'),
              ),
              ElevatedButton(
                onPressed: _loadPrinterInfo,
                child: const Text('Printer info'),
              ),
              ElevatedButton(
                onPressed: () => _run('Test print', SunmiPrinter.testPrint),
                child: const Text('Test print'),
              ),
              ElevatedButton(
                onPressed: () => _run('Print text', () async {
                  await SunmiPrinter.printText('Hello from sunmi_utils!');
                  await SunmiPrinter.commitTransaction();
                  await SunmiPrinter.feedPaper();
                }),
                child: const Text('Print text'),
              ),
              ElevatedButton(
                onPressed: () => _run('Print custom', () async {
                  await SunmiPrinter.printCustomText(
                    'BOLD LARGE',
                    size: SunmiFontSize.lg.value,
                    bold: true,
                  );
                  await SunmiPrinter.commitTransaction();
                  await SunmiPrinter.feedPaper();
                }),
                child: const Text('Print custom'),
              ),
              ElevatedButton(
                onPressed: () =>
                    _run('Print sample receipt', _printSampleReceipt),
                child: const Text('Sample receipt'),
              ),
              ElevatedButton(
                onPressed: () => _run('Print QR code', _printSampleQrCode),
                child: const Text('Print QR'),
              ),
              ElevatedButton(
                onPressed: () => _run('Print barcode', _printSampleBarcode),
                child: const Text('Print barcode'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
