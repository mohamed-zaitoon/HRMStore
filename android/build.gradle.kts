// Open-source code. Copyright Mohamed Zaitoon 2025-2026.
import org.gradle.api.tasks.compile.JavaCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
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

subprojects {
    tasks.withType<JavaCompile>().configureEach {
        options.isWarnings = false
        options.isDeprecation = false
        options.compilerArgs.addAll(
            listOf(
                "-nowarn",
                "-Xlint:-options",
                "-Xlint:-unchecked",
                "-Xlint:-deprecation"
            )
        )
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
