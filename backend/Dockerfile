# Eclipse Temurin (Alpine), JDK only where we actually compile
FROM docker.io/library/eclipse-temurin:26-jdk-alpine@sha256:bfaf402b2bebb3b5c85d65c66571e1108c63c54809e29a51540d349e42cadd14 AS build

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
FROM docker.io/library/eclipse-temurin:26-jre-alpine@sha256:2db9a5fb7c52fb44f9ffcf2d5caa16a39d4e8eb2977045ef3bb6589ae1c63ef5

# Set the working directory
WORKDIR /app

# Copy the built JAR file from the previous stage
COPY --from=build /app/target/*.jar app.jar

# Expose the port on which the Spring Boot application will run
EXPOSE 8080

# Command to run the application
CMD ["java", "-jar", "app.jar"]
