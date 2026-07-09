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
