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

    // CameraX 1.5.x declares concurrent-futures as runtime-only, but its compiled
    // classes carry JSpecify annotations that need it on the compile classpath.
    // Gradle 9 no longer promotes runtime deps, so add it explicitly to every
    // Android module (including plugins) to avoid javac failures.
    listOf("com.android.application", "com.android.library").forEach { pluginId ->
        pluginManager.withPlugin(pluginId) {
            dependencies.add("implementation", "androidx.concurrent:concurrent-futures:1.2.0")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
