# 🌐 Hybrid Minecraft Server Network (DevOps Architecture)

This repository contains the Infrastructure as Code (IaC) and configuration for a professional Minecraft server network. It utilizes a microservices architecture powered by **Docker** and continuous automated deployment (CI/CD) via **GitHub Actions**.

## 🏗️ Network Architecture

The network follows a Hub/Spoke model (a centralized Proxy connecting to multiple backend servers) for maximum scalability and performance:

- **Central Proxy (Velocity):** Routes traffic, handles connections, and unifies the network.
- **Lobby Server (Paper 1.20.6):** The main landing server. Optimized for low RAM consumption.
- **Survival Server (Paper 1.20.6):** The primary gameplay server with high-performance configurations (Aikar Flags).
- **Database (MariaDB):** Centralized storage for plugins such as LuckPerms, CoreProtect, and AuthMe.

## 🔐 Security & Zero Trust

The infrastructure is designed with strict enterprise-grade security standards:

1. **Database Isolation:** MariaDB does not expose its port to the public internet. It is bound exclusively to the VPN interface (Tailscale), ensuring that only authorized devices can interact with the database.
2. **Secrets Protection:** Infrastructure secrets (DB Passwords, Velocity Forwarding Secret) are managed locally on the VPS via an `.env` file that is strictly ignored in `.gitignore`.
3. **Secure CI/CD:** The GitHub Actions pipeline uses `tailscale/github-action` to temporarily join the VPN, allowing SSH deployment without opening the server's port 22 to the outside world.

## 🚀 Continuous Deployment Flow (CI/CD)

Any changes pushed to the `main` branch of this repository automatically trigger a GitHub Actions workflow (`deploy.yml`):

1. **Change Detection:** Analyzes which subdirectories were modified (e.g., `proxy-data/` or `survival-data/`).
2. **VPN Tunnel:** Connects to the private Tailscale network.
3. **Synchronization:** Executes `git pull` on the remote VPS.
4. **Smart Restarts:** Executes `docker compose restart <service>` **only** on the container whose configuration was altered, guaranteeing zero downtime for the rest of the network.

## 📁 Repository Structure

The repository stores only persistent and static configurations. The `.gitignore` file protects the server's integrity by actively ignoring dynamic data such as worlds (`world*/`), player data, local databases (`.db`), and log files.

```text
.
├── proxy-data/         # Velocity proxy and plugins configuration
├── data/               # Lobby configuration (Paper)
├── survival-data/      # Survival configuration (Paper)
├── mariadb-init/       # SQL database initialization scripts
├── docker-compose.yml  # Infrastructure definition
├── .env.example        # Required environment variables template
└── .github/workflows/  # CI/CD pipeline for GitHub Actions
```

## 🛠️ Server Requirements (VPS)

To replicate this environment, the host server requires:
- Docker Engine and Docker Compose v2.
- Tailscale (for DB access and secure deployment).
- Git configured with Deploy Keys to access this repository.
- The `.env` file manually created based on `.env.example`.
