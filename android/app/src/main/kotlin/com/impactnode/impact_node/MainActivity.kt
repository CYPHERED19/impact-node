package com.impactnode.impact_node

import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.impactnode.sms/direct"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendSms") {
                val phone = call.argument<String>("phone")
                val msg = call.argument<String>("msg")

                if (phone != null && msg != null) {
                    try {
                        val smsManager: SmsManager = this.getSystemService(SmsManager::class.java)
                        smsManager.sendTextMessage(phone, null, msg, null, null)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SMS_FAILED", "Failed to send SMS: ${e.message}", null)
                    }
                } else {
                    result.error("INVALID_ARGS", "Phone or msg cannot be null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
