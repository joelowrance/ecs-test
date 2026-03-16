# ECS Example — Hello World Reference Application

A production-grade "Hello World" reference application demonstrating:

- **.NET 10** Minimal API with structured logging (Serilog), health checks, and OpenAPI
- **Docker** multi-stage build with non-root user
- **AWS ECS on Fargate** — private subnets, ALB, Container Insights, autoscaling
- **Terraform** modular infrastructure with remote state (S3 + DynamoDB)
- **GitHub Actions** CI/CD with OIDC authentication (no long-lived AWS keys)

## Architecture

```
Internet
   │
   ▼
[ALB — public subnets]
   │  port 80 → /health (health check)
   ▼
[ECS Fargate Tasks — private subnets]
   │  GET /hello  →  { message, timestamp, version }
   │  GET /health →  200 OK (liveness)
   │  GET /health/ready → JSON (readiness)
   │
   ▼
[NAT Gateway → ECR / CloudWatch / Secrets Manager]
```

## Prerequisites

| Tool | Version |
|------|---------|
| .NET SDK | 10.0.x |
| Docker | 24+ |
| Terraform | 1.9+ |
| AWS CLI | 2.x |
| Git | any |

## Quick Start (local development)

```bash
# Run the API locally
dotnet run --project src/EcsExample.Api

# Test endpoints
curl http://localhost:5000/hello
curl http://localhost:5000/health
curl http://localhost:5000/health/ready

# OpenAPI UI (development only)
open http://localhost:5000/scalar
```

## Running Tests

```bash
dotnet test
```

## Docker

```bash
# Build
docker build -t ecs-example .

# Run
docker run --rm -p 8080:8080 ecs-example

# Test
curl http://localhost:8080/hello
```

## Infrastructure Deployment

### Step 1 — Bootstrap remote state (run once)

```bash
cd infra/bootstrap

# Create a terraform.tfvars (never commit this file with real values)
cat > terraform.tfvars <<EOF
state_bucket_name = "mycompany-ecs-example-terraform-state"
EOF

terraform init
terraform apply -var-file=terraform.tfvars
```

### Step 2 — Update backend.tf with the bucket name

Edit `infra/environments/dev/backend.tf` and `infra/environments/prod/backend.tf`,
replacing `<YOUR_STATE_BUCKET>` with the bucket name output from Step 1.

### Step 3 — Deploy an environment

```bash
cd infra/environments/dev

terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

After apply completes, Terraform outputs the ALB DNS name:

```bash
terraform output alb_dns_name
# → ecs-example-dev-alb-1234567890.us-east-1.elb.amazonaws.com

curl http://$(terraform output -raw alb_dns_name)/hello
```

## CI/CD Setup

### GitHub Secrets required

Configure these in **Settings → Secrets and variables → Actions**:

| Secret | Description |
|--------|-------------|
| `AWS_ACCOUNT_ID` | 12-digit AWS account ID |
| `AWS_REGION` | e.g. `us-east-1` |
| `ECR_REPOSITORY_DEV` | ECR repo name for dev |
| `ECR_REPOSITORY_PROD` | ECR repo name for prod |
| `ECS_CLUSTER_DEV` | ECS cluster name for dev |
| `ECS_CLUSTER_DEV` | ECS cluster name for dev |
| `ECS_SERVICE_DEV` | ECS service name for dev |
| `ECS_CLUSTER_PROD` | ECS cluster name for prod |
| `ECS_SERVICE_PROD` | ECS service name for prod |

### OIDC IAM Role

Create an IAM role for each environment that trusts GitHub's OIDC provider:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<ORG>/<REPO>:*"
        }
      }
    }
  ]
}
```

### GitHub Environments

Create environments named **`dev`** and **`production`** in Settings → Environments.
Add required reviewers to the `production` environment to enforce manual approval.

### Workflow behaviour

| Event | Workflow |
|-------|----------|
| Push / PR to `main` or `develop` | Build + test |
| Push to `main` | Build + test → deploy to dev |
| Manual (`workflow_dispatch`) | Deploy specific image tag to prod |

## Project Structure

```
.
├── src/EcsExample.Api/          .NET 10 Minimal API
│   ├── Endpoints/               Route handlers
│   └── Health/                  Health check implementations
├── tests/
│   ├── EcsExample.Tests.Unit/   xUnit unit tests
│   └── EcsExample.Tests.Integration/ WebApplicationFactory integration tests
├── infra/
│   ├── bootstrap/               One-time state backend setup
│   ├── modules/
│   │   ├── vpc/                 VPC, subnets, NAT GW
│   │   ├── ecr/                 Container registry
│   │   ├── alb/                 Application Load Balancer
│   │   └── ecs/                 ECS cluster, service, IAM, autoscaling
│   └── environments/
│       ├── dev/                 Dev environment composition
│       └── prod/                Prod environment composition
├── .github/workflows/
│   ├── build-and-test.yml
│   ├── deploy-dev.yml
│   └── deploy-prod.yml
├── Dockerfile                   Multi-stage build
└── global.json                  Pins .NET SDK version
```

## Best Practices Implemented

- **Security**: Non-root Docker user, tasks in private subnets, no public IPs, least-privilege IAM, OIDC (no static keys)
- **Reliability**: Deployment circuit breaker with auto-rollback, min 100% healthy during deploys, multi-AZ placement
- **Observability**: CloudWatch Container Insights, structured JSON logs (Serilog), separate liveness/readiness endpoints
- **Cost**: Dev uses single NAT GW; prod uses one per AZ; ECR lifecycle policies clean old images
- **Developer experience**: `global.json` pins SDK, `.editorconfig` enforces formatting, `TreatWarningsAsErrors` enforces code quality
