package com.gtirkha.age_verification.pigeon

import android.content.Context
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
        val impl = AgeVerificationApiImpl(mockContext)

        var result: Result<AgeVerificationResult>? = null
        impl.verifyAge(ageGates = null) { result = it }

        assertNotNull(result)
        assertTrue(result!!.isFailure)
        val error = assertIs<FlutterError>(result!!.exceptionOrNull())
        assertEquals(AgeVerificationErrorCode.NOT_INITIALISED.name, error.code)
    }

    @Test
    fun verifyAge_beforeInitialize_errorMessageMentionsInitialize() {
        val impl = AgeVerificationApiImpl(mockContext)

        var result: Result<AgeVerificationResult>? = null
        impl.verifyAge(ageGates = null) { result = it }

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
        val impl = AgeVerificationApiImpl(mockContext)

        var result: Result<Unit>? = null
        impl.initialize { result = it }

        assertNotNull(result)
        assertTrue(result!!.isFailure)
        val error = assertIs<FlutterError>(result!!.exceptionOrNull())
        assertEquals(AgeVerificationErrorCode.INIT_ERROR.name, error.code)
    }

    @Test
    fun initialize_onError_detailsAreNull() {
        val impl = AgeVerificationApiImpl(mockContext)

        var result: Result<Unit>? = null
        impl.initialize { result = it }

        val error = assertIs<FlutterError>(result!!.exceptionOrNull())
        assertEquals(null, error.details)
    }
}
