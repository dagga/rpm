plugins {
    base
}

val rpmBuildDir = layout.buildDirectory.dir("rpmbuild")
val sourcesDir = rpmBuildDir.map { it.dir("SOURCES") }
val specsDir = rpmBuildDir.map { it.dir("SPECS") }
val rpmsDir = rpmBuildDir.map { it.dir("RPMS") }
val srpmsDir = rpmBuildDir.map { it.dir("SRPMS") }
val buildDir = rpmBuildDir.map { it.dir("BUILD") }

tasks.register<Exec>("prepareSources") {
    group = "rpm"
    description = "Prepares the source tarball using prepare_sources.sh"
    
    // Ensure the script is executable
    doFirst {
        file("prepare_sources.sh").setExecutable(true)
    }

    commandLine("./prepare_sources.sh")
    
    // Define inputs and outputs for incremental build support
    inputs.files(
        "prepare_sources.sh",
        "wrapper.conf",
        "freenet.ini",
        "hyphanet-service",
        "hyphanet.service",
        "hyphanet.sysusers",
        "hyphanet.desktop",
        "hyphanet-start.desktop",
        "hyphanet-stop.desktop",
        "hyphanet.png",
        "org.hyphanet.service.policy"
    )
    
    // The script puts the tarball in ~/rpmbuild/SOURCES by default, 
    // we might want to change that or just track it.
    // For now, let's assume the script uses the default location.
}

tasks.register<Exec>("buildRpm") {
    group = "rpm"
    description = "Builds the RPM package using rpmbuild"
    dependsOn("prepareSources")

    val specFile = file("SPECS/hyphanet.spec")
    
    commandLine("rpmbuild", "-ba", specFile.absolutePath)
}

tasks.named("build") {
    dependsOn("buildRpm")
}

tasks.named("clean") {
    doLast {
        delete(layout.buildDirectory)
        // Also clean up the default rpmbuild directory if needed, 
        // but be careful not to delete user's other RPMs.
    }
}