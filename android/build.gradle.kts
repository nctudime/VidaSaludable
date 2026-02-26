allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Workaround for plugins without namespace (AGP 8+ requirement)
// Ensures third-party Android library modules define a namespace to avoid build failures.
plugins.withId("com.android.application") {
    // no-op, just to ensure Android Gradle Plugin is available
}
subprojects {
    plugins.withId("com.android.library") {
        // Configure the Android library extension if the plugin didn't set a namespace.
        extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
            if (namespace == null || namespace!!.isBlank()) {
                val manifest = file("src/main/AndroidManifest.xml")
                val pkg = if (manifest.exists()) {
                    val text = manifest.readText()
                    Regex("package=\\\"([^\\\"]+)\\\"").find(text)?.groupValues?.getOrNull(1)
                } else null
                namespace = (pkg ?: "fix.${project.name.replace('-', '_')}")
            }
        }
    }
}
