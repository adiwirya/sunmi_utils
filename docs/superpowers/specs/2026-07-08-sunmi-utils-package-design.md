# sunmi_utils — Flutter Plugin Design

**Date:** 2026-07-08
**Status:** Approved
**Source:** Ported from `pos-mobile` (`lib/utils/sunmi_scan.dart`, `lib/utils/sunmi_print.dart`, `lib/utils/enums.dart`, `MainActivity.kt`, `SunmiPrintHelper.java`, `SunmiScannerHelper.java`)

## Goal

Ekstrak fungsionalitas scanner dan printer Sunmi dari project `pos-mobile` menjadi satu Flutter plugin bernama `sunmi_utils` yang dipublish ke pub.dev. App pemakai cukup menambahkan dependency — tidak perlu menyalin kode native atau mengubah `MainActivity`.

## Keputusan Kunci

| Keputusan | Pilihan |
|---|---|
| Tipe package | Full Flutter plugin (native Android dibundel) |
| Scope | Scan + Print saja (tanpa `PrintUtils` app-specific, tanpa PayLib) |
| Distribusi | Publish ke pub.dev (nama `sunmi_utils` tersedia, diverifikasi 2026-07-08) |
| Gaya API | Dirapikan mengikuti konvensi Dart (bukan drop-in dari pos-mobile) |
| Struktur | Satu package plugin Android-only (bukan federated, bukan dipecah dua) |

## Arsitektur

Plugin Android-only. Folder `D:\Project\sunmi_utils` yang sekarang berisi scaffold *plain package* di-scaffold ulang dengan template plugin (`flutter create --template=plugin --platforms=android`).

```
sunmi_utils/
├── lib/
│   ├── sunmi_utils.dart              # barrel export
│   └── src/
│       ├── sunmi_printer.dart
│       ├── sunmi_scanner.dart
│       └── enums.dart
├── android/
│   ├── build.gradle                  # com.sunmi:printerlibrary:1.0.22, buildFeatures aidl=true
│   └── src/main/
│       ├── kotlin/com/summarecon/sunmi_utils/
│       │   ├── SunmiUtilsPlugin.kt   # channels + BroadcastReceiver scanner
│       │   ├── PrinterHelper.kt      # port SunmiPrintHelper (Kotlin, hanya method yang dipakai channel)
│       │   └── ScannerHelper.kt      # port SunmiScannerHelper (Kotlin)
│       └── aidl/com/sunmi/scanner/IScanInterface.aidl
├── example/                          # demo app scan & print
├── test/                             # unit test Dart (mock channel)
├── README.md, CHANGELOG.md, LICENSE (MIT)
```

- **Channel names (namespaced):** `sunmi_utils/method` (MethodChannel) dan `sunmi_utils/scan_events` (EventChannel). Nama lama `sunmi_channel`/`sunmi_event` tidak dipakai — kedua sisi channel pindah bersama ke plugin sehingga tidak ada isu kompatibilitas.
- **`SunmiUtilsPlugin`** (Kotlin) implement `FlutterPlugin` + `ActivityAware`, memindahkan seluruh logika dari `MainActivity.kt` pos-mobile: method call handler, EventChannel stream handler, dan BroadcastReceiver scanner (actions `com.sunmi.scanner.*`, extraction keys `data`/`code`/`barcode_data`/dst).
- **Dependency native via Maven:** hanya `com.sunmi:printerlibrary:1.0.22`. Temuan saat porting: `BitmapUtil`, `BytesUtil`, `ThreadPoolManager`, dan hampir seluruh `ESCUtil` di pos-mobile tidak pernah dipakai oleh jalur channel (hanya demo code) — jadi zxing/`core-3.3.0.jar` **tidak diperlukan** dan tidak diikutkan. Hanya 4 perintah ESC (bold on/off, underline on/off) yang diambil sebagai konstanta byte. Helper ditulis ulang sebagai Kotlin di namespace plugin; AIDL tetap `com.sunmi.scanner.IScanInterface` (kontrak service Sunmi).

## API Publik Dart

### SunmiScanner

```dart
class SunmiScanner {
  static Future<void> scan();
  static Future<void> stop();
  static Future<SunmiScannerModel> getModel();
  static Future<void> sendKeyEvent(KeyAction action, int keyCode);
  static Stream<String> get onBarcodeScanned; // broadcast
}
```

### SunmiPrinter

