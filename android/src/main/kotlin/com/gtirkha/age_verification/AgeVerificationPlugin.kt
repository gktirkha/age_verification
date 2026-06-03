package com.gtirkha.age_verification

import com.gtirkha.age_verification.pigeon.AgeVerificationApi
import com.gtirkha.age_verification.pigeon.AgeVerificationApiImpl
import io.flutter.embedding.engine.plugins.FlutterPlugin

/** AgeVerificationPlugin */
class AgeVerificationPlugin : FlutterPlugin {
    private var api: AgeVerificationApi? = null

    override fun onAttachedToEngine(p0: FlutterPlugin.FlutterPluginBinding) {
        api = AgeVerificationApiImpl(p0.applicationContext)
        AgeVerificationApi.setUp(binaryMessenger = p0.binaryMessenger, api)
    }

    override fun onDetachedFromEngine(p0: FlutterPlugin.FlutterPluginBinding) {
        api = null
        AgeVerificationApi.setUp(binaryMessenger = p0.binaryMessenger, api)
    }
}
