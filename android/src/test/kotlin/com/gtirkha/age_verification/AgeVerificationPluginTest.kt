package com.gtirkha.age_verification

import kotlin.test.Test
import kotlin.test.assertNotNull

// The plugin's only responsibility is wiring AgeVerificationApiImpl to the
// Pigeon binary messenger. Integration is verified by the example app;
// these unit tests guard the class structure.
class AgeVerificationPluginTest {

    @Test
    fun plugin_canBeInstantiated() {
        val plugin = AgeVerificationPlugin()
        assertNotNull(plugin)
    }
}
