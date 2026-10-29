# syntax=docker/dockerfile:1

# ---- Build stage: runs once, on the build machine's own architecture ($BUILDPLATFORM).
# A jar is the same on every architecture: compiling under arm64 emulation would only be slower.
FROM --platform=$BUILDPLATFORM eclipse-temurin:25.0.4.1_1-jdk-noble AS build
WORKDIR /src

# Dependencies first: this layer is reused as long as pom.xml does not change.
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN --mount=type=cache,target=/root/.m2 ./mvnw --batch-mode --no-transfer-progress dependency:go-offline

# Then the code. Tests already run in the CI backend job.
COPY src/ src/
RUN --mount=type=cache,target=/root/.m2 ./mvnw --batch-mode --no-transfer-progress -DskipTests package \
    && cp target/itsm-backend-*.jar application.jar \
    && java -Djarmode=tools -jar application.jar extract --layers --destination extracted

# ---- Runtime stage: built for each target architecture (amd64, arm64).
FROM eclipse-temurin:25.0.4.1_1-jre-noble
RUN groupadd --system --gid 10001 app \
    && useradd --system --uid 10001 --gid app --no-create-home app
WORKDIR /application

# One Docker layer per Spring Boot layer, from the least to the most frequently changed:
# a new version of the code only ships the last layer.
COPY --from=build /src/extracted/dependencies/ ./
COPY --from=build /src/extracted/spring-boot-loader/ ./
COPY --from=build /src/extracted/snapshot-dependencies/ ./
COPY --from=build /src/extracted/application/ ./

# Numeric non-root user (Kubernetes can check runAsNonRoot); the files above stay owned by root.
USER 10001:10001
EXPOSE 8080
# Heap sized from the container memory limit (technical specification).
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=70", "-jar", "application.jar"]
