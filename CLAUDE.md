# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Hello World reference application demonstrating .NET 10 + ASP.NET Core Minimal APIs deployed to AWS ECS Fargate via Terraform and GitHub Actions CI/CD.

## Commands

### .NET Application

```bash
# Run locally
dotnet run --project src/EcsExample.Api

# Build
dotnet build --configuration Release

# Run all tests
dotnet test

# Run unit tests only
dotnet test tests/EcsExample.Tests.Unit

# Run integration tests only
dotnet test tests/EcsExample.Tests.Integration

# Run a single test
dotnet test tests/EcsExample.Tests.Unit --filter "FullyQualifiedName~HelloEndpointsTests"
```

### Docker

```bash
docker build -t ecs-example .
docker run --rm -p 8080:8080 ecs-example
# App available at http://localhost:8080
```

### Terraform (Infrastructure)

```bash
# One-time bootstrap (S3 backend + DynamoDB lock table)
cd infra/bootstrap && terraform init && terraform apply -var-file=terraform.tfvars

# Deploy to an environment (dev or prod)
cd infra/environments/dev
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## Architecture

### Application Structure

```
src/EcsExample.Api/
  Program.cs              — App bootstrap: Serilog, OpenAPI, health checks, endpoint registration
  Endpoints/              — Minimal API route handlers (HelloEndpoints.cs)
  Health/                 — IHealthCheck implementations (ReadinessHealthCheck.cs)

tests/
  EcsExample.Tests.Unit/        — xUnit unit tests
  EcsExample.Tests.Integration/ — xUnit integration tests using WebApplicationFactory

infra/
  bootstrap/              — One-time S3 + DynamoDB state backend setup
  modules/vpc|ecr|alb|ecs — Reusable Terraform modules
  environments/dev|prod/  — Environment-specific compositions of modules
```

### Key Design Decisions

**Health check separation:** Two endpoints serve different purposes:
- `GET /health` — Liveness probe. Empty predicate (always 200 if process is up). Used by ALB target group health checks.
- `GET /health/ready` — Readiness probe. Runs `ReadinessHealthCheck` (add real dependency checks here). Returns structured JSON.

**Networking:** ECS tasks run in private subnets. All public traffic flows through the ALB in public subnets. Egress to AWS services (ECR, CloudWatch) goes through a NAT Gateway.

**Logging:** Serilog with structured JSON (`CompactJsonFormatter`) in production, human-readable template in development. Configured via `appsettings.json`, not in code.

**OpenAPI:** Enabled in Development only. Uses `Scalar.AspNetCore` (not Swagger UI).

**Code quality:** `TreatWarningsAsErrors`, `AnalysisMode: All`, and `Nullable: enable` are set in the project file. The editorconfig enforces 120-char line limit and LF line endings.

### CI/CD Workflows

| Workflow | Trigger | Purpose |
|---|---|---|
| `build-and-test.yml` | PR / push to main | Build + unit + integration tests |
| `deploy-dev.yml` | Push to main (after build passes) | Build Docker image → ECR → ECS dev |
| `deploy-prod.yml` | Manual dispatch with `image_tag` input | Deploy specific tag to ECS prod |

Production deployments require a GitHub environment approval. AWS authentication uses OIDC (no static credentials). ECS service updates use a circuit breaker with auto-rollback.

### Infrastructure Modules

1. **vpc** — VPC, public/private subnets across 2 AZs, IGW, NAT Gateway
2. **ecr** — Container registry with lifecycle policy (retains last 10 images)
3. **alb** — Application Load Balancer with HTTP listener and target group
4. **ecs** — Fargate cluster, task definition, IAM roles, autoscaling policies, CloudWatch Container Insights

### SDK & Tool Versions

- .NET SDK: pinned in `global.json` (`10.0.104`, `rollForward: latestPatch`)
- Terraform: `>= 1.9`
- AWS provider: `~> 6.0`
