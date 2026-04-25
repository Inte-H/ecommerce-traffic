import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    id("org.springframework.boot") version "4.0.0"
    id("io.spring.dependency-management") version "1.1.7"
    kotlin("jvm") version "2.2.20"
    kotlin("plugin.spring") version "2.2.20"
    id("nu.studer.jooq") version "9.0"
}

group = "com.ecommerce"
version = "0.0.1-SNAPSHOT"

// Toolchain은 JDK 25 (런타임/컴파일러 실행), 그러나 bytecode target은 24로 고정.
// 이유: Kotlin 2.2.20이 아직 JVM target 25 미지원. JDK 25의 핵심 이점
// (Virtual Threads, Compact Object Headers, Scoped Values)은 모두 런타임 기능이라
// bytecode target 24여도 JDK 25에서 실행할 때 그대로 누림.
java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(25)
    }
    sourceCompatibility = JavaVersion.VERSION_24
    targetCompatibility = JavaVersion.VERSION_24
}

repositories {
    mavenCentral()
}

dependencies {
    // Spring Boot
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("org.springframework.boot:spring-boot-starter-jooq")
    implementation("org.springframework.boot:spring-boot-starter-data-redis")
    implementation("org.redisson:redisson-spring-boot-starter:3.50.0")
    implementation("org.springframework.kafka:spring-kafka")

    // Kotlin
    implementation("com.fasterxml.jackson.module:jackson-module-kotlin")
    implementation("org.jetbrains.kotlin:kotlin-reflect")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-reactor")

    // Database
    implementation("org.postgresql:postgresql")
    implementation("com.zaxxer:HikariCP")

    // jOOQ
    jooqGenerator("org.postgresql:postgresql")

    // Monitoring
    implementation("io.micrometer:micrometer-registry-prometheus")

    // Test
    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.testcontainers:postgresql")
    testImplementation("org.testcontainers:kafka")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test")
}

// Spring Boot 4: Enable Virtual Threads (replaces spring.threads.virtual.enabled=true)
// Configured in application.yml

tasks.withType<KotlinCompile> {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_24)
        freeCompilerArgs.addAll("-Xjsr305=strict")
    }
}

tasks.withType<Test> {
    useJUnitPlatform()
}

jooq {
    version.set("3.19.15")
    configurations {
        create("main") {
            generateSchemaSourceOnCompilation.set(false)
            jooqConfiguration.apply {
                jdbc.apply {
                    driver = "org.postgresql.Driver"
                    url = "jdbc:postgresql://localhost:5432/ecommerce"
                    user = "user"
                    password = "password"
                }
                generator.apply {
                    name = "org.jooq.codegen.KotlinGenerator"
                    database.apply {
                        name = "org.jooq.meta.postgres.PostgresDatabase"
                        inputSchema = "public"
                    }
                    generate.apply {
                        isDeprecated = false
                        isRecords = true
                        isImmutablePojos = true
                        isFluentSetters = true
                    }
                    target.apply {
                        packageName = "com.ecommerce.jooq"
                        directory = "src/main/generated"
                    }
                }
            }
        }
    }
}
