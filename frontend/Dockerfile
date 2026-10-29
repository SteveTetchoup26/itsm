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

# ---- Runtime stage: Nginx as a non-root user (uid 101), listening on 8080.
# Built for each target architecture (amd64, arm64); Node is not in this image.
FROM nginxinc/nginx-unprivileged:1.30.6-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/dist/itsm-frontend/browser/ /usr/share/nginx/html/
EXPOSE 8080