```dart
class SunmiPrinter {
  // lifecycle
  static Future<void> bind();
  static Future<void> unbind();
  static Future<void> initPrinter();

  // info
  static Future<String?> getDeviceModel();
  static Future<String?> getPrinterVersion();
  static Future<String?> getSerialNumber();
  static Future<String?> getPaperSize();

  // konten
  static Future<void> printText(String text);
  static Future<void> printCustomText(String text,
      {int size = 24, bool bold = false, bool underline = false, String? font});
  static Future<void> printBarcode(String data,
      {SunmiBarcodeType type = SunmiBarcodeType.code128,
      int height = 100, int width = 2,
      SunmiBarcodeTextPos textPos = SunmiBarcodeTextPos.textAbove});
  static Future<void> printQrCode(String data,
      {int moduleSize = 12, SunmiQrLevel errorLevel = SunmiQrLevel.h});
  static Future<void> printImage(Uint8List bytes);
  static Future<void> printTable(List<SunmiColumn> columns);
  static Future<void> lineWrap(int lines);
  static Future<void> feedPaper();
  static Future<void> testPrint();

  // style
  static Future<void> setAlignment(SunmiAlign align);
  static Future<void> setFontSize(int size); // preset via konstanta SunmiFontSize
  static Future<void> setBold(bool bold);

  // transaksi (buffer)
  static Future<void> startTransaction({bool clear = true});
  static Future<void> commitTransaction();
  static Future<void> endTransaction({bool clear = true});
}
```

### Enum & tipe pendukung

- `SunmiAlign { left, center, right }`
- `SunmiQrLevel { l, m, q, h }`
- `SunmiBarcodeType { upcA, upcE, jan13, jan8, code39, itf, codabar, code93, code128 }`
- `SunmiBarcodeTextPos { noText, textAbove, textUnder, both }`
- `SunmiFontSize { xs(14), sm(18), md(24), lg(36), xl(42) }` — enhanced enum dengan nilai int
- `SunmiScannerModel { none(100), p2Lite(101), l2Newland(102), l2ZebraSe4710(103), l2HoneywellN3601(104), l2HoneywellN6603(105), l2ZebraSe4750(106), l2ZebraEm1350(107) }`
- `KeyAction { actionDown, actionUp }`
- `SunmiColumn(String text, int width, SunmiAlign align)` — menggantikan 3 list paralel di `printTable`

### Perubahan perilaku yang disengaja (vs pos-mobile)

1. Enum lowerCamelCase; mapping enum→int native terpusat (extension/enhanced enum), tidak lagi switch bertebaran di tiap method.
2. `printText`/`printCustomText` **tidak** memanggil `initPrinter()` otomatis lagi.
3. Return `Future<void>` — kegagalan dilempar sebagai `PlatformException`, bukan `bool?` yang selalu `true`.
4. `printImage` menerima `Uint8List` — app yang bertanggung jawab load asset, package tidak membaca `rootBundle`.
5. `getModel()` mengembalikan enum `SunmiScannerModel`, bukan int mentah 100–107.
6. `printTable` menerima `List<SunmiColumn>`.

## Error Handling

- Semua handler native dibungkus try-catch. `RemoteException`/`InnerPrinterException` → `result.error(code, message, null)` → `PlatformException` di Dart.
- Error codes: `PRINTER_ERROR` (kegagalan operasi printer), `SERVICE_NOT_FOUND` (bind di device non-Sunmi / service tidak tersedia), `SCANNER_ERROR`.
- Seluruh `Toast` di helper native dihapus — library tidak menampilkan UI; error dilaporkan lewat channel.
- Scanner receiver hanya teregistrasi saat ada subscriber pada `onBarcodeScanned` (di `onListen`), unregister di `onCancel` dan saat plugin detach. Kompatibel Android 13+ (`RECEIVER_NOT_EXPORTED`).

## Example App

Satu halaman demo di `example/`:
- Printer: tombol bind/unbind/init, print teks, custom text, QR, barcode, table, image, test print, transaksi buffer, info printer (model/versi/serial/paper).
- Scanner: tombol scan/stop, tampilan hasil barcode live dari stream, info model scanner.

Example app sekaligus sarana verifikasi manual di device Sunmi fisik.

## Testing

- **Unit test Dart** (`test/`): pakai `TestDefaultBinaryMessengerBinding` untuk mock `sunmi_utils/method` — verifikasi nama method & arguments per API, mapping enum→int, forwarding stream barcode dari `sunmi_utils/scan_events`, dan konversi error → `PlatformException`.
- **Native/hardware**: tidak di-unit-test; diverifikasi manual lewat example app di device Sunmi (dipegang user).
- `flutter analyze` bersih dengan `flutter_lints`; `dart pub publish --dry-run` lolos sebelum publish.

## Kesiapan pub.dev

- Dartdoc di semua API publik.
- README: deskripsi, daftar device/scanner yang didukung, setup, contoh kode scan & print, perilaku di device non-Sunmi, tabel error code.
- CHANGELOG dimulai dari `0.1.0`. LICENSE MIT.
- `pubspec.yaml`: description, `topics: [sunmi, printer, scanner, pos, barcode]`, `platforms: android`, field `repository` diisi URL repo Git (ditentukan saat publish).
- Folder `sunmi_utils` di-init sebagai git repo baru.

## Di Luar Scope (follow-up terpisah)

- Migrasi pos-mobile ke `sunmi_utils`: ganti pemakaian `SunmiScan`/`SunmiPrint`, sesuaikan nama enum, tambahkan `initPrinter()` eksplisit di titik yang dulu mengandalkan auto-init, hapus kode native Sunmi dari `MainActivity.kt`.
- Dukungan PayLib/payment Sunmi.
- Helper layout struk generik.
