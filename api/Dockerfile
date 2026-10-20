# syntax=docker/dockerfile:1
# Build context: api/. Multi-arch: docker buildx build --platform linux/arm64,linux/amd64 .
FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS build
ARG TARGETOS TARGETARCH
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags="-s -w" -o /out/hajanek-api ./cmd/hajanek-api \
 && mkdir -p /out/data

# Alpine (not distroless) for ffprobe: voice samples must be 5–30 s.
FROM alpine:3.22
RUN apk add --no-cache ffmpeg ca-certificates tzdata \
 && adduser -D -H -u 65532 nonroot
COPY --from=build /out/hajanek-api /hajanek-api
COPY --from=build --chown=65532:65532 /out/data /data
USER 65532:65532
# DATA_DIR holds voice samples, clips and the script cache (same volume as the DB).
ENV PORT=8080 DB_PATH=/data/hajanek.db DATA_DIR=/data/files
EXPOSE 8080
VOLUME ["/data"]
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s CMD ["/hajanek-api", "healthcheck"]
ENTRYPOINT ["/hajanek-api"]
