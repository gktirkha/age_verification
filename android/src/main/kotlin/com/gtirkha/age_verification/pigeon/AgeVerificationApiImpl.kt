package com.gtirkha.age_verification.pigeon

import android.content.Context
import com.google.android.play.agesignals.AgeSignalsException
import com.google.android.play.agesignals.AgeSignalsManager
import com.google.android.play.agesignals.AgeSignalsManagerFactory
import com.google.android.play.agesignals.AgeSignalsRequest
import com.google.android.play.agesignals.AgeSignalsResult
import com.google.android.play.agesignals.model.AgeSignalsErrorCode
import com.google.android.play.agesignals.model.AgeSignalsVerificationStatus
import com.google.android.play.agesignals.testing.FakeAgeSignalsManager

class AgeVerificationApiImpl(private val context: Context) : AgeVerificationApi {

    private var ageSignalsManager: AgeSignalsManager? = null
    private var mockConfig: AgeVerificationMockConfig? = null

    override fun initialize(
        mockConfig: AgeVerificationMockConfig?, callback: (Result<Unit>) -> Unit
    ) {
        this.mockConfig = mockConfig
        if (mockConfig != null) {
            // Mock mode — real manager not needed; FakeAgeSignalsManager is created per verifyAge call.
            callback(Result.success(Unit))
            return
        }
        try {
            ageSignalsManager = AgeSignalsManagerFactory.create(context)
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(
                Result.failure(
                    FlutterError(AgeVerificationErrorCode.INIT_ERROR.name, e.message, null)
                )
            )
        }
    }

    override fun verifyAge(
        ageGates: List<Long>?,
        skipEligibilityCheck: Boolean,
        callback: (Result<AgeVerificationResult>) -> Unit
    ) {
        val manager: AgeSignalsManager

        val mock = mockConfig
        if (mock != null) {
            // Build a FakeAgeSignalsManager so the result goes through the same
            // checkAgeSignals → addOnSuccessListener path as real production code.
            val fakeStatus = when (mock.status) {
                AgeVerificationStatus.VERIFIED -> AgeSignalsVerificationStatus.VERIFIED
                AgeVerificationStatus.SUPERVISED -> AgeSignalsVerificationStatus.SUPERVISED
                AgeVerificationStatus.SUPERVISED_APPROVAL_PENDING -> AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_PENDING
                AgeVerificationStatus.SUPERVISED_APPROVAL_DENIED -> AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_DENIED
                AgeVerificationStatus.DECLARED -> AgeSignalsVerificationStatus.DECLARED
                else -> AgeSignalsVerificationStatus.UNKNOWN
            }

            val fakeResult = AgeSignalsResult.builder().setUserStatus(fakeStatus).apply {
                mock.ageLower?.let { setAgeLower(it.toInt()) }
                mock.ageUpper?.let { setAgeUpper(it.toInt()) }
                mock.installId?.let { setInstallId(it) }
            }.build()

            val fakeManager = FakeAgeSignalsManager()
            fakeManager.setNextAgeSignalsResult(fakeResult)
            manager = fakeManager
        } else {
            val realManager = ageSignalsManager
            if (realManager == null) {
                callback(
                    Result.failure(
                        FlutterError(
                            AgeVerificationErrorCode.NOT_INITIALIZED.name,
                            "Age Signals API is not available. Call initialize() first.",
                            null,
                        )
                    )
                )
                return
            }
            manager = realManager
        }

        val request = AgeSignalsRequest.builder().build()

        manager.checkAgeSignals(request).addOnSuccessListener { ageSignalsResult ->
            val status = when (ageSignalsResult.userStatus()) {
                AgeSignalsVerificationStatus.VERIFIED -> AgeVerificationStatus.VERIFIED
                AgeSignalsVerificationStatus.SUPERVISED -> AgeVerificationStatus.SUPERVISED
                AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_PENDING -> AgeVerificationStatus.SUPERVISED_APPROVAL_PENDING
                AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_DENIED -> AgeVerificationStatus.SUPERVISED_APPROVAL_DENIED
                AgeSignalsVerificationStatus.DECLARED -> AgeVerificationStatus.DECLARED
                else -> AgeVerificationStatus.UNKNOWN
            }

            callback(
                Result.success(
                    AgeVerificationResult(
                        status = status,
                        ageLower = ageSignalsResult.ageLower()?.toLong(),
                        ageUpper = ageSignalsResult.ageUpper()?.toLong(),
                        source = null,
                        installId = ageSignalsResult.installId(),
                    )
                )
            )
        }.addOnFailureListener { exception ->
            val errorCode = if (exception is AgeSignalsException) {
                when (exception.errorCode) {
                    AgeSignalsErrorCode.API_NOT_AVAILABLE -> AgeVerificationErrorCode.API_NOT_AVAILABLE
                    AgeSignalsErrorCode.PLAY_STORE_NOT_FOUND -> AgeVerificationErrorCode.PLAY_STORE_NOT_FOUND
                    AgeSignalsErrorCode.NETWORK_ERROR -> AgeVerificationErrorCode.NETWORK_ERROR
                    AgeSignalsErrorCode.PLAY_SERVICES_NOT_FOUND -> AgeVerificationErrorCode.PLAY_SERVICES_NOT_FOUND
                    AgeSignalsErrorCode.CANNOT_BIND_TO_SERVICE -> AgeVerificationErrorCode.CANNOT_BIND_TO_SERVICE
                    AgeSignalsErrorCode.PLAY_STORE_VERSION_OUTDATED -> AgeVerificationErrorCode.PLAY_STORE_VERSION_OUTDATED
                    AgeSignalsErrorCode.PLAY_SERVICES_VERSION_OUTDATED -> AgeVerificationErrorCode.PLAY_SERVICES_VERSION_OUTDATED
                    AgeSignalsErrorCode.CLIENT_TRANSIENT_ERROR -> AgeVerificationErrorCode.CLIENT_TRANSIENT_ERROR
                    AgeSignalsErrorCode.APP_NOT_OWNED -> AgeVerificationErrorCode.APP_NOT_OWNED
                    AgeSignalsErrorCode.SDK_VERSION_OUTDATED -> AgeVerificationErrorCode.SDK_VERSION_OUTDATED
                    AgeSignalsErrorCode.INTERNAL_ERROR -> AgeVerificationErrorCode.INTERNAL_ERROR
                    else -> AgeVerificationErrorCode.API_ERROR
                }
            } else {
                AgeVerificationErrorCode.API_ERROR
            }.name

            callback(
                Result.failure(
                    FlutterError(
                        errorCode,
                        exception.message,
                        "Exception type: ${exception.javaClass.simpleName}",
                    )
                )
            )
        }
    }

}
