# artifacts-bundler.sh

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
- **Container builder**: one of `nerdctl` (Containerd), `podman`, or `docker`
- **Endpoint artifact tools**: `jq`, `zcat`
- **(Optional)** Kubernetes cluster and `kubectl` for the k8s demo
- **Network access** to:
  - `https://artifacts.elastic.co/`
  - `https://artifacts.security.elastic.co/`

> **Offline usage:** prefetch dependencies or mirror these URLs in your private registry.

---

## Demo Steps

Follow these copy‑and‑paste steps to experience the full workflow:

1. **Clone the repo**
   ```bash
   git clone https://github.com/<your‑username>/artifacts-bundler.sh.git
   cd artifacts-bundler.sh
   ```

2. **Install prerequisites**
   ```bash
   # Example on RHEL/CentOS
   sudo yum install -y bash curl tar jq gzip
   # Install podman or docker or nerdctl per your environment
   ```

3. **Download & bundle artifacts**
   ```bash
   ./download-artifacts.sh \
     --versions 8.17.4,8.18.0 \
     --bundle \
     --build-nginx-image
   ```

4. **Run the Nginx container locally**
   ```bash
   # With Docker:
   docker run -d -p 8080:80 elastic-artifacts-nginx:latest

   # Or Podman:
   podman run -d -p 8080:80 elastic-artifacts-nginx:latest
   ```
   Browse:  http://localhost:8080/downloads/

5. **(Elastic‑Stack) Ingest Nginx logs**
   - Use **Filebeat** or **Metricbeat** to ship `/var/log/nginx/*.log` into a local Elasticsearch (e.g. Docker, ECK).
   - Open Kibana at `http://localhost:5601` and visualize in Dashboard.

6. **(Kubernetes) Deploy & expose**
   ```bash
   kubectl apply -f k8s/nginx-deploy.yaml
   kubectl apply -f k8s/nginx-svc.yaml
   ```
   Wait for a LoadBalancer IP, then:
   ```
   http://<EXTERNAL-IP>/downloads/
   ```
   Point Filebeat there to ingest logs in-cluster.

---

## Project Structure

```
artifacts-bundler.sh/
├── scripts/
│   └── download-artifacts.sh   # Core artifact downloader & bundler
├── k8s/
│   ├── nginx-deploy.yaml      # Deployment manifest for k8s demo
│   ├── nginx-svc.yaml         # LoadBalancer service for k8s demo
│   └── ssl-configmap.yaml     # (Optional) SSL ConfigMap example
├── beats/
│   └── filebeat.yml           # Example Filebeat config for Nginx logs
├── README.md                  # This file
└── LICENSE                    # MIT License text
```

---

## Use Up‑to‑Date Elastic Versions

All examples target **Elastic Stack 8.17.x** or newer.  You can change `--versions` to any supported release: 8.18.x, 9.x, etc.

Beats and container images shown here reference versions explicitly; adjust as needed for your environment.

---

© 2025 Pete Ward • MIT License

