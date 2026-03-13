# ─── Stage 1: build ──────────────────────────────────────────────────────────
FROM ghcr.io/scontain/golang:1.25.4-alpine AS builder

# Install build essentials (needed for static linking via musl)
RUN apk add --no-cache git ca-certificates

WORKDIR /src

# Cache dependencies before copying source (layer-cache friendly)
COPY go.mod* go.sum* ./
RUN go mod download 2>/dev/null || true

# Copy source and build a fully static binary
COPY . .
RUN go build -v -o /usr/local/bin/go-args-env-file .

# The app reads files from /config at runtime — declare it as a volume hint.
# In Kubernetes the ConfigMap / Secret are mounted here.
VOLUME ["/config"]

ENTRYPOINT ["/usr/local/bin/go-args-env-file"]
