import java.net.HttpURLConnection
import java.net.URI
import java.security.MessageDigest

plugins {
    base
}

// --- Project Configuration ---
val appVersion = "0.7.5"
// Build ID must match the GitHub release tag (e.g. 01505)
val buildId = "01506"

// The project root IS the rpmbuild root
val rpmBuildRoot = layout.projectDirectory
val downloadsDir = layout.buildDirectory.dir("downloads")

// Download configuration
data class Downloadable(val name: String, val url: String, val sha256: String)

val artifacts = listOf(
    // Hyphanet JARs and Signature
    Downloadable("freenet.jar", "https://github.com/hyphanet/fred/releases/download/build${buildId}/freenet-build${buildId}.jar", "e8f49d90e49886aa7d4b56d3aaf21cf41e2b862120782d3992c29679160b5c7a"),
    Downloadable("freenet.jar.sig", "https://github.com/hyphanet/fred/releases/download/build${buildId}/freenet-build${buildId}.jar.sig", "a611b164ac4ba0dd378be8de155e064653e370332f129050a5018db88d06dc62"),
    Downloadable("freenet-ext.jar", "https://github.com/hyphanet/fred/releases/download/build${buildId}/freenet-ext.jar", "32f2b3d6beedf54137ea2f9a3ebef67666d769f0966b08cd17fd7db59ba4d79f"),
    
    // Official Hyphanet Keyring for verification
    Downloadable("keyring.gpg", "https://www.hyphanet.org/assets/keyring.gpg", "e8a4afdc5eaf0f3b36955cf8df22368a8bd1eda3eb1d286735e777e721025998"),

    // Dependencies (Verified against verification-metadata.xml)
    Downloadable("bcprov.jar", "https://repo1.maven.org/maven2/org/bouncycastle/bcprov-jdk15on/1.59/bcprov-jdk15on-1.59.jar", "1c31e44e331d25e46d293b3e8ee2d07028a67db011e74cb2443285aed1d59c85"),
    Downloadable("jna.jar", "https://repo1.maven.org/maven2/net/java/dev/jna/jna/4.5.2/jna-4.5.2.jar", "0c8eb7acf67261656d79005191debaba3b6bf5dd60a43735a245429381dbecff"),
    Downloadable("jna-platform.jar", "https://repo1.maven.org/maven2/net/java/dev/jna/jna-platform/4.5.2/jna-platform-4.5.2.jar", "f1d00c167d8921c6e23c626ef9f1c3ae0be473c95c68ffa012bc7ae55a87e2d6"),
    Downloadable("pebble.jar", "https://repo1.maven.org/maven2/io/pebbletemplates/pebble/3.1.5/pebble-3.1.5.jar", "d253a6dde59e138698aaaaee546461d2f1f6c8bd2aa38ecdd347df17cf90d6f0"),
    Downloadable("unbescape.jar", "https://repo1.maven.org/maven2/org/unbescape/unbescape/1.1.6.RELEASE/unbescape-1.1.6.RELEASE.jar", "597cf87d5b1a4f385b9d1cec974b7b483abb3ee85fc5b3f8b62af8e4bec95c2c"),
    Downloadable("slf4j-api.jar", "https://repo1.maven.org/maven2/org/slf4j/slf4j-api/1.7.25/slf4j-api-1.7.25.jar", "18c4a0095d5c1da6b817592e767bb23d29dd2f560ad74df75ff3961dbde25b79"),

    // Wrapper (Using SourceForge mirror for reliability)
    Downloadable("wrapper.tar.gz", "https://sourceforge.net/projects/wrapper/files/wrapper_Wrapper_Source_Linux_x86-64_64/3.5.51/wrapper_linux_x86-64_3.5.51.tar.gz/download", "271571fcd630dc0fee14d102328c0a345ef96ef96711555bb6f5f5f7c42c489c"),

    // Seednodes
    Downloadable("seednodes.fref", "https://raw.githubusercontent.com/hyphanet/java_installer/refs/heads/next/offline/seednodes.fref", "1dc8da78a0062ae1796465c65f3b44e4277a06469c16921689fb2b7923281fff")
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
            
            if (!file.exists()) {
                println("Downloading ${artifact.name}...")
                val url = URI(artifact.url).toURL()
                val connection = url.openConnection() as HttpURLConnection
                connection.setRequestProperty("User-Agent", "Mozilla/5.0 (compatible; Gradle/1.0)")
                connection.setInstanceFollowRedirects(true)
                connection.connect()
                
                // Handle redirects manually if needed
                var responseCode = connection.responseCode
                var finalConnection = connection
                
                if (responseCode == HttpURLConnection.HTTP_MOVED_PERM || responseCode == HttpURLConnection.HTTP_MOVED_TEMP) {
                    val newUrl = connection.getHeaderField("Location")
                    finalConnection = URI(newUrl).toURL().openConnection() as HttpURLConnection
                    finalConnection.setRequestProperty("User-Agent", "Mozilla/5.0 (compatible; Gradle/1.0)")
                    finalConnection.connect()
                    responseCode = finalConnection.responseCode
                }

                if (responseCode != HttpURLConnection.HTTP_OK) {
                    throw GradleException("Failed to download ${artifact.name}: HTTP $responseCode ${finalConnection.responseMessage}")
                }

                finalConnection.inputStream.use { input ->
                    file.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
            }

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
    val keyringFile = downloadsDir.map { it.file("keyring.gpg") }
    
    // Use a temporary directory for GPG home to avoid system conflicts
    val gpgHome = layout.buildDirectory.dir("gpg-home").get().asFile
    
    doFirst {
        if (gpgHome.exists()) gpgHome.deleteRecursively()
        gpgHome.mkdirs()
        
        // Import the keyring into the temp home
        project.exec {
            commandLine("gpg", "--homedir", gpgHome.absolutePath, "--import", keyringFile.get().asFile.absolutePath)
            isIgnoreExitValue = true // Import might return non-zero if keys are already there or other warnings
        }
    }
    
    // Verify the signature
    commandLine(
        "gpg", 
        "--homedir", gpgHome.absolutePath,
        "--verify", sigFile.get().asFile.absolutePath, 
        jarFile.get().asFile.absolutePath
    )
    
    doLast {
        // Cleanup
        gpgHome.deleteRecursively()
    }
    
    onlyIf { jarFile.get().asFile.exists() && sigFile.get().asFile.exists() && keyringFile.get().asFile.exists() }
}

tasks.register<Exec>("prepareSources") {
    group = "rpm"
    description = "Prepares the source tarball using prepare_sources.sh"
    dependsOn("downloadAssets")
    // Enforce signature verification
    dependsOn("verifyJarSignature")

    doFirst {
        file("prepare_sources.sh").setExecutable(true)
        
        val root = rpmBuildRoot.asFile
        File(root, "SOURCES").mkdirs()
        File(root, "SPECS").mkdirs()
        File(root, "BUILD").mkdirs()
        File(root, "RPMS").mkdirs()
        File(root, "SRPMS").mkdirs()
    }

    commandLine("./prepare_sources.sh")
    
    environment("DOWNLOADS_DIR", downloadsDir.get().asFile.absolutePath)
    environment("APP_VERSION", appVersion)
    environment("BUILD_ID", buildId)
    environment("RPM_BUILD_ROOT", rpmBuildRoot.asFile.absolutePath)
    
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
        "org.hyphanet.service.policy",
        "org.hyphanet.hyphanet.metainfo.xml"
    )
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
        "--define", "version ${appVersion}",
        "--define", "build_id ${buildId}",
        // Force definition of _unitdir to ensure compatibility on all systems (including Ubuntu/GitHub Actions)
        "--define", "_unitdir /usr/lib/systemd/system",
        specFile.absolutePath
    )
    
    doLast {
        val targetDir = layout.projectDirectory.dir("RPMS/x86_64").asFile
        if (!targetDir.exists()) targetDir.mkdirs()

        val weirdRootDir = layout.projectDirectory.dir("RPMS.x86_64").asFile
        if (weirdRootDir.exists()) {
            weirdRootDir.listFiles()?.forEach { file ->
                val dest = File(targetDir, file.name)
                file.renameTo(dest)
            }
            weirdRootDir.deleteRecursively()
        }
    }
}

tasks.named("build") {
    dependsOn("buildRpm")
}

tasks.named("clean") {
    doLast {
        delete(layout.buildDirectory)
        delete(layout.projectDirectory.dir("RPMS"))
        delete(layout.projectDirectory.dir("RPMS.x86_64"))
        delete(layout.projectDirectory.dir("SOURCES"))
        delete(layout.projectDirectory.dir("BUILD"))
        delete(layout.projectDirectory.dir("BUILDROOT"))
        delete(layout.projectDirectory.dir("SRPMS"))
    }
}