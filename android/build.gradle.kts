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

subprojects {
    afterEvaluate { project ->
        if (project.hasProperty("android")) {
            val androidExtension = project.extensions.findByName("android")
            if (androidExtension != null) {
                try {
                    val method = androidExtension.javaClass.getMethod("setCompileSdkVersion", Int::class.java)
                    method.invoke(androidExtension, 36)
                } catch (e: Exception) {
                    try {
                        val method = androidExtension.javaClass.getMethod("compileSdk", Int::class.java)
                        method.invoke(androidExtension, 36)
                    } catch (ignored: Exception) {}
                }
            }
        }
    }
}
