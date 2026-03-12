# ─── Stage 1: build ──────────────────────────────────────────────────────────
FROM golang:1.22-alpine AS builder

# Install build essentials (needed for static linking via musl)
RUN apk add --no-cache git ca-certificates

WORKDIR /src

# Cache dependencies before copying source (layer-cache friendly)
COPY go.mod* go.sum* ./
RUN go mod download 2>/dev/null || true

# Copy source and build a fully static binary
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build \
      -trimpath -buildvcs=false \
      -ldflags="-s -w" \
      -o /out/go-args-env-file \
      .

# ─── Stage 2: runtime ────────────────────────────────────────────────────────
# scratch = empty image; only the static binary (and CA certs) are included.
FROM scratch

# Copy TLS root certificates so the binary can make HTTPS calls if needed
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy the compiled binary
COPY --from=builder /out/go-args-env-file /go-args-env-file

# The app reads files from /config at runtime — declare it as a volume hint.
# In Kubernetes the ConfigMap / Secret are mounted here.
VOLUME ["/config"]

ENTRYPOINT ["/go-args-env-file"]
