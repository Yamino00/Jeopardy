# ---- Stage 1: build con Maven ----
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /workspace

# Prima solo il pom: il layer delle dipendenze resta in cache
# finche' il pom non cambia
COPY pom.xml .
RUN mvn -q -B dependency:go-offline

COPY src ./src
RUN mvn -q -B package -DskipTests

# ---- Stage 2: runtime su JRE slim ----
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Utente non-root
RUN addgroup -S app && adduser -S app -G app
USER app

COPY --from=build /workspace/target/*.jar app.jar

# Limiti di memoria adatti ai free tier (container piccoli)
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0"

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
