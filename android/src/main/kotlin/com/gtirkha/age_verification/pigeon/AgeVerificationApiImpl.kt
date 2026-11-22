package com.gtirkha.age_verification.pigeon

import android.app.Activity
import android.content.Context
import com.google.android.play.agesignals.AgeSignalsAccessRequest
import com.google.android.play.agesignals.AgeSignalsAccessResult
import com.google.android.play.agesignals.AgeSignalsException
import com.google.android.play.agesignals.AgeSignalsManager
import com.google.android.play.agesignals.AgeSignalsManagerFactory
import com.google.android.play.agesignals.AgeSignalsRequest
import com.google.android.play.agesignals.AgeSignalsResult
import com.google.android.play.agesignals.ApplicableAgeFeaturesRequest
import com.google.android.play.agesignals.ApplicableAgeFeaturesResult
import com.google.android.play.agesignals.model.AgeRangeSource
import com.google.android.play.agesignals.model.AgeSignalsErrorCode
import com.google.android.play.agesignals.model.AgeSignalsStatus
import com.google.android.play.agesignals.model.SignificantChangeStatus
import com.google.android.play.agesignals.testing.FakeAgeSignalsManager
import com.google.android.play.agesignals.model.ApplicableAgeFeature as PlayApplicableAgeFeature

