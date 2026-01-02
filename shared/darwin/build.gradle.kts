plugins {
    alias(libs.plugins.kotlin.multiplatform)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.touchlab.skie)
}

kotlin {
    // macOS targets for Swift interop
    listOf(macosArm64(), macosX64()).forEach { target ->
        target.binaries.framework {
            baseName = "ClaudeBarShared"
            export(projects.domain)
            export(projects.infrastructure)
            isStatic = true
        }
    }

    sourceSets {
        commonMain {
            dependencies {
                api(projects.domain)
                api(projects.infrastructure)
            }
        }
    }
}
