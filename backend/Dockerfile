# Eclipse Temurin (Alpine), JDK only where we actually compile
FROM docker.io/library/eclipse-temurin:26-jdk-alpine@sha256:8b7a8c567ddf2ea80020d175f83879ebedc0cc631040a5d4dc6a12a0cb8ec5e6 AS build

# Set the working directory
WORKDIR /app

# Copy the Maven wrapper, project configuration, and source files
COPY ./.mvn /app/.mvn
COPY ./mvnw /app/mvnw
COPY ./pom.xml /app/pom.xml
COPY ./src /app/src

# Build the application
RUN chmod +x /app/mvnw && /app/mvnw clean package -Dmaven.test.skip=true

# Runtime only needs a JRE, not the full JDK the build stage used
FROM docker.io/library/eclipse-temurin:26-jre-alpine@sha256:9eedff2367194d11eddd6f14101b444945a708c986270cd5716b934596ba3a31

# Set the working directory
WORKDIR /app

# Copy the built JAR file from the previous stage
COPY --from=build /app/target/*.jar app.jar

# Expose the port on which the Spring Boot application will run
EXPOSE 8080

# Command to run the application
CMD ["java", "-jar", "app.jar"]
