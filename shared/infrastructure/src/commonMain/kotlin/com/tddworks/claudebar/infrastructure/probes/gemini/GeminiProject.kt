package com.tddworks.claudebar.infrastructure.probes.gemini

import kotlinx.serialization.Serializable

@Serializable
internal data class GeminiProject(
    val projectId: String,
    val labels: Map<String, String>? = null
) {
    val isCLIProject: Boolean
        get() = projectId.startsWith("gen-lang-client")

    val hasGenerativeLanguageLabel: Boolean
        get() = labels?.containsKey("generative-language") == true
}

@Serializable
internal data class GeminiProjects(
    val projects: List<GeminiProject>
) {
    val bestProjectForQuota: GeminiProject?
        get() {
            // Prefer CLI-created projects
            val cliProject = projects.firstOrNull { it.isCLIProject }
            if (cliProject != null) return cliProject

            // Fallback to any project with the generative-language label
            return projects.firstOrNull { it.hasGenerativeLanguageLabel }
        }
}
