plugins {
    base
}

val rpmBuildRoot = layout.projectDirectory.dir("rpmbuild")

tasks.register<Exec>("prepareSources") {
    group = "rpm"
    description = "Prepares the source tarball using prepare_sources.sh"
    
    // Ensure the script is executable
    doFirst {
        file("prepare_sources.sh").setExecutable(true)
    }

    commandLine("./prepare_sources.sh")
    
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
    
    outputs.dir(rpmBuildRoot.dir("SOURCES"))
}

tasks.register<Exec>("buildRpm") {
    group = "rpm"
    description = "Builds the RPM package using rpmbuild"
    dependsOn("prepareSources")

    val specFile = file("SPECS/hyphanet.spec")
    
    // Define the topdir for rpmbuild to keep everything inside the project
    val topDir = rpmBuildRoot.asFile.absolutePath
    
    commandLine(
        "/usr/bin/rpmbuild",
        "-ba",
        "--define", "_topdir ${topDir}",
        specFile.absolutePath
    )
    
    doLast {
        // Copy the final RPM to the root for easy access
        copy {
            from(rpmBuildRoot.dir("RPMS/x86_64"))
            into(layout.projectDirectory.dir("RPMS/x86_64"))
        }
    }
}

tasks.named("build") {
    dependsOn("buildRpm")
}

tasks.named("clean") {
    doLast {
        delete(rpmBuildRoot)
        delete(layout.projectDirectory.dir("RPMS"))
    }
}