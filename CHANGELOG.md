## 1.0.0

- Verified on physical Sunmi hardware (V2s): scanner and printer both confirmed working.
- Fix: declare `woyou.aidlservice.jiuiv5` package visibility so the printer
  service can be found on Android 11+ (previously surfaced as `SERVICE_NOT_FOUND`
  even on genuine Sunmi hardware).
- Fix: `testPrint()` now flushes the print buffer explicitly, so it produces
  paper output on firmware that queues print jobs until committed.

## 0.1.0

- Initial release.
- `SunmiScanner`: scan/stop, scanner model, key events, barcode broadcast stream.
- `SunmiPrinter`: bind/init, printer info, text/custom text, alignment/font/bold,
  barcode, QR code, image, table, line wrap/feed paper, transaction buffer, test print.