class AgeVerificationApiImpl(
    private val context: Context,
    private val activityProvider: () -> Activity?,
) : AgeVerificationApi {

    private var ageSignalsManager: AgeSignalsManager? = null
    private var mockConfig: AgeVerificationMockConfig? = null

    override fun initialize(
        mockConfig: AgeVerificationMockConfig?, callback: (Result<Unit>) -> Unit
    ) {
        this.mockConfig = mockConfig
        if (mockConfig != null) {
            // Mock mode — real manager not needed; a FakeAgeSignalsManager is created per call.
            callback(Result.success(Unit))
            return
        }
        try {
            ageSignalsManager = AgeSignalsManagerFactory.create(context)
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(initError(e)))
        } catch (e: LinkageError) {
            // e.g. ExceptionInInitializerError / NoClassDefFoundError when the Play
            // library can't load — report it instead of crashing the host app.
            callback(Result.failure(initError(e)))
        }
    }

    private fun initError(e: Throwable) =
        FlutterError(AgeVerificationErrorCode.INIT_ERROR.name, e.message, null)

    override fun verifyAge(
        ageGates: List<Long>?,
        skipEligibilityCheck: Boolean,
        callback: (Result<AgeVerificationResult>) -> Unit
    ) {
        val manager = resolveManager(callback) ?: return

        manager.checkAgeSignals(AgeSignalsRequest.builder().build())
            .addOnSuccessListener { ageSignalsResult ->
                callback(
                    Result.success(
                        AgeVerificationResult(
                            status = mapStatus(
                                ageSignalsResult.ageRangeSource(),
                                ageSignalsResult.significantChangeStatus(),
                            ),
                            ageLower = ageSignalsResult.ageLower()?.toLong(),
                            ageUpper = ageSignalsResult.ageUpper()?.toLong(),
                            source = null,
                            installId = ageSignalsResult.installId(),
                        )
                    )
                )
            }
            .addOnFailureListener { callback(Result.failure(toFlutterError(it))) }
    }

    override fun getApplicableAgeFeatures(callback: (Result<List<ApplicableAgeFeature>>) -> Unit) {
        val manager = resolveManager(callback) ?: return

        manager.getApplicableAgeFeatures(ApplicableAgeFeaturesRequest.builder().build())
            .addOnSuccessListener { result ->
                val features = result.features().orEmpty().mapNotNull { feature ->
                    when (feature) {
                        PlayApplicableAgeFeature.MANDATORY_SHARING -> ApplicableAgeFeature.MANDATORY_SHARING
                        else -> null
                    }
                }
                callback(Result.success(features))
            }
            .addOnFailureListener { callback(Result.failure(toFlutterError(it))) }
    }

    override fun requestAgeSignalsAccess(callback: (Result<AgeSignalsAccessStatus>) -> Unit) {
        val manager = resolveManager(callback) ?: return

        val activity = activityProvider()
        if (activity == null) {
            callback(
                Result.failure(
                    FlutterError(
                        AgeVerificationErrorCode.API_ERROR.name,
                        "requestAgeSignalsAccess() needs a foreground Activity, but the plugin is not attached to one.",
                        null,
                    )
                )
            )
            return
        }

        val request = AgeSignalsAccessRequest.builder().setActivity(activity).build()
        manager.requestAgeSignalsAccess(request)
            .addOnSuccessListener { result ->
                callback(Result.success(mapAccessStatus(result.ageSignalsStatus())))
            }
            .addOnFailureListener { callback(Result.failure(toFlutterError(it))) }
    }

    /**
     * Returns the manager to call: a [FakeAgeSignalsManager] primed from [mockConfig]
     * in mock mode (so mock results go through the same mapping as production),
     * otherwise the real manager. Reports `NOT_INITIALIZED` and returns null if
     * [initialize] hasn't run.
     */
    private fun <T> resolveManager(callback: (Result<T>) -> Unit): AgeSignalsManager? {
        val mock = mockConfig
        if (mock != null) return buildFakeManager(mock)

        return ageSignalsManager ?: run {
            callback(
                Result.failure(
                    FlutterError(
                        AgeVerificationErrorCode.NOT_INITIALIZED.name,
                        "Age Signals API is not available. Call initialize() first.",
                        null,
                    )
                )
            )
            null
        }
    }

    private fun buildFakeManager(mock: AgeVerificationMockConfig): FakeAgeSignalsManager {
        // age-signals 0.0.4+ removed userStatus; encode the mocked status as
        // the ageRangeSource / significantChangeStatus pair that maps back to it.
        val (fakeSource, fakeChange) = when (mock.status) {
            AgeVerificationStatus.VERIFIED -> AgeRangeSource.TIER_C to null
            AgeVerificationStatus.SUPERVISED -> AgeRangeSource.TIER_B to SignificantChangeStatus.APPROVED
            AgeVerificationStatus.SUPERVISED_APPROVAL_PENDING -> AgeRangeSource.TIER_B to SignificantChangeStatus.PENDING
            AgeVerificationStatus.SUPERVISED_APPROVAL_DENIED -> AgeRangeSource.TIER_B to SignificantChangeStatus.DECLINED
            AgeVerificationStatus.DECLARED -> AgeRangeSource.TIER_A to null
            else -> null to null
        }

        val fakeResult = AgeSignalsResult.builder().apply {
            fakeSource?.let { setAgeRangeSource(it) }
            fakeChange?.let { setSignificantChangeStatus(it) }
            mock.ageLower?.let { setAgeLower(it.toInt()) }
            mock.ageUpper?.let { setAgeUpper(it.toInt()) }
            mock.installId?.let { setInstallId(it) }
        }.build()

        val fakeAccessStatus = when (mock.accessStatus ?: AgeSignalsAccessStatus.SHARED) {
            AgeSignalsAccessStatus.UNSPECIFIED -> AgeSignalsStatus.UNSPECIFIED
            AgeSignalsAccessStatus.SHARED -> AgeSignalsStatus.SHARED
            AgeSignalsAccessStatus.NOT_SHARED -> AgeSignalsStatus.NOT_SHARED
            AgeSignalsAccessStatus.VERIFICATION_REQUIRED -> AgeSignalsStatus.VERIFICATION_REQUIRED
        }

        val fakeFeatures = mock.applicableAgeFeatures.orEmpty().map {
            when (it) {
                ApplicableAgeFeature.MANDATORY_SHARING -> PlayApplicableAgeFeature.MANDATORY_SHARING
            }
        }.toSet()

        return FakeAgeSignalsManager().apply {
            setNextAgeSignalsResult(fakeResult)
            setNextAgeSignalsAccessResult(
                AgeSignalsAccessResult.builder().setAgeSignalsStatus(fakeAccessStatus).build()
            )
            setNextApplicableAgeFeaturesResult(
                ApplicableAgeFeaturesResult.builder().setFeatures(fakeFeatures).build()
            )
        }
    }

    companion object {
        /**
         * Derives the plugin's [AgeVerificationStatus] from the age-signals 0.0.4+
         * fields that replaced the removed `userStatus()`.
         *
         * - A pending/declined significant change wins: the user is supervised and
         *   the guardian hasn't approved / has denied it.
         * - TIER_B: age is managed by a parent or guardian.
         * - TIER_C / TIER_D: age was checked (credit card, ID, selfie, Digital ID…).
         * - TIER_A: the user provided their age to Google themselves.
         * - null / UNSPECIFIED: no signal shared.
         */
        internal fun mapStatus(ageRangeSource: Int?, significantChangeStatus: Int?): AgeVerificationStatus {
            when (significantChangeStatus) {
                SignificantChangeStatus.PENDING -> return AgeVerificationStatus.SUPERVISED_APPROVAL_PENDING
                SignificantChangeStatus.DECLINED -> return AgeVerificationStatus.SUPERVISED_APPROVAL_DENIED
            }
            return when (ageRangeSource) {
                AgeRangeSource.TIER_B -> AgeVerificationStatus.SUPERVISED
                AgeRangeSource.TIER_C, AgeRangeSource.TIER_D -> AgeVerificationStatus.VERIFIED
                AgeRangeSource.TIER_A -> AgeVerificationStatus.DECLARED
                else -> AgeVerificationStatus.UNKNOWN
            }
        }

        internal fun mapAccessStatus(ageSignalsStatus: Int?): AgeSignalsAccessStatus =
            when (ageSignalsStatus) {
                AgeSignalsStatus.SHARED -> AgeSignalsAccessStatus.SHARED
                AgeSignalsStatus.NOT_SHARED -> AgeSignalsAccessStatus.NOT_SHARED
                AgeSignalsStatus.VERIFICATION_REQUIRED -> AgeSignalsAccessStatus.VERIFICATION_REQUIRED
                else -> AgeSignalsAccessStatus.UNSPECIFIED
            }

        internal fun toFlutterError(exception: Exception): FlutterError {
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
                    AgeSignalsErrorCode.DEVICE_NOT_SUPPORTED -> AgeVerificationErrorCode.DEVICE_NOT_SUPPORTED
                    AgeSignalsErrorCode.INTERNAL_ERROR -> AgeVerificationErrorCode.INTERNAL_ERROR
                    else -> AgeVerificationErrorCode.API_ERROR
                }
            } else {
                AgeVerificationErrorCode.API_ERROR
            }

            return FlutterError(
                errorCode.name,
                exception.message,
                "Exception type: ${exception.javaClass.simpleName}",
            )
        }
    }
}
