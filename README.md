# sunmi_utils

Scanner and printer utilities for Sunmi POS devices (Android only): a barcode
scanner stream plus printing of text, QR codes, barcodes, tables, and images
on the built-in Sunmi printer.

Uses `com.sunmi:printerlibrary` and the Sunmi scanner service
(`com.sunmi.scanner`) under the hood — no native setup needed in your app.

## Platform support

| Platform | Supported |
|---|---|
| Android (Sunmi devices) | ✅ |
| iOS / others | ❌ |

Scanner models reported by `SunmiScanner.getModel()` cover P2Lite/V2Pro/P2Pro,
L2 Newland, L2 Zebra (SE4710/SE4750/EM1350), and L2 Honeywell (N3601/N6603).

## Tested on device

- Sunmi V2s
- Sunmi V2 Pro

## Getting started

```yaml
dependencies:
  sunmi_utils: ^1.0.0
```

## Scanner

```dart
import 'package:sunmi_utils/sunmi_utils.dart';

// Listen for scanned barcodes (hardware trigger or SunmiScanner.scan()).
final sub = SunmiScanner.onBarcodeScanned.listen((code) {
  print('Scanned: $code');
});

await SunmiScanner.scan();   // start scanning
await SunmiScanner.stop();   // stop scanning
final model = await SunmiScanner.getModel(); // SunmiScannerModel.p2Lite, ...

sub.cancel(); // always cancel when done
```

## Printer

```dart
// Bind once at startup. The connection is established asynchronously —
// printing immediately after bind() may still fail with SERVICE_NOT_FOUND.
await SunmiPrinter.bind();

await SunmiPrinter.initPrinter();
await SunmiPrinter.setAlignment(SunmiAlign.center);
await SunmiPrinter.setBold(true);
await SunmiPrinter.printText('MY STORE');
await SunmiPrinter.setBold(false);

await SunmiPrinter.printTable(const [
  SunmiColumn('Item', width: 2),
  SunmiColumn('Qty', width: 1, align: SunmiAlign.center),
  SunmiColumn('Price', width: 1, align: SunmiAlign.right),
]);

await SunmiPrinter.printQrCode('https://example.com');
await SunmiPrinter.printBarcode('1234567890', type: SunmiBarcodeType.code128);
await SunmiPrinter.commitTransaction(); // flush queued output; some firmware
                                        // needs this even outside a transaction
await SunmiPrinter.feedPaper();
```

Batch printing with the transaction buffer:

```dart
await SunmiPrinter.startTransaction();
// ... print calls are buffered ...
await SunmiPrinter.commitTransaction(); // flush buffer to paper
await SunmiPrinter.endTransaction();
```

Printing an image (load bytes on the app side):

```dart
final bytes = (await rootBundle.load('assets/logo.png')).buffer.asUint8List();
await SunmiPrinter.printImage(bytes);
```

## Error handling

All failures surface as `PlatformException`:

| Code | Meaning |
|---|---|
| `SERVICE_NOT_FOUND` | Sunmi printer/scanner service unavailable (non-Sunmi device, or not yet connected) |
| `PRINTER_ERROR` | A printer operation failed |
| `SCANNER_ERROR` | A scanner operation failed |

On non-Sunmi devices the plugin loads fine; the first printer/scanner call
throws `SERVICE_NOT_FOUND`.
