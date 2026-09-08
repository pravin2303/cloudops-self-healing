# CloudOps — Self-Healing AWS Infrastructure

> A production-style, highly available containerized web application on AWS,
> provisioned entirely with Terraform, deployed via GitHub Actions, and
> capable of automatically detecting and recovering from instance failure.

**Status:** 🚧 In active development — see [Project Phases](#project-phases) below.

## Table of Contents

- [Project Overview](#project-overview)
- [Problem Statement](#problem-statement)
- [Architecture](#architecture)
- [Technologies](#technologies)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Self-Healing Demonstration](#self-healing-demonstration)
- [Security Considerations](#security-considerations)
- [Cost Considerations](#cost-considerations)
- [Cleanup](#cleanup)

## Project Overview

_(To be completed in Phase 13 — full documentation pass.)_

## Architecture

_(Architecture diagram and explanation will be added in Phase 13. See `architecture/architecture.mmd` for the current source diagram.)_

## Repository Structure

```
cloudops-self-healing/
├── app/                    # Flask application source + tests
├── terraform/              # Infrastructure as Code
│   ├── modules/            # Reusable Terraform modules
│   └── environments/dev/   # Dev environment composition
├── .github/workflows/      # CI/CD pipelines
├── scripts/                # Operational scripts (bootstrap, health checks, failure tests)
├── docs/                   # Detailed documentation
└── architecture/           # Architecture diagram source
```

## Project Phases

- [x] Phase 0 — Repository scaffolding
- [x] Phase 1 — Flask application
- [x] Phase 2 — Dockerfile
- [x] Phase 3 — Terraform networking
- [x] Phase 4 — Terraform security
- [ ] Phase 5 — ECR
- [ ] Phase 6 — ALB + Target Group
- [ ] Phase 7 — Compute (Launch Template)
- [ ] Phase 8 — Auto Scaling Group
- [ ] Phase 9 — CloudWatch monitoring
- [ ] Phase 10 — Failure simulation
- [ ] Phase 11 — CI pipeline
- [ ] Phase 12 — CD pipeline (OIDC)
- [ ] Phase 13 — Full documentation
- [ ] Phase 14 — Interview prep
- [ ] Phase 15 — Cleanup

## License

MIT — see [LICENSE](LICENSE)
