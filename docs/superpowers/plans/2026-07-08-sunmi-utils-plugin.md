# sunmi_utils Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flutter plugin `sunmi_utils` (Android-only) berisi `SunmiScanner` + `SunmiPrinter` untuk device Sunmi POS, siap publish ke pub.dev.

**Architecture:** Dart API statis (`SunmiScanner`, `SunmiPrinter`) berkomunikasi lewat MethodChannel `sunmi_utils/method` dan EventChannel `sunmi_utils/scan_events` ke `SunmiUtilsPlugin` (Kotlin) yang mendelegasikan ke `PrinterHelper` (wrap `SunmiPrinterService` dari `com.sunmi:printerlibrary`) dan `ScannerHelper` (wrap AIDL `IScanInterface`). Hasil scan dikirim via BroadcastReceiver → EventChannel.

**Tech Stack:** Flutter plugin (Kotlin), `com.sunmi:printerlibrary:1.0.22`, AIDL `com.sunmi.scanner.IScanInterface`, `flutter_test` + `TestDefaultBinaryMessengerBinding` untuk unit test.

**Spec:** `docs/superpowers/specs/2026-07-08-sunmi-utils-package-design.md`

## Global Constraints

- Working dir: `D:\Project\sunmi_utils`. Semua command dijalankan dari sini kecuali disebut lain. Shell: PowerShell (pisahkan command dengan `;`, bukan `&&`).
- Dart SDK: `^3.12.1`; Flutter: `>=3.3.0`.
- Org/namespace Android: `com.summarecon` → package `com.summarecon.sunmi_utils`.
- Channel names: MethodChannel `sunmi_utils/method`, EventChannel `sunmi_utils/scan_events` — persis string ini di Dart dan Kotlin.
- Dependency native HANYA `com.sunmi:printerlibrary:1.0.22` (tanpa zxing, tanpa PayLib).
- `buildFeatures { aidl = true }` wajib di `android/build.gradle` plugin (AGP 8 mematikan AIDL default).
- Versi package `0.1.0`, lisensi MIT.
- lint: `flutter_lints ^6.0.0`; `flutter analyze` harus "No issues found!" sebelum tiap commit.
- Library TIDAK boleh menampilkan UI native (tidak ada Toast) dan TIDAK membaca `rootBundle`.
- Kegagalan native dilaporkan via `result.error(code, message, null)` dengan code: `SERVICE_NOT_FOUND`, `PRINTER_ERROR`, `SCANNER_ERROR`.
- Jangan menyentuh folder `docs/` saat scaffold ulang; `.git/` sudah ada.

---

### Task 1: Scaffold ulang sebagai plugin Android

**Files:**
- Delete: `lib/`, `test/`, `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `CHANGELOG.md`, `README.md`, `LICENSE`, `sunmi_utils.iml`, `.metadata`, `.idea/`, `.vscode/`, `.dart_tool/`
- Create (via `flutter create`): struktur plugin lengkap (`android/`, `example/`, dll)
- Modify: `pubspec.yaml` (tulis ulang penuh), `lib/sunmi_utils.dart`, `example/lib/main.dart`

**Interfaces:**
- Produces: struktur plugin dengan `flutter.plugin.platforms.android` → `package: com.summarecon.sunmi_utils`, `pluginClass: SunmiUtilsPlugin`. Task lain berasumsi struktur ini ada.

- [ ] **Step 1: Hapus scaffold plain-package lama** (JANGAN hapus `docs/` dan `.git/`)

```powershell
cd D:\Project\sunmi_utils
Remove-Item -Recurse -Force lib, test, .idea, .vscode, .dart_tool -ErrorAction SilentlyContinue
Remove-Item -Force pubspec.yaml, pubspec.lock, analysis_options.yaml, CHANGELOG.md, README.md, LICENSE, sunmi_utils.iml, .metadata -ErrorAction SilentlyContinue
```

- [ ] **Step 2: Scaffold plugin di folder yang sama**

```powershell
flutter create --template=plugin --platforms=android --org com.summarecon --project-name sunmi_utils .
```

Expected: "All done!" dan folder `android/`, `example/`, `lib/` muncul.

- [ ] **Step 3: Hapus boilerplate platform-interface yang tidak dipakai** (kita pakai MethodChannel langsung, bukan federated)

```powershell
Remove-Item lib\sunmi_utils_platform_interface.dart, lib\sunmi_utils_method_channel.dart -ErrorAction SilentlyContinue
Remove-Item test\sunmi_utils_test.dart, test\sunmi_utils_method_channel_test.dart -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force example\integration_test -ErrorAction SilentlyContinue
```

- [ ] **Step 4: Ganti isi `lib/sunmi_utils.dart`** dengan placeholder (barrel asli diisi di Task 5):

```dart
/// Scanner and printer utilities for Sunmi POS devices.
library;
```

- [ ] **Step 5: Ganti isi `example/lib/main.dart`** dengan placeholder (UI asli di Task 9):

```dart
import 'package:flutter/material.dart';

void main() {
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('sunmi_utils example'))),
    ),
  );
}
```

- [ ] **Step 6: Tulis ulang `pubspec.yaml` (root, bukan example) persis:**

```yaml
name: sunmi_utils
description: "Scanner and printer utilities for Sunmi POS devices: barcode scanner stream, and printing text, QR codes, barcodes, tables, and images on the built-in Sunmi printer."
version: 0.1.0
repository: https://github.com/summarecon/sunmi_utils
topics:
  - sunmi
  - printer
  - scanner
  - pos
  - barcode

