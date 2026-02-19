import java.net.URI
import java.security.MessageDigest

plugins {
    base
}

val rpmBuildRoot = layout.projectDirectory.dir("rpmbuild")
val downloadsDir = layout.buildDirectory.dir("downloads")

// Configuration des téléchargements
data class Downloadable(val name: String, val url: String, val sha256: String)

val artifacts = listOf(
    // Hyphanet JARs and Signature
    Downloadable("freenet.jar", "https://github.com/hyphanet/fred/releases/download/build01505/freenet.jar", ""),
    Downloadable("freenet.jar.sig", "https://github.com/hyphanet/fred/releases/download/build01505/freenet-build01505.jar.sig", ""),
    Downloadable("freenet-ext.jar", "https://github.com/hyphanet/fred/releases/download/build01505/freenet-ext.jar", ""),

    // Dependencies
    Downloadable("bcprov.jar", "https://repo1.maven.org/maven2/org/bouncycastle/bcprov-jdk15on/1.59/bcprov-jdk15on-1.59.jar", "2537a509d48d686c8753029197e2530743a232e596c46976142456a532b53930"),
    Downloadable("jna.jar", "https://repo1.maven.org/maven2/net/java/dev/jna/jna/4.5.2/jna-4.5.2.jar", "e7d44528148b1d9366415276329495543972685a6f369d1343844697956b5d49"),
    Downloadable("jna-platform.jar", "https://repo1.maven.org/maven2/net/java/dev/jna/jna-platform/4.5.2/jna-platform-4.5.2.jar", "064434d6d205668b240e2e8966d486d348527e6a2c91d265a606c795b2c2b338"),
    Downloadable("pebble.jar", "https://repo1.maven.org/maven2/io/pebbletemplates/pebble/3.1.5/pebble-3.1.5.jar", "f264e9681878396913160d195799989182318c5585698e590401137b17a26c25"),
    Downloadable("unbescape.jar", "https://repo1.maven.org/maven2/org/unbescape/unbescape/1.1.6.RELEASE/unbescape-1.1.6.RELEASE.jar", "7b90360afb2b86024a558c8ea6894811065857255661d3876188b7617a4a9749"),
    Downloadable("slf4j-api.jar", "https://repo1.maven.org/maven2/org/slf4j/slf4j-api/1.7.25/slf4j-api-1.7.25.jar", "18c4a0095d5c1da6b814472412a81381759b645207231d299784df9a0619d051"),

    // Wrapper
    Downloadable("wrapper.tar.gz", "https://download.tanukisoftware.com/wrapper/3.5.51/wrapper-linux-x86-64-3.5.51.tar.gz", ""),

    // Seednodes
    Downloadable("seednodes.fref", "https://raw.githubusercontent.com/hyphanet/java_installer/refs/heads/next/offline/seednodes.fref", "")
)

tasks.register("downloadAssets") {
    group = "rpm"
    description = "Downloads and verifies external assets"
    
    val outputDir = downloadsDir.get().asFile
    outputs.dir(outputDir)

    doLast {
        if (!outputDir.exists()) outputDir.mkdirs()

        artifacts.forEach { artifact ->
            val file = File(outputDir, artifact.name)
            
            // 1. Download if missing
            if (!file.exists()) {
                println("Downloading ${artifact.name}...")
                val url = URI(artifact.url).toURL()
                url.openStream().use { input ->
                    file.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
            }

            // 2. Calculate Hash
            val digest = MessageDigest.getInstance("SHA-256")
            file.inputStream().use { input ->
                val buffer = ByteArray(8192)
                var bytesRead = input.read(buffer)
                while (bytesRead != -1) {
                    digest.update(buffer, 0, bytesRead)
                    bytesRead = input.read(buffer)
                }
            }
            val calculatedHash = digest.digest().joinToString("") { "%02x".format(it) }

            // 3. Verify Hash
            if (artifact.sha256.isNotEmpty()) {
                if (calculatedHash != artifact.sha256) {
                    throw GradleException("Checksum mismatch for ${artifact.name}!\nExpected: ${artifact.sha256}\nActual:   $calculatedHash\nPlease delete the file or update the hash in build.gradle.kts")
                }
            } else {
                println("WARNING: No hash provided for ${artifact.name}. Calculated hash: $calculatedHash")
            }
        }
    }
}

tasks.register<Exec>("verifyJarSignature") {
    group = "rpm"
    description = "Verifies the GPG signature of freenet.jar"
    dependsOn("downloadAssets")
    
    val jarFile = downloadsDir.map { it.file("freenet.jar") }
    val sigFile = downloadsDir.map { it.file("freenet.jar.sig") }
    
    // This task requires GPG to be installed and the Hyphanet key to be imported
    // We assume this is done in the CI environment or manually by the user
    commandLine("gpg", "--verify", sigFile.get().asFile.absolutePath, jarFile.get().asFile.absolutePath)
    
    // Only run if both files exist
    onlyIf { jarFile.get().asFile.exists() && sigFile.get().asFile.exists() }
}

tasks.register<Exec>("prepareSources") {
    group = "rpm"
    description = "Prepares the source tarball using prepare_sources.sh"
    dependsOn("downloadAssets")
    // Uncomment the following line to enforce signature verification before build
    // dependsOn("verifyJarSignature")
    
    // Ensure the script is executable
    doFirst {
        file("prepare_sources.sh").setExecutable(true)
    }

    commandLine("./prepare_sources.sh")
    
    // Pass the downloads directory to the script via Environment Variable
    environment("DOWNLOADS_DIR", downloadsDir.get().asFile.absolutePath)
    
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
    // Add downloaded files as inputs
    inputs.dir(downloadsDir)
    
    outputs.dir(rpmBuildRoot.dir("SOURCES"))
}

tasks.register<Exec>("buildRpm") {
    group = "rpm"
    description = "Builds the RPM package using rpmbuild"
    dependsOn("prepareSources")

    val specFile = file("SPECS/hyphanet.spec")
    val topDir = rpmBuildRoot.asFile.absolutePath
    
    commandLine(
        "/usr/bin/rpmbuild",
        "-ba",
        "--define", "_topdir ${topDir}",
        specFile.absolutePath
    )
    
    doLast {
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
        delete(downloadsDir)
    }
}