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
