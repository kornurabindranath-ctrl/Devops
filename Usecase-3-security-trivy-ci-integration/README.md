Day 3 – Trivy CI Integration

> Container vulnerability scanning integrated with GitHub Actions — a production-grade DevSecOps pipeline with security gates, CVE detection, and container hardening.

![Security Scan](https://img.shields.io/badge/Security-Trivy-blue?logo=aqua)
![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?logo=github-actions)
![Docker](https://img.shields.io/badge/Container-Docker-2496ED?logo=docker)
![Python](https://img.shields.io/badge/Language-Python-3776AB?logo=python)

---


## Overview

This project demonstrates a complete **DevSecOps pipeline** using [Trivy](https://github.com/aquasecurity/trivy) — an open-source vulnerability scanner — integrated with GitHub Actions. It covers the full lifecycle from a deliberately vulnerable container image to a hardened, production-ready one.

**What this project covers:**

- Container vulnerability scanning with Trivy
- CI/CD security gates (fail pipeline on HIGH/CRITICAL CVEs)
- CVE detection and severity threshold enforcement
- False positive suppression via `.trivyignore`
- JSON and SARIF security report generation
- Container hardening with a minimal base image and non-root user
- DevSecOps best practices end-to-end

---

## Architecture

```
Developer
    │
    ▼
Git Push
    │
    ▼
GitHub Actions
    │
    ├── Checkout Code
    ├── Build Docker Image
    ├── Trivy Scan
    ├── Severity Gate
    ├── Generate Reports
    └── Upload Artifacts
```

---



## Tech Stack

| Component          | Technology      |
|--------------------|-----------------|
| Language           | Python          |
| Containerization   | Docker          |
| Security Scanner   | Trivy           |
| CI/CD              | GitHub Actions  |
| Reports            | JSON            |
| Security Dashboard | SARIF           |
| Version Control    | Git             |

---

## Phase 1 – Vulnerable Application Setup

### 1.1 Create Project Structure

```bash
mkdir app
mkdir -p .github/workflows
```

### 1.2 Application Files

**`app/app.py`**
```python
from flask import Flask

app = Flask(__name__)

@app.route("/")
def home():
    return "Trivy Security Scan Demo"

if __name__ == "__main__":
    app.run(host="0.0.0.0")
```

**`app/requirements.txt`**
```
Flask==2.2.2
Werkzeug<3.0
```

**`app/Dockerfile`** — intentionally vulnerable base image for demo purposes
```dockerfile
FROM python:3.9

WORKDIR /app

COPY requirements.txt .

RUN pip install -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["python", "app.py"]
```

### 1.3 Build & Run

```bash
# Build the image
docker build -t trivy:v2 .

# Run the application
docker run -p 5000:5000 trivy:v2
```

### Screenshots

| Step | Screenshot |
|------|-----------|
| Project Structure | ![Project Structure]<img width="2692" height="740" alt="image" src="https://github.com/user-attachments/assets/d98d3eea-e113-47f6-a07f-c065f9e9bfb6" />|
| Docker Image size| ![Docker image size is huge this leads to more vulnerabilities]<img width="2374" height="178" alt="image" src="https://github.com/user-attachments/assets/a55bc395-5185-49ba-abd2-1d06e54280a0" />|

---

## Phase 2 – Trivy Installation & Scanning

### 2.1 Install Trivy

```bash
# macOS
brew install trivy

# Verify installation
trivy --version
```

### 2.2 Scan Modes

**Full image scan**
```bash
trivy image trivy:v2
```

**Scan only HIGH and CRITICAL severities**
```bash
trivy image \
  --severity HIGH,CRITICAL \
  trivy:v2
```

**Fail pipeline on vulnerabilities found**
```bash
trivy image \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  trivy:v2
```

**Generate JSON report**
```bash
trivy image \
  -f json \
  -o report.json \
  trivy:v2
```

### 2.3 Additional Scan Types

``
# Filesystem scan
trivy fs .

Found vulnerabities in falsk version 2.2.2, need to upgrade version of flask.

<img width="2938" height="1534" alt="image" src="https://github.com/user-attachments/assets/b960ee7d-74d2-4097-b3c3-e1f89460b660" />


# Secret detection
trivy fs --scanners secret .

We can observe that the access keys are hardcoded in the source code, which is a serious security risk and should be avoided in production environments.

<img width="2404" height="1682" alt="image" src="https://github.com/user-attachments/assets/b093ef16-e77c-4edf-ab51-fdbc9e93fcc3" />


# Misconfiguration scan
trivy config .

Running a container with privileged access poses security risks. It is recommended to use a dedicated non-root user to minimize the attack surface and adhere to the principle of least privilege.

<img width="2924" height="1546" alt="image" src="https://github.com/user-attachments/assets/f3e09f87-140d-4cc9-a15a-ba1f8b726a73" />

``

### Screenshots

| Step | Screenshot |
|------|-----------|
| First Scan | ![Trivy Scan]<img width="2940" height="1160" alt="image" src="https://github.com/user-attachments/assets/45d36c86-12ec-4baa-8b97-292fee2c8040" />|
| Severity Scan | ![Severity Scan]<img width="2932" height="1152" alt="image" src="https://github.com/user-attachments/assets/6b42a8f7-1d28-4521-9073-6ab01c0c65c6" />|
| Security Gate | Setting exit-code: '1' causes the pipeline to fail when vulnerabilities are detected, making it an effective security gate in CI/CD workflows.|
| Reports | ![Reports]Find the report on main folder of usecase 3 |

---

## Phase 3 – GitHub Actions Integration

### 3.1 Workflow File

**`.github/workflows/security-scan.yml`**

```yaml
name: Trivy Security Scan

on:
  push:
    branches:
      - main

jobs:

  security_scan:

    runs-on: ubuntu-latest

    steps:

      - uses: actions/checkout@v4

      - name: Build Docker Image
        run: |
          docker build -t trivy-demo:v1 ./app

      - name: Run Trivy Scan
        uses: aquasecurity/trivy-action@0.28.0
        with:
          image-ref: trivy-demo:v1
          severity: HIGH,CRITICAL
          ignore-unfixed: true
          exit-code: '1'

      - name: Upload Artifact
        uses: actions/upload-artifact@v4
        with:
          name: trivy-report
          path: trivy-report.json
```

### 3.2 Suppress False Positives

Create a `.trivyignore` file at the repo root with known false positives:

```
# .trivyignore
CVE-2023-30861
CVE-2026-42497
CVE-2026-42497
```

Trivy will skip these CVEs during all scans automatically.

### Screenshots

| Step | Screenshot |
|------|-----------|
| Failed Pipeline | ![Failed Pipeline]<img width="2174" height="1542" alt="image" src="https://github.com/user-attachments/assets/95a2322b-933c-4754-9bdd-82283cf95db9" />|
| Artifacts | ![To get Artifacts pass  exit-code: '0' to Reports steps without this reports is not created]<img width="2216" height="794" alt="image" src="https://github.com/user-attachments/assets/9539fb2e-ba3e-4863-aefc-b8aefb9a74d6" />|

---

## Phase 4 – Container Hardening

### 4.1 Secure Dockerfile

**`app/Dockerfile.secure`** — hardened version using minimal base image and non-root user

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN useradd -m appuser

USER appuser

EXPOSE 5000

CMD ["python", "app.py"]
```

**Key hardening changes:**
- Upgraded base image from `python:3.9` → `python:3.12-slim` (fewer packages, fewer CVEs)
- Added `--no-cache-dir` flag to avoid storing pip cache layers
- Created and switched to a non-root `appuser` (eliminates privilege escalation risk)

### 4.2 Build & Scan Secure Image

```bash
# Build hardened image
docker build \
  -f Dockerfile.secure \
  -t trivy:v3 .

# Scan and compare
trivy image trivy:v3
```
Image Size difference
<img width="1630" height="152" alt="image" src="https://github.com/user-attachments/assets/6e665cd7-fbb6-45be-9960-5aa0ca69f1bc" />


### Screenshots

| Step | Screenshot |
|------|-----------|
| Vulnerable Image (v1) | ![Before]<img width="2938" height="1028" alt="image" src="https://github.com/user-attachments/assets/bbe54e0e-e233-41af-ace6-8ead3df04df7" />|
| Secure Image (v2) | ![After]<img width="2934" height="994" alt="image" src="https://github.com/user-attachments/assets/858b7f58-2868-40de-ae73-13a5ea502111" />|
| Comparison | Comparing the Trivy scan results for both images indicates that vulnerability counts are strongly correlated with image size, as smaller images typically contain fewer dependencies and therefore fewer vulnerabilities. |

---

## Security Comparison

| Metric     | v1 (Vulnerable) | v2 (Hardened)    |
|------------|-----------------|------------------|
| Base Image | python:3.9      | python:3.12-slim |
| User       | root            | appuser          |
| Pip Cache  | Enabled         | Disabled         |
| Critical   | ❌ Present      | ✅ Reduced       |
| High       | ❌ Present      | ✅ Reduced       |
| Medium     | ❌ Present      | ✅ Reduced       |

---

## Useful Commands

```bash
# Full image scan
trivy image trivy-demo:v1

# Severity gate (fails pipeline on HIGH/CRITICAL)
trivy image --severity HIGH,CRITICAL --exit-code 1 trivy-demo:v1

# Filesystem scan
trivy fs .

# Secret scan
trivy fs --scanners secret .

# Misconfiguration scan
trivy config .

# JSON report
trivy image -f json -o report.json trivy-demo:v1

# SARIF report
trivy image -f sarif -o report.sarif trivy-demo:v1
```

---

## Key Learnings

- Trivy vulnerability scanning (image, filesystem, config, secrets)
- Container security hardening (non-root user, minimal base images)
- CVE analysis and severity classification
- GitHub Actions CI/CD pipeline integration
- DevSecOps pipeline design with security gates
- False positive handling with `.trivyignore`
- Supply chain security awareness

---

---

