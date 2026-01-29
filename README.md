# AWS Enterprise Landing Zone

> A production-grade AWS multi-account infrastructure implementation using Terraform, following AWS Well-Architected Framework and landing zone best practices.

## Overview

This project demonstrates the complete setup of an enterprise AWS infrastructure from Day 0 (initial setup) through Day 2 (operations). It's designed for a fictional mid-size organization "TechCorp Solutions" with 500 employees across multiple departments.

## Architecture Highlights

- **Multi-Account Strategy**: AWS Organizations with separated OUs for Security, Infrastructure, and Workloads
- **Environment Separation**: Production, Non-Production (Dev/Staging), and Sandbox environments
- **Centralized Identity**: AWS IAM Identity Center for unified access management
- **Hub-and-Spoke Network**: Transit Gateway-based network architecture
- **Security First**: GuardDuty, Security Hub, Config Rules, and SCPs
- **Cost Management**: Tagging strategy, budgets, and cost allocation

## Project Structure

```
.
├── README.md
├── docs/
│   ├── DESIGN.md              # Detailed design document
│   ├── IMPLEMENTATION.md      # Step-by-step implementation guide
│   ├── RUNBOOKS.md           # Operational runbooks
│   └── diagrams/             # Architecture diagrams
├── terraform/
│   ├── modules/              # Reusable Terraform modules
│   ├── environments/         # Environment-specific configurations
│   ├── policies/             # SCPs and IAM policies
│   └── global/               # Global configurations
├── scripts/                  # Helper scripts
└── .github/
    └── workflows/            # CI/CD pipelines
```

## Prerequisites

- AWS Account (will become Management Account)
- Terraform >= 1.5.0
- AWS CLI v2
- Git

## Quick Start

1. Clone this repository
2. Configure AWS credentials for your management account
3. Follow the [Implementation Guide](docs/IMPLEMENTATION.md)

## Implementation Phases

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Foundation (Org, OUs, SCPs) | Planned |
| 2 | Security Baseline | Planned |
| 3 | Identity & Access | Planned |
| 4 | Network Foundation | Planned |
| 5 | Workload Accounts | Planned |
| 6 | Day 2 Operations | Planned |

## Key Features Demonstrated

### Day 0 - Initial Setup
- AWS Organizations structure
- Service Control Policies
- Account baseline configuration

### Day 1 - Core Infrastructure
- Network architecture (VPCs, TGW)
- Security tooling deployment
- Identity management setup

### Day 2 - Operations
- Monitoring and alerting
- Incident response automation
- Cost optimization
- Compliance reporting

## Technologies Used

| Tool | Purpose |
|------|---------|
| Terraform | Infrastructure as Code |
| AWS Organizations | Multi-account management |
| IAM Identity Center | Centralized identity |
| Transit Gateway | Network hub |
| GuardDuty | Threat detection |
| Security Hub | Security posture |
| GitHub Actions | CI/CD |

## Documentation

- [Design Document](docs/DESIGN.md) - Detailed architecture and design decisions
- [Implementation Guide](docs/IMPLEMENTATION.md) - Step-by-step setup instructions
- [Operational Runbooks](docs/RUNBOOKS.md) - Day 2 operations procedures

## Cost Considerations

This architecture is designed for production use. For learning/demo purposes, you can:
- Use fewer availability zones
- Skip NAT Gateways in non-prod
- Use smaller instance sizes
- Enable auto-shutdown for dev environments

Estimated monthly cost for minimal setup: ~$100-200/month

## License

MIT License - Feel free to use this for learning and demonstration purposes.

## Author

Ravi Yasakeerthi

---

*This project is for educational and portfolio demonstration purposes.*
