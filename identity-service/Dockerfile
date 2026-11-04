FROM eclipse-temurin:21-jre
WORKDIR /app
# Jar is built on the host: mvn -q package -DskipTests
COPY target/*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
