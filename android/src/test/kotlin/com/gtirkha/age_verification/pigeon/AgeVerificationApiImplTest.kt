package com.gtirkha.age_verification.pigeon

import android.content.Context
import com.google.android.play.agesignals.model.AgeRangeSource
import com.google.android.play.agesignals.model.AgeSignalsStatus
import com.google.android.play.agesignals.model.SignificantChangeStatus
import org.mockito.Mockito.mock
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class AgeVerificationApiImplTest {

    // A mock context is sufficient — the Context is only used inside initialize(),
    // so constructing AgeVerificationApiImpl never touches Android APIs.
    private val mockContext: Context = mock(Context::class.java)

    @Test
    fun verifyAge_beforeInitialize_returnsNotInitialisedError() {
        val impl = AgeVerificationApiImpl(mockContext) { null }

        var result: Result<AgeVerificationResult>? = null
        impl.verifyAge(ageGates = null, skipEligibilityCheck = false) { result = it }

        assertNotNull(result)
        assertTrue(result!!.isFailure)
        val error = assertIs<FlutterError>(result!!.exceptionOrNull())
        assertEquals("notInitialized", error.code)
    }

    @Test
    fun verifyAge_beforeInitialize_errorMessageMentionsInitialize() {
        val impl = AgeVerificationApiImpl(mockContext) { null }

        var result: Result<AgeVerificationResult>? = null
        impl.verifyAge(ageGates = null, skipEligibilityCheck = false) { result = it }

        val error = assertIs<FlutterError>(result!!.exceptionOrNull())
        assertTrue(
            error.message?.contains("initialize", ignoreCase = true) == true,
            "Error message should mention initialize()",
        )
    }

    @Test
    fun initialize_withMockContext_returnsInitError() {
        // In a JVM unit-test environment there are no Play Services, so
        // AgeSignalsManagerFactory.create(context) throws — the impl catches
        // it and wraps it as INIT_ERROR.
        val impl = AgeVerificationApiImpl(mockContext) { null }

        var result: Result<Unit>? = null
        impl.initialize(mockConfig = null) { result = it }

        assertNotNull(result)
        assertTrue(result!!.isFailure)
        val error = assertIs<FlutterError>(result!!.exceptionOrNull())
        assertEquals("initError", error.code)
    }

    @Test
    fun initialize_onError_detailsAreNull() {
        val impl = AgeVerificationApiImpl(mockContext) { null }

        var result: Result<Unit>? = null
        impl.initialize(mockConfig = null) { result = it }

        val error = assertIs<FlutterError>(result!!.exceptionOrNull())
        assertEquals(null, error.details)
    }

    @Test
    fun getApplicableAgeFeatures_beforeInitialize_returnsNotInitialisedError() {
        val impl = AgeVerificationApiImpl(mockContext) { null }

        var result: Result<List<ApplicableAgeFeature>>? = null
        impl.getApplicableAgeFeatures { result = it }

        val error = assertIs<FlutterError>(result!!.exceptionOrNull())
        assertEquals("notInitialized", error.code)
    }

    @Test
    fun requestAgeSignalsAccess_beforeInitialize_returnsNotInitialisedError() {
        val impl = AgeVerificationApiImpl(mockContext) { null }

        var result: Result<AgeSignalsAccessStatus>? = null
        impl.requestAgeSignalsAccess { result = it }

        val error = assertIs<FlutterError>(result!!.exceptionOrNull())
        assertEquals("notInitialized", error.code)
    }

    @Test
    fun requestAgeSignalsAccess_withoutActivity_returnsApiError() {
        val impl = AgeVerificationApiImpl(mockContext) { null }
        impl.initialize(AgeVerificationMockConfig(status = AgeVerificationStatus.VERIFIED)) {}

        var result: Result<AgeSignalsAccessStatus>? = null
        impl.requestAgeSignalsAccess { result = it }

        val error = assertIs<FlutterError>(result!!.exceptionOrNull())
        assertEquals("apiError", error.code)
        assertTrue(error.message?.contains("Activity") == true)
    }

    @Test
    fun mapStatus_mapsAgeRangeSourceTiers() {
        assertEquals(AgeVerificationStatus.DECLARED, AgeVerificationApiImpl.mapStatus(AgeRangeSource.TIER_A, null))
        assertEquals(AgeVerificationStatus.SUPERVISED, AgeVerificationApiImpl.mapStatus(AgeRangeSource.TIER_B, null))
        assertEquals(AgeVerificationStatus.VERIFIED, AgeVerificationApiImpl.mapStatus(AgeRangeSource.TIER_C, null))
        assertEquals(AgeVerificationStatus.VERIFIED, AgeVerificationApiImpl.mapStatus(AgeRangeSource.TIER_D, null))
        assertEquals(AgeVerificationStatus.UNKNOWN, AgeVerificationApiImpl.mapStatus(AgeRangeSource.UNSPECIFIED, null))
        assertEquals(AgeVerificationStatus.UNKNOWN, AgeVerificationApiImpl.mapStatus(null, null))
    }

    @Test
    fun mapStatus_significantChangeOverridesSource() {
        assertEquals(
            AgeVerificationStatus.SUPERVISED_APPROVAL_PENDING,
            AgeVerificationApiImpl.mapStatus(AgeRangeSource.TIER_B, SignificantChangeStatus.PENDING),
        )
        assertEquals(
            AgeVerificationStatus.SUPERVISED_APPROVAL_DENIED,
            AgeVerificationApiImpl.mapStatus(AgeRangeSource.TIER_B, SignificantChangeStatus.DECLINED),
        )
        assertEquals(
            AgeVerificationStatus.SUPERVISED,
            AgeVerificationApiImpl.mapStatus(AgeRangeSource.TIER_B, SignificantChangeStatus.APPROVED),
        )
    }

    @Test
    fun mapAccessStatus_mapsAllValues() {
        assertEquals(AgeSignalsAccessStatus.SHARED, AgeVerificationApiImpl.mapAccessStatus(AgeSignalsStatus.SHARED))
        assertEquals(AgeSignalsAccessStatus.NOT_SHARED, AgeVerificationApiImpl.mapAccessStatus(AgeSignalsStatus.NOT_SHARED))
        assertEquals(
            AgeSignalsAccessStatus.VERIFICATION_REQUIRED,
            AgeVerificationApiImpl.mapAccessStatus(AgeSignalsStatus.VERIFICATION_REQUIRED),
        )
        assertEquals(AgeSignalsAccessStatus.UNSPECIFIED, AgeVerificationApiImpl.mapAccessStatus(AgeSignalsStatus.UNSPECIFIED))
        assertEquals(AgeSignalsAccessStatus.UNSPECIFIED, AgeVerificationApiImpl.mapAccessStatus(null))
    }

    @Test
    fun dartName_matchesDartEnumNames() {
        // Must match AgeVerificationErrorCode.values.map((e) => e.name) in Dart.
        val expected = listOf(
            "apiNotAvailable", "playStoreNotFound", "networkError", "playServicesNotFound",
            "cannotBindToService", "playStoreVersionOutdated", "playServicesVersionOutdated",
            "clientTransientError", "appNotOwned", "sdkVersionOutdated", "deviceNotSupported",
            "internalError", "notInitialized", "initError", "apiError",
        )
        assertEquals(expected, AgeVerificationErrorCode.entries.map { it.dartName })
    }
}
