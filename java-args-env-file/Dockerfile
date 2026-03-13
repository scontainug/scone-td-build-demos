# Use a multi-stage build for a small final image

# Stage 1: Build the Java app
FROM eclipse-temurin:17-jdk AS build
WORKDIR /app
COPY Main.java .
RUN javac Main.java

# Stage 2: Run with JRE only
FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /app/Main.class .
ENTRYPOINT ["/opt/java/openjdk/bin/java", "Main"]
