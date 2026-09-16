package com.adiwirya.sunmi_utils

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
        // Some firmware queues print jobs until a buffer commit — flush explicitly
        // instead of relying on lineWrap/autoOutPaper alone.
        s.commitPrinterBuffer()
        feedPaper()
    }

    companion object {
        // ESC/POS commands, taken from pos-mobile's ESCUtil (the only 4 used).
        private val ESC_BOLD_ON = byteArrayOf(0x1B, 69, 0x0F)
        private val ESC_BOLD_OFF = byteArrayOf(0x1B, 69, 0)
        private val ESC_UNDERLINE_ON = byteArrayOf(0x1B, 45, 1)
        private val ESC_UNDERLINE_OFF = byteArrayOf(0x1B, 45, 0)
    }
}
