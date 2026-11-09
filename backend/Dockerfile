# Eclipse Temurin (Alpine), JDK only where we actually compile
FROM docker.io/library/eclipse-temurin:27-jdk-alpine@sha256:8b32b7f44f8752d9aaa0a58d2fb8d679aa719083f8f0c2d9bd90eb35f2fc149d AS build

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
FROM docker.io/library/eclipse-temurin:27-jre-alpine@sha256:3689ae1ed2051837cfd9ad0977446a60ca799d95cbb8f8e64a42e72ecaad6b35

# Set the working directory
WORKDIR /app

# Copy the built JAR file from the previous stage
COPY --from=build /app/target/*.jar app.jar

# Expose the port on which the Spring Boot application will run
EXPOSE 8080

# Command to run the application
CMD ["java", "-jar", "app.jar"]
