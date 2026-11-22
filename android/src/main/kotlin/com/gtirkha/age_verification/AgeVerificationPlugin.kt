package com.gtirkha.age_verification

import android.app.Activity
import com.gtirkha.age_verification.pigeon.AgeVerificationApi
import com.gtirkha.age_verification.pigeon.AgeVerificationApiImpl
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/** AgeVerificationPlugin */
class AgeVerificationPlugin : FlutterPlugin, ActivityAware {
    private var api: AgeVerificationApi? = null

    // requestAgeSignalsAccess() shows a Play prompt, which needs the host Activity.
    private var activity: Activity? = null

    override fun onAttachedToEngine(p0: FlutterPlugin.FlutterPluginBinding) {
        api = AgeVerificationApiImpl(p0.applicationContext) { activity }
        AgeVerificationApi.setUp(binaryMessenger = p0.binaryMessenger, api)
    }

    override fun onDetachedFromEngine(p0: FlutterPlugin.FlutterPluginBinding) {
        api = null
        AgeVerificationApi.setUp(binaryMessenger = p0.binaryMessenger, api)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}
