# Offline Elastic Artifact Mirror & Nginx Delivery

**download-artifacts.sh** is a helper script that:

- **Bulk‑downloads** Elastic Stack binaries (Beats, APM, Fleet, Endpoint, etc.) and security endpoint artifacts.
- **Bundles** them into a timestamped tarball for easy distribution in air‑gapped environments.
- **Builds** a minimal Nginx container image to serve the artifacts over HTTP.

This is ideal for organizations running **air‑gapped** Elastic deployments or needing an offline mirror of both core Elastic and Elastic Defend artifacts.

---

## Prerequisites

- **Bash** ≥ 4.0
- **curl**, **tar**
- **Container builder**: `nerdctl` (Containerd), `podman`, or `docker`
- **Endpoint tools**: `jq`, `zcat`
- **(Optional)** Kubernetes cluster and `kubectl` for the k8s demo
- **Network access** to:
  - `https://artifacts.elastic.co/`
  - `https://artifacts.security.elastic.co/`

> **Offline usage:** prefetch dependencies or mirror these URLs in your private registry.

---

## Example Usage

Most users will choose **one** of these workflows:

1. **Bundle artifacts only** (to serve artifacts directly on your server)
2. **Build an Nginx image only** (to serve artifacts directly from container via HTTP)
3. **Combine both** (download, bundle, and build)

### 1. Bundle Artifacts Only
```bash
# Download version 8.17.4 and create a tarball\ 
./scripts/download-artifacts.sh --versions 8.17.4 --bundle
```
- Outputs: a timestamped tarball in `./artifacts-bundle/`

### 2. Build Nginx Container Only
```bash
# Download version 8.17.4 and build the Nginx image\ 
./scripts/download-artifacts.sh --versions 8.17.4 --build-nginx-image
```
- Outputs: an Nginx image (`elastic-artifacts-nginx:latest`) with artifacts baked in

### 3. Full Workflow (Download, Bundle, Build)
```bash
./scripts/download-artifacts.sh \
  --versions 8.17.4,8.18.0 \
  --bundle \
  --build-nginx-image
```

---

## Usage
```bash
./scripts/download-artifacts.sh [options]
```
| Flag                       | Description                                                      |
|----------------------------|------------------------------------------------------------------|
| `-h`, `--help`             | Show help message and exit                                       |
| `--versions v1,v2,...`     | Comma-separated list of Elastic versions to download              |
|                            | (repeatable for space-separated versions)                        |
| `--bundle`                 | Create a `.tar.gz` bundle of the downloaded artifacts            |
| `--build-nginx-image`      | Build a Docker/Podman/nerdctl image serving the artifacts        |
| `--destination DIR`        | Set output directory for downloads (default: `./artifacts-bundle`)|
| `--bundle-name FILE.tar.gz`| Specify custom bundle filename (default uses timestamp)          |
| `--nginx-image-tag TAG`    | Set the tag for the built image (default: `elastic-artifacts-nginx:latest`) |
| `--update`                 | Do not clear existing files in destination; only add missing ones|

---

## Demo Steps

1. **Clone the repo**
   ```bash
   git clone https://github.com/pkward/artifacts-bundler.sh.git
   cd artifacts-bundler.sh
   ```

2. **Install prerequisites**
   ```bash
   # RHEL/CentOS example
   sudo dnf install -y curl tar jq gzip
   # Install podman, docker, or nerdctl
   ```

3. **Download & bundle artifacts**
   ```bash
   ./scripts/download-artifacts.sh \
     --versions 8.17.4,8.18.0 \
     --bundle \
     --build-nginx-image
   ```

4. **Run the Nginx container locally**
   ```bash
   # Docker example
   docker run -d -p 8080:80 elastic-artifacts-nginx:latest
   ```
   Browse: http://localhost:8080/downloads/

5. **Kubernetes deployment**
   ```bash
   kubectl apply -f k8s/nginx-deploy.yaml
   kubectl apply -f k8s/nginx-nodeport.yaml
   ```
   Browse on any node IP: http://<NODE-IP>:30080/downloads/

---

## Project Structure

```
artifacts-bundler.sh/
├── scripts/
│   └── download-artifacts.sh   # Core downloader & bundler script
├── k8s/
│   ├── nginx-deploy.yaml      # Deployment manifest
│   ├── nginx-nodeport.yaml    # NodePort service manifest
│   └── ssl-configmap.yaml     # SSL ConfigMap example
├── README.md                  # This file
└── LICENSE                    # MIT License text
```

---

## Use Up‑to‑Date Elastic Versions

Examples target **Elastic Stack 8.17.x** or newer. Adjust `--versions` for 8.18.x, 9.x, etc.

---

© 2025 Pete Ward • MIT License