environment:
  sdk: ^3.12.1
  flutter: ">=3.3.0"

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  plugin:
    platforms:
      android:
        package: com.summarecon.sunmi_utils
        pluginClass: SunmiUtilsPlugin
```

Catatan: nilai `repository` disesuaikan dengan URL repo Git sebenarnya sebelum publish (Task 10 memverifikasi); kalau repo belum dibuat, biarkan dulu — `dart pub publish --dry-run` hanya memberi warning, bukan error.

- [ ] **Step 7: Verifikasi**

```powershell
flutter pub get; flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 8: Commit**

```powershell
git add -A; git commit -m "chore: re-scaffold sunmi_utils as Android plugin"
```

---

### Task 2: Enums & tipe pendukung (Dart)

**Files:**
- Create: `lib/src/enums.dart`
- Test: `test/enums_test.dart`

**Interfaces:**
- Produces (dipakai Task 3-5, 9): enum `SunmiAlign{left,center,right}`, `SunmiQrLevel{l,m,q,h}`, `SunmiBarcodeType{upcA..code128}`, `SunmiBarcodeTextPos{noText,textAbove,textUnder,both}`, `SunmiFontSize{xs,sm,md,lg,xl}`, `SunmiScannerModel{none..l2ZebraEm1350}` + `fromValue(int)`, `KeyAction{actionDown,actionUp}` — semua punya `final int value`; class `SunmiColumn(String text, {required int width, SunmiAlign align})`.

- [ ] **Step 1: Tulis failing test `test/enums_test.dart`:**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sunmi_utils/src/enums.dart';

void main() {
  test('SunmiAlign maps to native ints', () {
    expect(SunmiAlign.left.value, 0);
    expect(SunmiAlign.center.value, 1);
    expect(SunmiAlign.right.value, 2);
  });

  test('SunmiQrLevel maps to native ints', () {
    expect(SunmiQrLevel.l.value, 0);
    expect(SunmiQrLevel.m.value, 1);
    expect(SunmiQrLevel.q.value, 2);
    expect(SunmiQrLevel.h.value, 3);
  });

  test('SunmiBarcodeType maps to native ints', () {
    expect(SunmiBarcodeType.upcA.value, 0);
    expect(SunmiBarcodeType.code39.value, 4);
    expect(SunmiBarcodeType.code128.value, 8);
  });

  test('SunmiBarcodeTextPos maps to native ints', () {
    expect(SunmiBarcodeTextPos.noText.value, 0);
    expect(SunmiBarcodeTextPos.textAbove.value, 1);
    expect(SunmiBarcodeTextPos.textUnder.value, 2);
    expect(SunmiBarcodeTextPos.both.value, 3);
  });

  test('SunmiFontSize presets', () {
    expect(SunmiFontSize.xs.value, 14);
    expect(SunmiFontSize.sm.value, 18);
    expect(SunmiFontSize.md.value, 24);
    expect(SunmiFontSize.lg.value, 36);
    expect(SunmiFontSize.xl.value, 42);
  });

  test('SunmiScannerModel.fromValue resolves known models', () {
    expect(SunmiScannerModel.fromValue(101), SunmiScannerModel.p2Lite);
    expect(SunmiScannerModel.fromValue(107), SunmiScannerModel.l2ZebraEm1350);
  });

  test('SunmiScannerModel.fromValue falls back to none', () {
    expect(SunmiScannerModel.fromValue(0), SunmiScannerModel.none);
    expect(SunmiScannerModel.fromValue(999), SunmiScannerModel.none);
  });

  test('KeyAction maps to Android KeyEvent actions', () {
    expect(KeyAction.actionDown.value, 0);
    expect(KeyAction.actionUp.value, 1);
  });

  test('SunmiColumn defaults align to left', () {
    const col = SunmiColumn('Item', width: 2);
    expect(col.text, 'Item');
    expect(col.width, 2);
    expect(col.align, SunmiAlign.left);
  });
}
```

- [ ] **Step 2: Jalankan — pastikan gagal**

```powershell
flutter test test/enums_test.dart
```

Expected: FAIL (compile error, `enums.dart` belum ada).

- [ ] **Step 3: Tulis `lib/src/enums.dart`:**

```dart
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
  static SunmiScannerModel fromValue(int value) => values.firstWhere(
        (model) => model.value == value,
        orElse: () => none,
      );
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
  const SunmiColumn(this.text, {required this.width, this.align = SunmiAlign.left});

  /// Cell content.
  final String text;

  /// Relative column width (proportion, like flex).
  final int width;

  /// Cell alignment.
  final SunmiAlign align;
}
```

Catatan: dartdoc yang mereferensikan `SunmiPrinter`/`SunmiScanner` valid setelah Task 3-4; abaikan warning analyzer `comment_references` sementara jika muncul (tidak error).

- [ ] **Step 4: Jalankan — pastikan lulus**

```powershell
flutter test test/enums_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```powershell
git add lib/src/enums.dart test/enums_test.dart; git commit -m "feat: add Sunmi enums and SunmiColumn"
```

---

### Task 3: SunmiScanner (Dart)

**Files:**
- Create: `lib/src/sunmi_scanner.dart`
- Test: `test/sunmi_scanner_test.dart`

**Interfaces:**
- Consumes: `KeyAction`, `SunmiScannerModel` dari `lib/src/enums.dart`.
- Produces (dipakai Task 8-9): `SunmiScanner.scan()`, `stop()`, `getModel() → Future<SunmiScannerModel>`, `sendKeyEvent(KeyAction, int)`, `onBarcodeScanned → Stream<String>`. Method names di channel: `SCAN`, `STOP_SCAN`, `GET_SCANNER_MODEL`, `SEND_KEY_EVENT`.

