# Deployment Guide

This guide walks through deploying the backend platform (FastAPI + services) separately from the web frontend (Next.js).

## 1. Backend (Gateway + Services)

### Prerequisites
- Docker 24+
- Docker Compose 2+
- Access to a container registry (optional, for pushing images)
- A `.env` file with production secrets (copy `.env.example` to `.env` and fill in values if running outside Compose)

### Local/Single-host deployment with Docker Compose
1. Build and start the stack:
   ```powershell
   cd c:/Users/abhi1/Desktop/SDE_PROJECTS/Distributed_payment_gateway
   docker compose up -d --build
   ```
2. Services exposed:
   - FastAPI gateway: `http://localhost:8000`
   - gRPC transaction: `localhost:50052`
   - gRPC fraud: `localhost:50053`
   - Postgres: `localhost:5432`
3. Tear down:
   ```powershell
   docker compose down
   ```

### Container images
Each service already has a dedicated Dockerfile under `docker/`.

| Service              | Dockerfile                        | Default Port |
|----------------------|-----------------------------------|--------------|
| FastAPI gateway      | `docker/gateway.Dockerfile`       | 8000         |
| Transaction service  | `docker/transaction.Dockerfile`   | 50052        |
| Fraud service        | `docker/fraud.Dockerfile`         | 50053        |

To build and push, e.g. for the gateway:
```powershell
# Build
cd c:/Users/abhi1/Desktop/SDE_PROJECTS/Distributed_payment_gateway
$registry="myregistry.azurecr.io"  # change to yours
$tag="$registry/ledgerstream/gateway:$(git rev-parse --short HEAD)"
docker build -f docker/gateway.Dockerfile -t $tag .

# Push
az acr login --name myregistry         # or docker login <registry>
docker push $tag
```
Repeat for other services, updating the Dockerfile path and repository names.

### Deploying to a VM / container app
1. Provision infrastructure (e.g. Azure Container Apps, AWS ECS, Kubernetes).
2. Push images for each service.
3. Create deployment manifests (compose, Helm, or platform-specific) that:
   - Set `DATABASE__URL` to your managed database connection string.
   - Wire `FRAUD_SERVICE_HOST` and `FRAUD_SERVICE_PORT` in the gateway.
   - Expose ports (8000, 50052, 50053) or load balance as required.
4. Apply migrations (if using Alembic) and seed data before traffic flows.

For Kubernetes, you can use the existing Docker images with separate Deployments/Services and a PostgreSQL managed service.

## 2. Web Frontend (Next.js)

### Prerequisites
- Node.js 18+
- npm 10+
- Production API endpoint from the backend
- Optional: Vercel, Azure Static Web Apps, or any provider supporting Next.js

### Environment configuration
Copy the example file and update the API URL:
```powershell
cd c:/Users/abhi1/Desktop/SDE_PROJECTS/Distributed_payment_gateway/frontend
copy .env.local.example .env.production.local
# edit .env.production.local to point NEXT_PUBLIC_API_BASE_URL to your backend
```

### Production build
```powershell
npm ci
npm run build
npm run start   # serves the app on http://localhost:3000
```

### Containerized build
A simple production Dockerfile (create `frontend/Dockerfile` if you plan to containerize):
```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/package*.json ./
RUN npm ci --omit=dev
EXPOSE 3000
CMD ["npm", "run", "start"]
```
Build and push similar to backend images.

### Hosting options
- **Vercel**: Connect the repository, set `NEXT_PUBLIC_API_BASE_URL` in the dashboard, trigger build.
- **Azure Static Web Apps / App Service**: Use the Docker image or run `npm run build` and deploy `.next` output.
- **Any Node-compatible PaaS**: Start with `npm run start` after the build.

## 3. CI/CD Suggestions
- Backend: Use GitHub Actions to build/push each service Dockerfile and update your infrastructure (Helm, Compose, Bicep, etc.).
- Frontend: Use a separate workflow to run `npm ci && npm run build` and deploy to Vercel or container registry.

For a full Azure setup, provision:
- Azure Container Apps or AKS for services (pull images from ACR)
- Azure Database for PostgreSQL
- Azure Front Door / Application Gateway for HTTPS exposure
- Vercel/Azure Static Web Apps for the frontend, pointing to the backend HTTPS URL

## 4. Local vs Production URLs
Update the Flutter client (`flutter_app/lib/core/config.dart`) and the Next.js app to use environment variables so production points at the hosted backend while local development continues to target `http://localhost:8000`.

---
This document focuses on manual deployment. If you need automated scripts or IaC, follow up with details about your target cloud so we can expand this guide.
