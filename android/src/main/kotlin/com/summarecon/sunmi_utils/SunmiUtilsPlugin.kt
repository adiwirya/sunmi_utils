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