- [ ] **Step 1: Tulis failing test `test/sunmi_scanner_test.dart`:**

```dart
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
```

- [ ] **Step 2: Jalankan — pastikan gagal**

```powershell
flutter test test/sunmi_scanner_test.dart
```

Expected: FAIL (compile error, `sunmi_scanner.dart` belum ada).

- [ ] **Step 3: Tulis `lib/src/sunmi_scanner.dart`:**

```dart
import 'package:flutter/services.dart';

import 'enums.dart';

/// API for the built-in hardware barcode scanner on Sunmi devices.
class SunmiScanner {
  SunmiScanner._();

  static const MethodChannel _channel = MethodChannel('sunmi_utils/method');
  static const EventChannel _eventChannel =
      EventChannel('sunmi_utils/scan_events');

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
      _channel.invokeMethod(
        'SEND_KEY_EVENT',
        {'action': action.value, 'code': keyCode},
      );

  /// Broadcast stream of scanned barcodes.
  ///
  /// The native broadcast receiver is only registered while this stream has
  /// listeners. Cancel your subscription when done.
  static Stream<String> get onBarcodeScanned =>
      _barcodeStream ??= _eventChannel
          .receiveBroadcastStream()
          .map((dynamic event) => event as String);
}
```

- [ ] **Step 4: Jalankan — pastikan lulus**

```powershell
flutter test test/sunmi_scanner_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```powershell
git add lib/src/sunmi_scanner.dart test/sunmi_scanner_test.dart; git commit -m "feat: add SunmiScanner Dart API"
```

---

### Task 4: SunmiPrinter (Dart) — lifecycle, info, teks & style

**Files:**
- Create: `lib/src/sunmi_printer.dart`
- Test: `test/sunmi_printer_test.dart`

**Interfaces:**
- Consumes: `SunmiAlign` dari `lib/src/enums.dart`.
- Produces (dilengkapi Task 5, dipakai Task 8-9): `SunmiPrinter.bind()`, `unbind()`, `initPrinter()`, `getDeviceModel()`, `getPrinterVersion()`, `getSerialNumber()`, `getPaperSize()` (semua info `Future<String?>`), `printText(String)`, `printCustomText(String, {int size, bool bold, bool underline, String? font})`, `setAlignment(SunmiAlign)`, `setFontSize(int)`, `setBold(bool)`, `lineWrap(int)`, `feedPaper()`.

- [ ] **Step 1: Tulis failing test `test/sunmi_printer_test.dart`:**

```dart
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
```

- [ ] **Step 2: Jalankan — pastikan gagal**

```powershell
flutter test test/sunmi_printer_test.dart
```

Expected: FAIL (compile error, `sunmi_printer.dart` belum ada).

- [ ] **Step 3: Tulis `lib/src/sunmi_printer.dart`:**

```dart
import 'package:flutter/services.dart';

