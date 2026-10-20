# syntax=docker/dockerfile:1
# forge voice worker for Spark (CONTRACTS §8). Build context: forge/.
#   docker compose -f deploy/docker-compose.worker.yml up -d --build
# Only `forge worker` is meant to run here: it needs config.yaml, ffmpeg and the
# API/audio env, not the content dir or an LLM.
FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS build
ARG TARGETOS TARGETARCH
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags="-s -w" -o /out/forge ./cmd/forge

FROM alpine:3.22
RUN apk add --no-cache ffmpeg ca-certificates tzdata \
 && adduser -D -H -u 65532 nonroot \
 && mkdir -p /hajanek/forge/work \
 && chown 65532:65532 /hajanek/forge/work
# FindRepo looks for forge/go.mod; work/ holds temporary clips.
COPY go.mod config.yaml /hajanek/forge/
COPY --from=build /out/forge /usr/local/bin/forge
USER 65532:65532
WORKDIR /hajanek/forge
ENTRYPOINT ["forge"]
CMD ["worker", "--repo", "/hajanek"]
