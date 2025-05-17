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
- **Container builder**: `nerdctl` (containerd), `podman`, or `docker`
- **Endpoint tools**: `jq`, `zcat`
- **(Optional)** Kubernetes cluster and `kubectl` for the k8s demo
- **Network access** to:
  - `https://artifacts.elastic.co/`
  - `https://artifacts.security.elastic.co/`


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
| `--versions 8.x.x,9.x.x,...`     | Comma-separated list of Elastic versions to download       |
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
   git clone https://github.com/pkward/artifacts-bundler.git
   cd artifacts-bundler
   ```

2. **Install prerequisites**
   ```bash
   # RHEL/CentOS example
   sudo dnf install -y curl tar jq gzip
   # Install podman, docker, or nerdctl
   sudo dnf install -y docker-ce|podman|containerd.io
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
   # Docker|Podman example
   docker|podman run -d -p 80:80 elastic-artifacts-nginx:latest
   ```
   Browse: ```http://<your-ip>/downloads/```

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

## Add Internal Artifacts Repository to Fleet Settings

In Kibana, navigate to Fleet > Settings under "Management".

Click Add next to Agent Binary Download.

Enter your mirror URL, e.g.:
```
http://<YOUR-MIRROR-IP>:<port>/downloads/
```
Click Save. Elastic Agents will now fetch binaries from your private mirror. 

Example screenshots:

<img width="1512" alt="Screenshot 2025-04-30 at 7 31 08 PM" src="https://github.com/user-attachments/assets/857ceb84-ea4b-41ba-b80e-f0248a703a39" />
<img width="1512" alt="Screenshot 2025-04-30 at 7 34 07 PM" src="https://github.com/user-attachments/assets/61512744-9f2f-4e8e-a3b9-d61e433c5252" />


## Add Internal Artifacts Repo URL to Elastic Defend Advanced Settings

In Kibana’s Security > Endpoint > Policies, select your Endpoint policy.

Click Edit policy, scroll to Advanced settings, and expand Global artifact download source.

Enter the mirror URL:
```
http://<YOUR-MIRROR-IP>:<port>
```
Click Save to apply to all enrolled Endpoint agents.

Example screenshot:

<img width="1497" alt="Screenshot 2025-04-30 at 7 27 11 PM" src="https://github.com/user-attachments/assets/6b847eeb-4442-48ab-b9fc-a07b3e33554e" />
<img width="1497" alt="Screenshot 2025-04-30 at 7 27 00 PM" src="https://github.com/user-attachments/assets/c56d96f6-ab1d-4bee-a1ce-40a644e8bbc9" />
<img width="1497" alt="Screenshot 2025-04-30 at 7 26 48 PM" src="https://github.com/user-attachments/assets/7c2f5843-38ab-480e-a933-0212101485fc" />

Confirm Elastic Defend (Endpoint) can retrieve Global artifacts:

<img width="468" alt="image" src="https://github.com/user-attachments/assets/b0367e5c-7b7e-493e-adc0-8df3ad45234f" />


---

© 2025 Pete Ward • MIT License

