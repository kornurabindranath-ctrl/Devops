Day 02 — Docker Image Optimization — Engineering Case Study

> From a 1.41 GB bloated image to an 18.2 MB hardened production container.

This repository documents the **evolution** of a Docker image for a Go application — not as a tutorial, but as an engineering case study. Each version exists because the previous one had a measurable problem. Each optimization is explained, implemented, and compared.

---

## Why This Matters in Production

- Large images slow pod startup in Kubernetes — cold start delays mean real traffic impact during scaling
- Every deployment pulls the full image across every node — 1.41 GB vs 18.2 MB is minutes vs seconds
- Unoptimized CI/CD pipelines re-download all dependencies on every push — wasted build minutes at scale
- Registry storage and data transfer costs compound silently across nodes, regions, and deployments
- Images running as root with a full shell are a security liability — one breach and the attacker has full access
- More packages in the image means more CVEs to track, patch, and explain to compliance
- Slow pipelines slow feedback loops — engineers wait longer, ship slower
- Optimization isn't polish — it's what separates a working container from a production-ready one

---

## Table of Contents

- [Overview](#overview)
- [Level 1 — Basic Image](#level-1--basic-image)
- [Level 2 — Multi-Stage Build](#level-2--multi-stage-build)
- [Level 3 — Distroless Runtime](#level-3--distroless-runtime)
- [Level 4 — Docker Layer Caching](#level-4--docker-layer-caching)
- [Level 5 — BuildKit Cache Mounts](#level-5--buildkit-cache-mounts)
- [Final Results](#final-results)
- [Key Takeaways](#key-takeaways)

---

## Overview

| Version | Image Size | Primary Improvement      |
|---------|----------:|--------------------------|
| L1      | 1.41 GB   | Basic implementation     |
| L2      | 25.7 MB   | Multi-stage build        |
| L3      | 18.2 MB   | Distroless runtime       |
| L4      | 18.2 MB   | Optimized layer caching  |
| L5      | 18.2 MB   | BuildKit cache mounts    |

---

## Level 1 — Basic Image

### Goal

Get the application running inside a container. Nothing more.

┌──────────────────────────────┐
│ Debian                       │
├──────────────────────────────┤
│ Linux Packages               │
├──────────────────────────────┤
│ Go SDK                       │
├──────────────────────────────┤
│ Go Compiler                  │
├──────────────────────────────┤
│ Build Cache                  │
├──────────────────────────────┤
│ Source Code                  │
├──────────────────────────────┤
│ Binary                        │
└──────────────────────────────┘

≈ 1.41 GB

### Dockerfile

```dockerfile
FROM golang:1.26

WORKDIR /app

COPY . .

RUN go build -o server .

EXPOSE 8080

CMD ["./server"]
```

### How It Works

- Uses the official `golang` base image
- Copies the entire project into the container
- Builds the binary inside the container
- Runs the compiled binary

### Problems

- The Go compiler ships to production
- Build tools and source code are included in the final image
- Enormous attack surface
- Slow to push and pull

### Results

Image Size: 1.41 GB
<img width="1920" height="158" alt="image" src="https://github.com/user-attachments/assets/8b0f4c8f-47a4-43d4-9f30-b89c8cb17550" />

Docker History

<img width="2542" height="858" alt="image" src="https://github.com/user-attachments/assets/b5a46db0-3d16-4ce5-8ade-7d16e90c9039" />

dive analysis
<img width="1512" height="592" alt="image" src="https://github.com/user-attachments/assets/fdb2455e-b551-4be6-933d-7af8e58a11fb" />


---

## Why Level 2?

Level 1 works. But everything used to **build** the application ends up in the image that **runs** it.

A production container only needs the compiled binary. The compiler, the source code, the build cache — none of it belongs there.

The fix: separate the build environment from the runtime environment.

┌──────────────────────────────┐
│ Alpine Linux                 │
├──────────────────────────────┤
│ Binary                       │
└──────────────────────────────┘

≈ 25.7 MB

---

## Level 2 — Multi-Stage Build

### Goal

Reduce image size by keeping the build stage out of the final image.

### Dockerfile

```dockerfile
#stage 1 - Build
FROM golang:1.26 AS builder

WORKDIR /app

COPY . .

RUN go build -o server .

#stage 2 - Runtime
FROM alpine:latest

WORKDIR /app

COPY --from=builder /app/server .

EXPOSE 8080

CMD ["./server"]
```

### What Changed

- **Builder stage** — compiles the binary using the full Go image
- **Runtime stage** — copies only the compiled binary into a minimal Alpine base
- Source code never makes it into the final image

### Improvements

- ✅ Go compiler removed
- ✅ Source code removed
- ✅ Build cache removed
- ✅ Attack surface drastically reduced

### Comparison

| Feature      | L1       | L2      |
|--------------|----------|---------|
| Go Compiler  | ✅ Yes   | ❌ No   |
| Source Code  | ✅ Yes   | ❌ No   |
| Image Size   | 1.41 GB  | 25.7 MB |

<img width="1730" height="228" alt="image" src="https://github.com/user-attachments/assets/6cc7938b-fd32-4ca4-a4e6-3b84783a2e22" />

<img width="2574" height="438" alt="image" src="https://github.com/user-attachments/assets/4be8495b-3d83-46c4-bb12-59a35ffb735a" />

<img width="1440" height="578" alt="image" src="https://github.com/user-attachments/assets/82189735-fcaa-4633-8d9b-2ae832e6f921" />


---

## Why Level 3?

Level 2 cut the image from 1.41 GB to 25.7 MB. That's a 98% reduction.

But Alpine isn't minimal — it still ships a shell, BusyBox utilities, and a package manager. In a production container running a single Go binary, none of that is needed. And every tool that exists in the image is a tool an attacker could use.

The fix: remove everything except the binary.

---

## Level 3 — Distroless Runtime

### Goal

Harden the container by eliminating everything the application doesn't need to run.

Distroless

Application
│
├── Binary
└── Required Runtime Libraries

No shell.

No package manager.

No unnecessary tools.

This results in:

Smaller attack surface
Better security
Fewer CVEs
Production-ready images

### Dockerfile

```dockerfile

# Stage 1 - Build
FROM golang:1.26 AS builder

WORKDIR /app

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o server .

# Stage 2 - Runtime
FROM gcr.io/distroless/static-debian12

WORKDIR /

COPY --from=builder /app/server /server

EXPOSE 8080

USER nonroot:nonroot

ENTRYPOINT ["/server"]
```

### What Changed

- Switched from Alpine to `gcr.io/distroless/static-debian12`
- No shell, no package manager, no OS utilities
- Application runs as a non-root user

### Improvements

- ✅ No shell access
- ✅ No package manager
- ✅ Runs as non-root
- ✅ Production-grade security posture

### Comparison

| Feature          | L2      | L3      |
|------------------|---------|---------|
| Shell            | ✅ Yes  | ❌ No   |
| Package Manager  | ✅ Yes  | ❌ No   |
| Runs as Root     | ✅ Yes  | ❌ No   |
| Image Size       | 25.7 MB | 18.2 MB |

<img width="2132" height="268" alt="image" src="https://github.com/user-attachments/assets/c2e3fcee-33a0-4605-aa4a-4da3d6fa483f" />

<img width="2622" height="904" alt="image" src="https://github.com/user-attachments/assets/5ab0a10d-5111-4415-9b01-36d4a2014e76" />

<img width="1480" height="582" alt="image" src="https://github.com/user-attachments/assets/2aa23082-025d-4c58-835b-be3dfc6310bf" />

---

## Why Level 4?

The runtime image is secure and minimal. The next bottleneck is **build time**.

Every code change triggers a full rebuild — including dependency downloads. In a CI/CD pipeline, that overhead compounds fast.

Docker builds in layers. If we order the instructions correctly, unchanged layers hit the cache and are skipped entirely.

The fix: restructure the Dockerfile so dependencies are installed before source code is copied.

---

## Level 4 — Docker Layer Caching

### Goal

Reduce rebuild time on code changes by caching the dependency layer separately.

Goal of Dockerfile_v4

Instead of optimizing image size, we'll optimize build time.

Current Build (v3)
COPY . .

RUN go build -o server .

Problem:

main.go changes
        │
        ▼
COPY . .
        │
        ▼
Entire layer changes
        │
        ▼
Everything after it rebuilds

Even a one-line change invalidates the cache.

Better Build
Copy go.mod
        │
        ▼
Download dependencies
        │
        ▼
Copy source code
        │
        ▼
Build

Now:

Only main.go changed
        │
        ▼
Docker reuses dependency cache ✅

This is much faster for real applications


### Dockerfile

```dockerfile
# Builder Stage
FROM golang:1.26 AS builder

WORKDIR /app

# Copy dependency files first
COPY go.mod .
COPY go.sum .

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build binary
RUN CGO_ENABLED=0 GOOS=linux go build -o server .

# Runtime Stage
FROM gcr.io/distroless/static-debian12

WORKDIR /

# Copy only the binary
COPY --from=builder /app/server /server

# Run as non-root
USER nonroot:nonroot

EXPOSE 8080

ENTRYPOINT ["/server"]
```

"Why did you copy go.mod before COPY . .?"

"Because Docker caches the dependency download layer. If only main.go changes, go.mod and go.sum remain unchanged, so go mod download is reused from cache. This significantly reduces build time in CI/CD pipelines."

### What Changed

- `go.mod` and `go.sum` are copied and dependencies downloaded **before** the source code is copied
- As long as dependencies don't change, that layer is cached
- Only changed source code triggers a rebuild

### Improvements

- ✅ Faster local rebuilds
- ✅ Dependencies downloaded only when `go.mod` / `go.sum` change
- ✅ Better CI/CD pipeline performance

### Comparison

| Feature               | L3             | L4        |
|-----------------------|----------------|-----------|
| Layer Cache           | Basic          | Optimized |
| Dependency Downloads  | Every rebuild  | Cached    |

> 📸 Add screenshots: cached build output, uncached build output, timing comparison
<img width="2900" height="146" alt="image" src="https://github.com/user-attachments/assets/73aaf105-6d0e-4e3d-afed-bdbda8bab540" />

<img width="2930" height="180" alt="image" src="https://github.com/user-attachments/assets/ca4957b4-e470-4faa-bae6-943fc97a19b8" />

---
One small improvement

Our current Go application doesn't have any external dependencies, so go mod download won't make a visible difference yet. To really demonstrate Docker layer caching, I suggest we first add a small dependency (for example, the gorilla/mux router), then build v4 again. That way, you'll actually see Docker cache the dependency download layer, which is much closer to what happens in real production applications.

## Why Level 5?

Level 4 caches the dependency layer at the Docker layer level. But if a rebuild is triggered — say, `go.mod` changed — Go still re-downloads all modules from scratch.

BuildKit cache mounts persist the Go module cache and build cache **across builds**, at the filesystem level. They survive even when the Docker layer cache is invalidated.

The fix: mount persistent caches directly into the build step.

---

## Level 5 — BuildKit Cache Mounts

"Docker already caches layers. Why use BuildKit cache mounts?"

"Docker layer caching skips an entire RUN instruction only if its inputs haven't changed. When a RUN instruction must execute—for example, because go.mod changed—Docker reruns the whole step. BuildKit cache mounts persist directories like the Go module cache and Go build cache across builds, so even when the RUN step executes again, Go can reuse previously downloaded modules and compiled packages instead of downloading or compiling everything from scratch."


### Goal

Accelerate dependency downloads and compilation in CI/CD by persisting caches across builds.



### Dockerfile

```dockerfile
# Builder Stage
FROM golang:1.26 AS builder

WORKDIR /app

# Copy dependency files first
COPY go.mod .
COPY go.sum .

# Cache downloaded Go modules
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# Copy application source
COPY . .

# Cache Go build artifacts
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux go build -o server .

# Runtime Stage
FROM gcr.io/distroless/static-debian12

WORKDIR /

COPY --from=builder /app/server /server

USER nonroot:nonroot

EXPOSE 8080

ENTRYPOINT ["/server"]
```

### What Changed

- `--mount=type=cache,target=/go/pkg/mod` — persists the Go module cache
- `--mount=type=cache,target=/root/.cache/go-build` — persists the Go build cache
- Modules already downloaded are reused without network access
- Previously compiled packages are not recompiled

### Improvements

- ✅ Near-instant dependency resolution on cache hit
- ✅ Incremental compilation — only changed packages recompile
- ✅ Significant reduction in CI/CD build minutes

### Comparison

| Feature      | L4                  | L5                       |
|--------------|---------------------|--------------------------|
| Build Cache  | Docker layer cache  | Docker + BuildKit mounts |
| Build Speed  | Fast                | Fastest                  |

<img width="2940" height="224" alt="image" src="https://github.com/user-attachments/assets/03edf546-4524-46c6-8b50-2243028d7987" />

---

## Final Results

| Version | Image Size | Primary Improvement      |
|---------|----------:|--------------------------|
| L1      | 1.41 GB   | Basic implementation     |
| L2      | 25.7 MB   | Multi-stage build        |
| L3      | 18.2 MB   | Distroless runtime       |
| L4      | 18.2 MB   | Optimized layer caching  |
| L5      | 18.2 MB   | BuildKit cache mounts    |

**Size reduction: 1.41 GB → 18.2 MB — a 98.7% reduction.**

---

## Key Takeaways

- **Multi-stage builds** are the single biggest lever for image size — 98% reduction in one step
- **Distroless images** remove the runtime attack surface without changing application behavior
- **Layer ordering** is free performance — restructuring instructions costs nothing and saves rebuild time
- **BuildKit cache mounts** make CI/CD builds significantly faster when dependencies change frequently
- Image size, security posture, and build speed are independent dimensions — optimizing one doesn't sacrifice the others

---




