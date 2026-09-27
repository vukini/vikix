# Java

One of the most used languages anywhere: large programs built from
classes and interfaces, a huge standard library, and a fast runtime (the
JVM) that also runs Kotlin, Scala and Clojure.

## On this machine

<!-- tools -->

- More than one Java installed? `xbps-alternatives -l -g jdk` (the compiler and tools) and `-g java` (the runtime) list them; `sudo xbps-alternatives -s openjdk21` and `sudo xbps-alternatives -s openjdk21-jre` make 21 the one you get
- Offline docs: Zeal's Java docset
- Examples: `~/dev/java/examples/` (`make run` in each; Gradle's first build takes a while)

## Where to start

1. `jshell`, trying lines as you read the first part of dev.java/learn.
2. `examples/hello`, then `java Hello.java`: one file, no build.
3. The University of Helsinki's Java MOOC, or Think Java, with their exercises.
4. `examples/shapes`: records, interfaces and sealed types.

## Online

- Learn and news: https://dev.java/ (https://dev.java/learn/)
- OpenJDK, the open source Java: https://openjdk.org/ (source: https://github.com/openjdk/jdk)
- The standard library (Java 21): https://docs.oracle.com/en/java/javase/21/docs/api/
- Libraries (Maven Central): https://central.sonatype.com/
- Gradle: https://docs.gradle.org/

## Free books and courses

- Java Programming MOOC (University of Helsinki) — https://java-programming.mooc.fi/
- Think Java — https://greenteapress.com/wp/think-java-2e/
- Introduction to Programming Using Java, by David Eck — https://math.hws.edu/javanotes/