import 'enums.dart';

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

  /// Prints [text] with one-off styling, without changing global style state.
  static Future<void> printCustomText(
    String text, {
    int size = 24,
    bool bold = false,
    bool underline = false,
    String? font,
  }) =>
      _channel.invokeMethod('PRINT_CUSTOM_TEXT', {
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
  static Future<void> setBold(bool bold) =>
      _channel.invokeMethod('SET_BOLD', {'bold': bold});

  /// Feeds [lines] blank lines.
  static Future<void> lineWrap(int lines) =>
      _channel.invokeMethod('LINE_WRAP', {'lines': lines});

  /// Pushes the paper out to the tear bar (falls back to 3 blank lines on
  /// devices that don't support it).
  static Future<void> feedPaper() => _channel.invokeMethod('FEED_PAPER');
}
```

- [ ] **Step 4: Jalankan — pastikan lulus**

```powershell
flutter test test/sunmi_printer_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```powershell
git add lib/src/sunmi_printer.dart test/sunmi_printer_test.dart; git commit -m "feat: add SunmiPrinter lifecycle, info, text and style APIs"
```

---

### Task 5: SunmiPrinter (Dart) — barcode/QR/image/table/transaksi + barrel export

**Files:**
- Modify: `lib/src/sunmi_printer.dart` (tambah method), `lib/sunmi_utils.dart` (barrel), `test/sunmi_printer_test.dart` (tambah test)

**Interfaces:**
- Consumes: `SunmiBarcodeType`, `SunmiBarcodeTextPos`, `SunmiQrLevel`, `SunmiColumn` dari enums.
- Produces (dipakai Task 8-9): `printBarcode`, `printQrCode`, `printImage(Uint8List)`, `printTable(List<SunmiColumn>)`, `startTransaction({bool clear})`, `commitTransaction()`, `endTransaction({bool clear})`, `testPrint()`; barrel `package:sunmi_utils/sunmi_utils.dart` mengekspor enums + printer + scanner.

- [ ] **Step 1: Tambahkan test berikut di dalam `main()` `test/sunmi_printer_test.dart` (setelah test yang sudah ada):**

```dart
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
```

Tambahkan import di atas file test: `import 'dart:typed_data';`

- [ ] **Step 2: Jalankan — pastikan gagal**

```powershell
flutter test test/sunmi_printer_test.dart
```

Expected: FAIL (method belum ada).

- [ ] **Step 3: Tambahkan di `lib/src/sunmi_printer.dart`** — import `dart:typed_data` di atas (`import 'dart:typed_data';` — atau cukup `package:flutter/services.dart` yang sudah re-export `Uint8List`; kalau analyzer komplain, tambahkan eksplisit), lalu method berikut di dalam class sebelum penutup `}`:

```dart
  // ----------------------------------------------------------- barcode & more

  /// Prints a 1D barcode.
  static Future<void> printBarcode(
    String data, {
    SunmiBarcodeType type = SunmiBarcodeType.code128,
    int height = 100,
    int width = 2,
    SunmiBarcodeTextPos textPos = SunmiBarcodeTextPos.textAbove,
  }) =>
      _channel.invokeMethod('PRINT_BARCODE', {
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
  }) =>
      _channel.invokeMethod('PRINT_QRCODE', {
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
```

- [ ] **Step 4: Ganti isi `lib/sunmi_utils.dart` dengan barrel:**

```dart
/// Scanner and printer utilities for Sunmi POS devices.
library;

export 'src/enums.dart';
export 'src/sunmi_printer.dart';
export 'src/sunmi_scanner.dart';
```

- [ ] **Step 5: Jalankan semua test + analyze — pastikan lulus**

```powershell
flutter test; flutter analyze
```

Expected: `All tests passed!` dan `No issues found!`

- [ ] **Step 6: Commit**

```powershell
git add lib test; git commit -m "feat: add barcode/QR/image/table/transaction printing and barrel export"
```

---

### Task 6: Native — gradle, AIDL & ScannerHelper

**Files:**
- Modify: `android/build.gradle`
- Create: `android/src/main/aidl/com/sunmi/scanner/IScanInterface.aidl`
- Create: `android/src/main/kotlin/com/summarecon/sunmi_utils/ScannerHelper.kt`

**Interfaces:**
- Produces (dipakai Task 8): `ScannerHelper(context)` dengan `connect()`, `disconnect()`, `scan()`, `stop()`, `getScannerModel(): Int`, `sendKeyEvent(action: Int, code: Int)`. Method melempar `IllegalStateException` bila service scanner belum terkoneksi.

- [ ] **Step 1: Edit `android/build.gradle`** — di dalam blok `android { ... }` hasil scaffold, tambahkan setelah baris `namespace`:

```groovy
    buildFeatures {
        aidl = true
    }
```

dan di akhir file (level teratas, setelah blok `android`), tambahkan:

```groovy
dependencies {
    implementation("com.sunmi:printerlibrary:1.0.22")
}
```

Jangan mengubah versi AGP/Kotlin yang digenerate template. (Kalau template sudah membuat blok `dependencies`, cukup tambahkan baris implementation ke dalamnya.)

- [ ] **Step 2: Salin AIDL** — buat `android/src/main/aidl/com/sunmi/scanner/IScanInterface.aidl` dengan isi persis (verbatim dari pos-mobile, path sumber: `D:\Project\pos-mobile\android\app\src\main\aidl\com\sunmi\scanner\IScanInterface.aidl`):

```aidl
package com.sunmi.scanner;

interface IScanInterface {
    /**
         *
         * key.getAction()==KeyEvent.ACTION_UP
         * key.getAction()==KeyEvent.ACTION_DWON
         */
        void sendKeyEvent(in KeyEvent key);
        /**
         *
         */
        void scan();
        /**
         *
         */
        void stop();
        /**
         *
         * 100-->NONE
         * 101-->P2Lite
         * 102-->l2-newland
         * 103-->l2-zebra
         */
        int getScannerModel();
}
```

Fallback terdokumentasi: jika build Step 4 gagal dengan error AIDL "couldn't find import for class KeyEvent", tambahkan baris `import android.view.KeyEvent;` setelah baris `package` (di pos-mobile file ini terbukti compile tanpa import, jadi kemungkinan besar tidak perlu).

- [ ] **Step 3: Tulis `android/src/main/kotlin/com/summarecon/sunmi_utils/ScannerHelper.kt`:**

```kotlin
package com.summarecon.sunmi_utils

import android.app.Service
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import android.view.KeyEvent
import com.sunmi.scanner.IScanInterface

/**
 * Wraps the Sunmi scanner AIDL service (com.sunmi.scanner).
 * All operations throw [IllegalStateException] when the service is not
 * connected (e.g. non-Sunmi device).
 */
class ScannerHelper(private val context: Context) {
    private var scanService: IScanInterface? = null
    private var bound = false

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            scanService = IScanInterface.Stub.asInterface(binder)
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            scanService = null
        }
    }

    fun connect() {
        val intent = Intent().apply {
            setPackage("com.sunmi.scanner")
            action = "com.sunmi.scanner.IScanInterface"
        }
        bound = context.bindService(intent, connection, Service.BIND_AUTO_CREATE)
    }

    fun disconnect() {
        if (bound) {
            runCatching { context.unbindService(connection) }
            bound = false
        }
        scanService = null
    }

    private fun requireService(): IScanInterface = scanService
        ?: throw IllegalStateException("Sunmi scanner service is not connected on this device")

    fun scan() = requireService().scan()

    fun stop() = requireService().stop()

    fun getScannerModel(): Int = requireService().scannerModel

    fun sendKeyEvent(action: Int, code: Int) {
        requireService().sendKeyEvent(KeyEvent(action, code))
    }
}
```

Catatan porting: berbeda dari `SunmiScannerHelper.java` pos-mobile, semua `Toast` dihapus dan "silent return saat service null" diganti `IllegalStateException` (sesuai spec error handling).

- [ ] **Step 4: Verifikasi compile**

```powershell
cd example; flutter build apk --debug; cd ..
```

Expected: `Built build\app\outputs\flutter-apk\app-debug.apk`. (Template `SunmiUtilsPlugin.kt` masih versi getPlatformVersion — itu diganti di Task 8; yang penting AIDL + ScannerHelper compile.)

- [ ] **Step 5: Commit**

```powershell
git add android; git commit -m "feat(android): add scanner AIDL, ScannerHelper, and printerlibrary dependency"
```

---

### Task 7: Native — PrinterHelper

**Files:**
- Create: `android/src/main/kotlin/com/summarecon/sunmi_utils/PrinterHelper.kt`

**Interfaces:**
- Consumes: `com.sunmi.peripheral.printer.*` dari `printerlibrary` (ditambahkan Task 6).
- Produces (dipakai Task 8): `PrinterHelper` dengan `bind(context): Boolean`, `unbind(context)`, `initPrinter()`, `getDeviceModel()`, `getPrinterVersion()`, `getSerialNumber()`, `getPaperSize()`, `printText`, `printCustomText`, `setAlignment(Int)`, `setFontSize(Float)`, `setBold(Boolean)`, `lineWrap(Int)`, `feedPaper()`, `printBarcode`, `printQr`, `printTable`, `printBitmap`, `enterPrinterBuffer`, `commitPrinterBuffer`, `exitPrinterBuffer`, `printTestPage()`. Method melempar `IllegalStateException` bila service belum terkoneksi.

- [ ] **Step 1: Tulis `android/src/main/kotlin/com/summarecon/sunmi_utils/PrinterHelper.kt`:**

```kotlin
package com.summarecon.sunmi_utils

import android.content.Context
import android.graphics.Bitmap
import android.os.RemoteException
import com.sunmi.peripheral.printer.InnerPrinterCallback
import com.sunmi.peripheral.printer.InnerPrinterException
import com.sunmi.peripheral.printer.InnerPrinterManager
import com.sunmi.peripheral.printer.SunmiPrinterService
import com.sunmi.peripheral.printer.WoyouConsts

/**
 * Wraps [SunmiPrinterService] from com.sunmi:printerlibrary.
 * Ported from pos-mobile's SunmiPrintHelper.java, keeping only the methods
 * used by the plugin channel; Toasts removed, silent failures replaced with
 * exceptions (surfaced to Dart as PlatformException).
 */
class PrinterHelper {
    private var service: SunmiPrinterService? = null

    private val callback = object : InnerPrinterCallback() {
        override fun onConnected(s: SunmiPrinterService) {
            service = s
        }

        override fun onDisconnected() {
            service = null
        }
    }

    private fun requireService(): SunmiPrinterService = service
        ?: throw IllegalStateException(
            "Sunmi printer service is not connected. Call SunmiPrinter.bind() first and wait for the connection."
        )

    /** Returns false when the Sunmi printer service does not exist on this device. */
    fun bind(context: Context): Boolean = try {
        InnerPrinterManager.getInstance().bindService(context, callback)
    } catch (e: InnerPrinterException) {
        false
    }

    fun unbind(context: Context) {
        if (service != null) {
            try {
                InnerPrinterManager.getInstance().unBindService(context, callback)
            } catch (_: InnerPrinterException) {
            }
            service = null
        }
    }

    fun initPrinter() {
        requireService().printerInit(null)
    }

    fun getDeviceModel(): String = requireService().printerModal ?: ""

    fun getPrinterVersion(): String = requireService().printerVersion ?: ""

    fun getSerialNumber(): String = requireService().printerSerialNo ?: ""

    fun getPaperSize(): String = if (requireService().printerPaper == 1) "58mm" else "80mm"

    fun printText(text: String) {
        requireService().printText(text + "\n", null)
    }

    fun printCustomText(text: String, size: Float, bold: Boolean, underline: Boolean, font: String?) {
        val s = requireService()
        try {
            s.setPrinterStyle(
                WoyouConsts.ENABLE_BOLD,
                if (bold) WoyouConsts.ENABLE else WoyouConsts.DISABLE
            )
        } catch (e: RemoteException) {
            // setPrinterStyle requires printer service v4.2.22+; fall back to ESC.
            s.sendRAWData(if (bold) ESC_BOLD_ON else ESC_BOLD_OFF, null)
        }
        try {
            s.setPrinterStyle(
                WoyouConsts.ENABLE_UNDERLINE,
                if (underline) WoyouConsts.ENABLE else WoyouConsts.DISABLE
            )
        } catch (e: RemoteException) {
            s.sendRAWData(if (underline) ESC_UNDERLINE_ON else ESC_UNDERLINE_OFF, null)
        }
        s.printTextWithFont(text, font, size, null)
    }

    fun setAlignment(align: Int) {
        requireService().setAlignment(align, null)
    }

    fun setFontSize(size: Float) {
        requireService().setFontSize(size, null)
    }

    fun setBold(bold: Boolean) {
        requireService().sendRAWData(if (bold) ESC_BOLD_ON else ESC_BOLD_OFF, null)
    }

    fun lineWrap(lines: Int) {
        requireService().lineWrap(lines, null)
    }

    fun feedPaper() {
        try {
            requireService().autoOutPaper(null)
        } catch (e: RemoteException) {
            // Devices without auto-out paper: feed 3 lines instead.
            requireService().lineWrap(3, null)
        }
    }

    fun printBarcode(data: String, symbology: Int, height: Int, width: Int, textPos: Int) {
        requireService().printBarCode(data, symbology, height, width, textPos, null)
    }

    fun printQr(data: String, moduleSize: Int, errorLevel: Int) {
        requireService().printQRCode(data, moduleSize, errorLevel, null)
    }

    fun printTable(texts: Array<String>, widths: IntArray, aligns: IntArray) {
        requireService().printColumnsString(texts, widths, aligns, null)
    }

    fun printBitmap(bitmap: Bitmap) {
        requireService().printBitmap(bitmap, null)
    }

    fun enterPrinterBuffer(clear: Boolean) {
        requireService().enterPrinterBuffer(clear)
    }

    fun commitPrinterBuffer() {
        requireService().commitPrinterBuffer()
    }

    fun exitPrinterBuffer(clear: Boolean) {
        requireService().exitPrinterBuffer(clear)
    }

    fun printTestPage() {
        val s = requireService()
        s.printerInit(null)
        s.setAlignment(1, null)
        s.printText("sunmi_utils test print\n", null)
        s.printColumnsString(arrayOf("Item", "Price"), intArrayOf(1, 1), intArrayOf(0, 2), null)
        s.lineWrap(3, null)
    }

    companion object {
        // ESC/POS commands, taken from pos-mobile's ESCUtil (the only 4 used).
        private val ESC_BOLD_ON = byteArrayOf(0x1B, 69, 0x0F)
        private val ESC_BOLD_OFF = byteArrayOf(0x1B, 69, 0)
        private val ESC_UNDERLINE_ON = byteArrayOf(0x1B, 45, 1)
        private val ESC_UNDERLINE_OFF = byteArrayOf(0x1B, 45, 0)
    }
}
```

- [ ] **Step 2: Verifikasi compile**

```powershell
cd example; flutter build apk --debug; cd ..
```

Expected: `Built build\app\outputs\flutter-apk\app-debug.apk`.

- [ ] **Step 3: Commit**

```powershell
git add android; git commit -m "feat(android): add PrinterHelper wrapping SunmiPrinterService"
```

---

### Task 8: Native — SunmiUtilsPlugin (wiring channel + receiver)

**Files:**
- Modify: `android/src/main/kotlin/com/summarecon/sunmi_utils/SunmiUtilsPlugin.kt` (ganti seluruh isi template)

**Interfaces:**
- Consumes: `PrinterHelper` (Task 7), `ScannerHelper` (Task 6). Method names & argumen HARUS cocok dengan Dart (Task 3-5): `BIND_PRINTER`, `UNBIND_PRINTER`, `INIT_PRINTER`, `GET_DEVICE_MODEL`, `GET_PRINTER_VERSION`, `GET_SERIAL_NUMBER`, `GET_PAPER_SIZE`, `PRINT_TEXT{text}`, `PRINT_CUSTOM_TEXT{text,size,bold,underline,font}`, `SET_ALIGNMENT{align}`, `SET_FONT_SIZE{size}`, `SET_BOLD{bold}`, `LINE_WRAP{lines}`, `FEED_PAPER`, `PRINT_BARCODE{data,type,height,width,textPos}`, `PRINT_QRCODE{data,moduleSize,errorLevel}`, `PRINT_IMAGE{bytes}`, `PRINT_TABLE{texts,widths,aligns}`, `START_TRANSACTION{clear}`, `COMMIT_TRANSACTION`, `END_TRANSACTION{clear}`, `TEST_PRINT`, `SCAN`, `STOP_SCAN`, `GET_SCANNER_MODEL`, `SEND_KEY_EVENT{action,code}`.
- Produces: plugin terdaftar otomatis via `pubspec.yaml` `pluginClass`.

- [ ] **Step 1: Ganti seluruh isi `SunmiUtilsPlugin.kt` dengan:**

```kotlin
package com.summarecon.sunmi_utils

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Flutter plugin exposing the Sunmi printer and scanner services. */
class SunmiUtilsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel

    private val printer = PrinterHelper()
    private var scanner: ScannerHelper? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var receiverRegistered = false

    private val scannerActions = listOf(
        "com.sunmi.scanner.ACTION_DATA_CODE_RECEIVED",
        "com.sunmi.scanner.action.DATA_CODE_RECEIVED",
        "com.sunmi.scanner.ACTION_BARCODE_READER_DATA"
    )

    private val scannerDataKeys = listOf(
        "data", "code", "barcode_data", "scannerdata", "SCAN_BARCODE1", "value"
    )

    private val scanReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            if (intent == null) return
            val data = extractScanData(intent) ?: return
            mainHandler.post { eventSink?.success(data) }
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, "sunmi_utils/method")
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "sunmi_utils/scan_events")
        eventChannel.setStreamHandler(this)
        scanner = ScannerHelper(context).also { it.connect() }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        unregisterReceiverIfNeeded()
        scanner?.disconnect()
        scanner = null
        printer.unbind(context)
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
    }

    private fun requireScanner(): ScannerHelper = scanner
        ?: throw IllegalStateException("Scanner is not initialized")

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                // ------------------------------------------------- printer
                "BIND_PRINTER" -> {
                    if (printer.bind(context)) {
                        result.success(null)
                    } else {
                        result.error(
                            "SERVICE_NOT_FOUND",
                            "Sunmi printer service not found on this device",
                            null
                        )
                    }
                }
                "UNBIND_PRINTER" -> { printer.unbind(context); result.success(null) }
                "INIT_PRINTER" -> { printer.initPrinter(); result.success(null) }
                "GET_DEVICE_MODEL" -> result.success(printer.getDeviceModel())
                "GET_PRINTER_VERSION" -> result.success(printer.getPrinterVersion())
                "GET_SERIAL_NUMBER" -> result.success(printer.getSerialNumber())
                "GET_PAPER_SIZE" -> result.success(printer.getPaperSize())
                "PRINT_TEXT" -> {
                    printer.printText(call.argument<String>("text") ?: "")
                    result.success(null)
                }
                "PRINT_CUSTOM_TEXT" -> {
                    printer.printCustomText(
                        call.argument<String>("text") ?: "",
                        (call.argument<Int>("size") ?: 24).toFloat(),
                        call.argument<Boolean>("bold") ?: false,
                        call.argument<Boolean>("underline") ?: false,
                        call.argument<String>("font")
                    )
                    result.success(null)
                }
                "SET_ALIGNMENT" -> {
                    printer.setAlignment(call.argument<Int>("align") ?: 0)
                    result.success(null)
                }
                "SET_FONT_SIZE" -> {
                    printer.setFontSize((call.argument<Int>("size") ?: 24).toFloat())
                    result.success(null)
                }
                "SET_BOLD" -> {
                    printer.setBold(call.argument<Boolean>("bold") ?: false)
                    result.success(null)
                }
                "LINE_WRAP" -> {
                    printer.lineWrap(call.argument<Int>("lines") ?: 1)
                    result.success(null)
                }
                "FEED_PAPER" -> { printer.feedPaper(); result.success(null) }
                "PRINT_BARCODE" -> {
                    printer.printBarcode(
                        call.argument<String>("data") ?: "",
                        call.argument<Int>("type") ?: 8,
                        call.argument<Int>("height") ?: 100,
                        call.argument<Int>("width") ?: 2,
                        call.argument<Int>("textPos") ?: 1
                    )
                    result.success(null)
                }
                "PRINT_QRCODE" -> {
                    printer.printQr(
                        call.argument<String>("data") ?: "",
                        call.argument<Int>("moduleSize") ?: 12,
                        call.argument<Int>("errorLevel") ?: 3
                    )
                    result.success(null)
                }
                "PRINT_IMAGE" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null || bytes.isEmpty()) {
                        result.error("PRINTER_ERROR", "Image bytes are empty", null)
                        return
                    }
                    val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                    if (bitmap == null) {
                        result.error("PRINTER_ERROR", "Bytes could not be decoded as an image", null)
                        return
                    }
                    printer.printBitmap(bitmap)
                    result.success(null)
                }
                "PRINT_TABLE" -> {
                    printer.printTable(
                        (call.argument<List<String>>("texts") ?: emptyList()).toTypedArray(),
                        (call.argument<List<Int>>("widths") ?: emptyList()).toIntArray(),
                        (call.argument<List<Int>>("aligns") ?: emptyList()).toIntArray()
                    )
                    result.success(null)
                }
                "START_TRANSACTION" -> {
                    printer.enterPrinterBuffer(call.argument<Boolean>("clear") ?: true)
                    result.success(null)
                }
                "COMMIT_TRANSACTION" -> { printer.commitPrinterBuffer(); result.success(null) }
                "END_TRANSACTION" -> {
                    printer.exitPrinterBuffer(call.argument<Boolean>("clear") ?: true)
                    result.success(null)
                }
                "TEST_PRINT" -> { printer.printTestPage(); result.success(null) }
                // ------------------------------------------------- scanner
                "SCAN" -> { requireScanner().scan(); result.success(null) }
                "STOP_SCAN" -> { requireScanner().stop(); result.success(null) }
                "GET_SCANNER_MODEL" -> result.success(requireScanner().getScannerModel())
                "SEND_KEY_EVENT" -> {
                    requireScanner().sendKeyEvent(
                        call.argument<Int>("action") ?: 0,
                        call.argument<Int>("code") ?: 0
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: IllegalStateException) {
            result.error("SERVICE_NOT_FOUND", e.message, null)
        } catch (e: Exception) {
            val code = if (call.method in SCANNER_METHODS) "SCANNER_ERROR" else "PRINTER_ERROR"
            result.error(code, e.message ?: e.toString(), null)
        }
    }

    // ------------------------------------------------------ scan event stream

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        registerReceiverIfNeeded()
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        unregisterReceiverIfNeeded()
    }

    private fun registerReceiverIfNeeded() {
        if (receiverRegistered) return
        val filter = IntentFilter().apply { scannerActions.forEach { addAction(it) } }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(scanReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            context.registerReceiver(scanReceiver, filter)
        }
        receiverRegistered = true
    }

    private fun unregisterReceiverIfNeeded() {
        if (!receiverRegistered) return
        runCatching { context.unregisterReceiver(scanReceiver) }
        receiverRegistered = false
    }

    private fun extractScanData(intent: Intent): String? {
        scannerDataKeys.forEach { key ->
            val value = intent.getStringExtra(key)
            if (!value.isNullOrBlank()) return value
        }
        val bytes = intent.getByteArrayExtra("data")
        if (bytes != null && bytes.isNotEmpty()) return String(bytes)
        return null
    }

    companion object {
        private val SCANNER_METHODS =
            setOf("SCAN", "STOP_SCAN", "GET_SCANNER_MODEL", "SEND_KEY_EVENT")
    }
}
```

- [ ] **Step 2: Verifikasi compile + seluruh test Dart masih lulus**

```powershell
cd example; flutter build apk --debug; cd ..; flutter test; flutter analyze
```

Expected: APK built, `All tests passed!`, `No issues found!`

- [ ] **Step 3: Commit**

```powershell
git add android; git commit -m "feat(android): implement SunmiUtilsPlugin channel wiring and scan broadcast receiver"
```

---

### Task 9: Example app

**Files:**
- Modify: `example/lib/main.dart` (ganti seluruh isi placeholder)

**Interfaces:**
- Consumes: seluruh API publik `package:sunmi_utils/sunmi_utils.dart` (Task 2-5).

- [ ] **Step 1: Ganti seluruh isi `example/lib/main.dart`:**

```dart
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
    return const MaterialApp(
      title: 'sunmi_utils example',
      home: HomePage(),
    );
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
    _scanSubscription?.cancel();
    super.dispose();
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    try {
      await action();
      _showMessage('$label: OK');
    } on PlatformException catch (e) {
      _showMessage('$label gagal: [${e.code}] ${e.message}');
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
        _printerInfo = 'Model: $model\nVersi: $version\nSN: $serial\nKertas: $paper';
      });
    } on PlatformException catch (e) {
      setState(() => _printerInfo = 'Gagal: [${e.code}] ${e.message}');
    }
  }

  Future<void> _printSampleReceipt() async {
    await SunmiPrinter.startTransaction();
    await SunmiPrinter.setAlignment(SunmiAlign.center);
    await SunmiPrinter.setBold(true);
    await SunmiPrinter.printText('SUNMI UTILS DEMO');
    await SunmiPrinter.setBold(false);
    await SunmiPrinter.printText('Contoh struk');
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.setAlignment(SunmiAlign.left);
    await SunmiPrinter.printTable(const [
      SunmiColumn('Item', width: 2),
      SunmiColumn('Qty', width: 1, align: SunmiAlign.center),
      SunmiColumn('Harga', width: 1, align: SunmiAlign.right),
    ]);
    await SunmiPrinter.printTable(const [
      SunmiColumn('Kopi', width: 2),
      SunmiColumn('2', width: 1, align: SunmiAlign.center),
      SunmiColumn('30rb', width: 1, align: SunmiAlign.right),
    ]);
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.setAlignment(SunmiAlign.center);
    await SunmiPrinter.printQrCode('https://pub.dev/packages/sunmi_utils');
    await SunmiPrinter.printBarcode('1234567890');
    await SunmiPrinter.feedPaper();
    await SunmiPrinter.commitTransaction();
    await SunmiPrinter.endTransaction();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('sunmi_utils example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Scanner', style: Theme.of(context).textTheme.titleLarge),
          Text('Barcode terakhir: $_lastBarcode'),
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
                onPressed: () => _run('Model scanner', () async {
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
                child: const Text('Info printer'),
              ),
              ElevatedButton(
                onPressed: () => _run('Test print', SunmiPrinter.testPrint),
                child: const Text('Test print'),
              ),
              ElevatedButton(
                onPressed: () =>
                    _run('Print teks', () => SunmiPrinter.printText('Halo dari sunmi_utils!')),
                child: const Text('Print teks'),
              ),
              ElevatedButton(
                onPressed: () => _run(
                  'Print custom',
                  () => SunmiPrinter.printCustomText('TEBAL BESAR',
                      size: SunmiFontSize.lg.value, bold: true),
                ),
                child: const Text('Print custom'),
              ),
              ElevatedButton(
                onPressed: () => _run('Print struk contoh', _printSampleReceipt),
                child: const Text('Struk contoh'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verifikasi**

```powershell
flutter analyze; cd example; flutter build apk --debug; cd ..
```

Expected: `No issues found!` dan APK built.

- [ ] **Step 3: Commit**

```powershell
git add example; git commit -m "feat: add example app demonstrating scanner and printer APIs"
```

---

### Task 10: Dokumen pub.dev + publish dry-run

**Files:**
- Create/Modify: `README.md`, `CHANGELOG.md`, `LICENSE`

**Interfaces:**
- Consumes: seluruh API publik (nama method di contoh README harus cocok dengan Task 2-5).

- [ ] **Step 1: Tulis `README.md`:**

````markdown
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

Tested on Sunmi V2s. Scanner models reported by `SunmiScanner.getModel()`
cover P2Lite/V2Pro/P2Pro, L2 Newland, L2 Zebra (SE4710/SE4750/EM1350), and
L2 Honeywell (N3601/N6603).

## Getting started

```yaml
dependencies:
  sunmi_utils: ^0.1.0
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
````

- [ ] **Step 2: Tulis `CHANGELOG.md`:**

```markdown
## 0.1.0

- Initial release.
- `SunmiScanner`: scan/stop, scanner model, key events, barcode broadcast stream.
- `SunmiPrinter`: bind/init, printer info, text/custom text, alignment/font/bold,
  barcode, QR code, image, table, line wrap/feed paper, transaction buffer, test print.
```

- [ ] **Step 3: Tulis `LICENSE`** (MIT):

```text
MIT License

Copyright (c) 2026 Rizky Rahmansyah

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 4: Verifikasi penuh**

```powershell
flutter test; flutter analyze; dart pub publish --dry-run
```

Expected: semua test lulus, analyze bersih, dry-run menampilkan "Package has 0 warnings" ATAU hanya warning soal `repository` URL jika repo Git remote belum dibuat (dapat diterima; perbaiki URL sebelum publish sungguhan).

- [ ] **Step 5: Commit**

```powershell
git add README.md CHANGELOG.md LICENSE; git commit -m "docs: add README, CHANGELOG, and MIT license for pub.dev"
```

---

## Verifikasi Manual di Device Sunmi (dilakukan user, setelah Task 10)

Jalankan example app di device Sunmi fisik (`cd example; flutter run`) dan cek:

1. **Scanner**: tombol Scan menyalakan scanner head; scan barcode → "Barcode terakhir" terisi; trigger fisik juga masuk ke stream; tombol Model menampilkan model yang benar.
2. **Printer**: Bind → Info printer terisi (model/versi/SN/kertas); Test print keluar; Print teks/custom keluar sesuai style; Struk contoh keluar utuh (header center bold, table rapi, QR + barcode tercetak, kertas maju).
3. **Error path**: jalankan di device/emulator non-Sunmi → tombol printer/scanner memunculkan snackbar `[SERVICE_NOT_FOUND] ...`, app tidak crash, tidak ada Toast native.

Setelah lolos + repo Git remote dibuat (update field `repository` di pubspec): `dart pub publish`.
