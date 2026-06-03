package com.gtirkha.age_verification.pigeon

import android.content.Context
import com.google.android.play.agesignals.AgeSignalsException
import com.google.android.play.agesignals.AgeSignalsManager
import com.google.android.play.agesignals.AgeSignalsManagerFactory
import com.google.android.play.agesignals.AgeSignalsRequest
import com.google.android.play.agesignals.model.AgeSignalsVerificationStatus

class AgeVerificationApiImpl(private val context: Context) : AgeVerificationApi {

    private var ageSignalsManager: AgeSignalsManager? = null
    private var mockConfig: AgeVerificationMockConfig? = null

    override fun initialize(mockConfig: AgeVerificationMockConfig?, callback: (Result<Unit>) -> Unit) {
        this.mockConfig = mockConfig
        if (mockConfig != null) {
            // Mock mode — skip real manager initialisation.
            callback(Result.success(Unit))
            return
        }
        try {
            ageSignalsManager = AgeSignalsManagerFactory.create(context)
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(
                Result.failure(
                    FlutterError(
                        AgeVerificationErrorCode.INIT_ERROR.name, e.message, null
                    )
                )
            )
        }
    }

    override fun verifyAge(
        ageGates: List<Long>?, callback: (Result<AgeVerificationResult>) -> Unit
    ) {
        val manager = ageSignalsManager
        if (manager == null) {
            callback(
                Result.failure(
                    FlutterError(
                        AgeVerificationErrorCode.NOT_INITIALISED.name,
                        "Age Signals API is not available. Call initialize() first.",
                        null,
                    )
                )
            )
            return
        }

        mockConfig?.let { mock ->
            callback(
                Result.success(
                    AgeVerificationResult(
                        status = mock.status,
                        ageLower = mock.ageLower,
                        ageUpper = mock.ageUpper,
                        source = mock.source,
                        installId = mock.installId,
                    )
                )
            )
            return
        }

        val request = AgeSignalsRequest.builder().build()

        manager.checkAgeSignals(request).addOnSuccessListener { ageSignalsResult ->
            val status = when (ageSignalsResult.userStatus()) {
                AgeSignalsVerificationStatus.VERIFIED -> AgeSignalsStatus.VERIFIED
                AgeSignalsVerificationStatus.SUPERVISED -> AgeSignalsStatus.SUPERVISED
                AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_PENDING -> AgeSignalsStatus.SUPERVISED_APPROVAL_PENDING
                AgeSignalsVerificationStatus.SUPERVISED_APPROVAL_DENIED -> AgeSignalsStatus.SUPERVISED_APPROVAL_DENIED
                AgeSignalsVerificationStatus.DECLARED -> AgeSignalsStatus.DECLARED
                else -> AgeSignalsStatus.UNKNOWN
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
                    -1 -> AgeVerificationErrorCode.API_NOT_AVAILABLE
                    -2 -> AgeVerificationErrorCode.PLAY_SERVICES_ERROR
                    -3 -> AgeVerificationErrorCode.NETWORK_ERROR
                    -4, -5, -6, -7 -> AgeVerificationErrorCode.PLAY_SERVICES_ERROR
                    -8 -> AgeVerificationErrorCode.API_ERROR
                    -9 -> AgeVerificationErrorCode.API_NOT_AVAILABLE
                    -10 -> AgeVerificationErrorCode.SDK_VERSION_OUTDATED
                    -100 -> AgeVerificationErrorCode.API_ERROR
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
