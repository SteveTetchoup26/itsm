# syntax=docker/dockerfile:1

# ---- Build stage: runs once, on the build machine's own architecture ($BUILDPLATFORM).
# The output (HTML, JavaScript, CSS) is the same for every architecture.
FROM --platform=$BUILDPLATFORM node:24.22.2-alpine AS build
WORKDIR /src

# Dependencies first: this layer is reused as long as the lock file does not change.
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --ignore-scripts --no-audit --no-fund

# Then the code. Lint and tests already run in the CI frontend job.
COPY . .
RUN npm run build

# ---- Runtime stage: official Nginx image, run as a non-root user (uid 101), listening on 8080.
# Built for each target architecture (amd64, arm64); Node is not in this image.
# The official image is used rather than nginxinc/nginx-unprivileged, which published nginx security
# fixes weeks later; nginx.conf does what that image did (no "user" directive, pid and temp in /tmp).
FROM nginx:1.30.7-alpine
# Security fixes of the Alpine packages published since the base image was built
# (the image is scanned by Trivy, blocking on fixable critical vulnerabilities).
RUN apk upgrade --no-cache
# The complete configuration replaces the default one, which read conf.d/ (removed, unused).
COPY nginx.conf /etc/nginx/nginx.conf
RUN rm /etc/nginx/conf.d/default.conf
COPY --from=build /src/dist/itsm-frontend/browser/ /usr/share/nginx/html/
# Numeric id: the "nginx" user of the image. A number lets the platform check that it is not root.
USER 101
EXPOSE 8080
