# AWS Enterprise Infrastructure Design Document

## Project Overview

**Project Name:** AWS Enterprise Landing Zone
**Version:** 1.0
**Author:** [Your Name]
**Last Updated:** 2026-01-24

### Purpose
Design and implement a production-grade AWS multi-account infrastructure for a mid-size organization (~500 employees) with multiple departments and projects, following AWS Well-Architected Framework principles.

---

## 1. Organization Profile (Use Case)

### Company: TechCorp Solutions
- **Industry:** Software Development & SaaS
- **Size:** 500 employees
- **Departments:**
  - Engineering (150 people)
  - Data Science (50 people)
  - Platform/DevOps (30 people)
  - Security (20 people)
  - Finance (50 people)
  - HR (30 people)
  - Sales & Marketing (170 people)

### Current Challenges (Simulated)
1. No centralized cloud governance
2. Shadow IT with scattered AWS accounts
3. No consistent security policies
4. Manual user access management
5. No cost allocation or budgeting
6. No disaster recovery strategy

---

## 2. AWS Multi-Account Strategy

### Account Structure (AWS Organizations)

```
Root (Management Account)
│
├── Security OU
│   ├── Security-Tooling Account (GuardDuty, Security Hub, Config)
│   ├── Log-Archive Account (Centralized Logging)
│   └── Audit Account (CloudTrail, Compliance)
│
├── Infrastructure OU
│   ├── Network-Hub Account (Transit Gateway, DNS, VPN)
│   ├── Shared-Services Account (CI/CD, Artifact Repos, Container Registry)
│   └── Identity Account (IAM Identity Center Directory)
│
├── Workloads OU
│   ├── Production OU
│   │   ├── Prod-Engineering Account
│   │   ├── Prod-DataScience Account
│   │   └── Prod-Platform Account
│   │
│   ├── Non-Production OU
│   │   ├── Staging-Engineering Account
│   │   ├── Dev-Engineering Account
│   │   ├── Staging-DataScience Account
│   │   └── Dev-DataScience Account
│   │
│   └── Experimental OU
│       ├── Sandbox-Engineering Account
│       ├── Sandbox-DataScience Account
│       └── Innovation-Lab Account
│
└── Suspended OU (For decommissioned accounts)
```

### Account Naming Convention
```
<org>-<environment>-<department>-<purpose>
Example: techcorp-prod-eng-workloads
```

---

## 3. Environment Tiers & Policies

### Production Environment
- **Access:** Restricted, approval-based
- **SCP Policies:**
  - Deny region restriction (us-east-1, us-west-2 only)
  - Deny leaving organization
  - Deny disabling CloudTrail/Config
  - Deny public S3 buckets
  - Require IMDSv2
  - Deny root user actions
- **Guardrails:**
  - Mandatory encryption at rest
  - Mandatory VPC flow logs
  - No direct internet access (NAT Gateway only)
  - Mandatory tagging (Environment, Owner, CostCenter, Project)

### Non-Production (Staging/Dev)
- **Access:** Team-based with time-limited elevated access
- **SCP Policies:**
  - Same as Production (slightly relaxed)
  - Allow additional regions for testing
  - Budget limits enforced
- **Guardrails:**
  - Encryption recommended
  - Auto-shutdown for non-business hours (cost savings)
  - Resource quotas

### Experimental/Sandbox
- **Access:** Self-service with guardrails
- **SCP Policies:**
  - Strict budget limits ($500/month per sandbox)
  - Deny expensive instance types
  - Auto-cleanup after 30 days
  - No production data access
- **Guardrails:**
  - Isolated VPCs (no connectivity to prod)
  - Limited service access
  - Mandatory resource tagging

---

## 4. Identity & Access Management

### AWS IAM Identity Center (SSO) Structure

#### Permission Sets (Roles)
| Permission Set | Description | Applicable Accounts |
|----------------|-------------|---------------------|
| AdministratorAccess | Full admin access | Management, Security |
| PowerUserAccess | Full access minus IAM | Dev, Staging |
| DeveloperAccess | Deploy & debug applications | Dev, Staging, Sandbox |
| ReadOnlyAccess | View-only access | All accounts |
| DataScientistAccess | SageMaker, EMR, Athena focused | Data accounts |
| SecurityAuditAccess | Security review access | All accounts |
| BillingAccess | Cost and billing only | Management |
| NetworkAdminAccess | VPC, TGW, Route53 access | Network account |

#### Groups & Assignments
```
Groups:
├── Platform-Admins → AdministratorAccess (All accounts)
├── Security-Team → SecurityAuditAccess (All), AdminAccess (Security OU)
├── Engineering-Leads → PowerUserAccess (Non-Prod), ReadOnly (Prod)
├── Engineering-Developers → DeveloperAccess (Dev, Sandbox)
├── DataScience-Team → DataScientistAccess (Data accounts)
├── Finance-Team → BillingAccess (Management), ReadOnly (All)
└── Auditors → ReadOnlyAccess (All accounts)
```

### Identity Provider Integration
- **Primary:** AWS IAM Identity Center with built-in directory
- **Future:** Integration with external IdP (Okta/Azure AD) via SAML 2.0

---

## 5. Network Architecture

### Hub-and-Spoke Model with Transit Gateway

```
                                    ┌─────────────────┐
                                    │   Internet      │
                                    └────────┬────────┘
                                             │
                                    ┌────────▼────────┐
                                    │  Egress VPC     │
                                    │  (NAT Gateway)  │
                                    └────────┬────────┘
                                             │
┌──────────────┐                   ┌─────────▼─────────┐                   ┌──────────────┐
│ On-Premises  │◄──── VPN/DX ────►│  Transit Gateway  │◄────────────────►│ Inspection   │
│ Data Center  │                   │     (Hub)         │                   │ VPC (NWFW)   │
└──────────────┘                   └─────────┬─────────┘                   └──────────────┘
                                             │
              ┌──────────────────────────────┼──────────────────────────────┐
              │                              │                              │
     ┌────────▼────────┐          ┌─────────▼─────────┐          ┌────────▼────────┐
     │   Production    │          │   Non-Production  │          │   Shared        │
     │   VPCs          │          │   VPCs            │          │   Services VPC  │
     └─────────────────┘          └───────────────────┘          └─────────────────┘
```

### VPC Design (per environment)
```
VPC CIDR: 10.{env}.0.0/16

Subnets per AZ (3 AZs):
├── Public Subnet    : 10.{env}.{az}0.0/24  (ALB, NAT Gateway)
├── Private Subnet   : 10.{env}.{az}1.0/24  (Applications, EKS nodes)
├── Database Subnet  : 10.{env}.{az}2.0/24  (RDS, ElastiCache)
└── Reserved Subnet  : 10.{env}.{az}3.0/24  (Future use)

Environment CIDR Allocation:
├── Production:      10.100.0.0/16
├── Staging:         10.101.0.0/16
├── Development:     10.102.0.0/16
├── Sandbox:         10.200.0.0/16 - 10.250.0.0/16
└── Shared Services: 10.0.0.0/16
```

### DNS Architecture
- **Route 53 Private Hosted Zones** shared via RAM
- **Central DNS:** corp.internal
- **Environment DNS:** {env}.corp.internal

---

## 6. Security Architecture

### Preventive Controls
1. **Service Control Policies (SCPs)**
   - Baseline guardrails across all accounts
   - Environment-specific restrictions

2. **IAM Permission Boundaries**
   - Limit maximum permissions for delegated admin

3. **VPC Security**
   - Security Groups (stateful)
   - Network ACLs (stateless)
   - AWS Network Firewall (inspection)

### Detective Controls
1. **AWS CloudTrail** - All API activity logged to Log Archive account
2. **AWS Config** - Configuration compliance monitoring
3. **Amazon GuardDuty** - Threat detection
4. **AWS Security Hub** - Unified security findings
5. **Amazon Inspector** - Vulnerability scanning

### Responsive Controls
1. **AWS Lambda** - Automated remediation
2. **EventBridge Rules** - Event-driven security responses
3. **SNS Notifications** - Security alerts

---

## 7. Cost Management

### Tagging Strategy (Mandatory)
| Tag Key | Description | Example Values |
|---------|-------------|----------------|
| Environment | Deployment environment | prod, staging, dev, sandbox |
| Department | Owning department | engineering, data-science, platform |
| Project | Project identifier | project-alpha, core-platform |
| CostCenter | Finance cost center | CC-1001, CC-2002 |
| Owner | Team/person responsible | platform-team, john.doe@corp.com |
| ManagedBy | IaC tool | terraform, manual |

### Budget Alerts
- **Organization Level:** Monthly spend alerts at 50%, 80%, 100%
- **Account Level:** Individual account budgets
- **Project Level:** Tag-based budget tracking

### Cost Optimization
- Reserved Instances for production workloads
- Spot Instances for non-critical workloads
- Auto-scaling policies
- Scheduled scaling (dev environments)
- S3 Intelligent Tiering

---

## 8. Terraform Module Structure

```
terraform/
├── modules/
│   ├── organization/          # AWS Organizations, OUs, SCPs
│   ├── account-baseline/      # Account vending baseline
│   ├── identity-center/       # IAM Identity Center setup
│   ├── network/
│   │   ├── vpc/              # Standard VPC module
│   │   ├── transit-gateway/  # TGW hub configuration
│   │   └── vpc-endpoints/    # Centralized VPC endpoints
│   ├── security/
│   │   ├── guardduty/        # GuardDuty organization setup
│   │   ├── securityhub/      # Security Hub setup
│   │   ├── config/           # AWS Config rules
│   │   └── cloudtrail/       # Organization trail
│   ├── logging/
│   │   ├── central-logging/  # S3 + KMS for log archive
│   │   └── log-subscription/ # CloudWatch log forwarding
│   └── governance/
│       ├── budgets/          # AWS Budgets
│       └── tagging/          # Tag policies
│
├── environments/
│   ├── management/           # Root/Management account
│   ├── security/             # Security tooling account
│   ├── network/              # Network hub account
│   ├── shared-services/      # Shared services account
│   ├── production/           # Production workload accounts
│   ├── non-production/       # Dev/Staging accounts
│   └── sandbox/              # Experimental accounts
│
├── policies/
│   ├── scps/                 # Service Control Policies (JSON)
│   └── permission-sets/      # IAM Identity Center permission sets
│
└── global/
    ├── backend.tf            # Remote state configuration
    ├── providers.tf          # Provider configurations
    └── variables.tf          # Global variables
```

---

## 9. Implementation Phases

### Phase 1: Foundation (Week 1-2)
- [ ] AWS Organizations setup
- [ ] OU structure creation
- [ ] Management account hardening
- [ ] CloudTrail organization trail
- [ ] Core SCPs deployment

### Phase 2: Security Baseline (Week 3-4)
- [ ] Security tooling account setup
- [ ] Log archive account setup
- [ ] GuardDuty organization enablement
- [ ] Security Hub enablement
- [ ] AWS Config rules deployment

### Phase 3: Identity & Access (Week 5-6)
- [ ] IAM Identity Center configuration
- [ ] Permission sets creation
- [ ] Groups and user assignments
- [ ] Emergency access procedures

### Phase 4: Network Foundation (Week 7-8)
- [ ] Network hub account setup
- [ ] Transit Gateway deployment
- [ ] Shared VPC creation
- [ ] DNS architecture setup
- [ ] VPC endpoints (centralized)

### Phase 5: Workload Accounts (Week 9-10)
- [ ] Account vending automation
- [ ] Production account baseline
- [ ] Non-production accounts
- [ ] Sandbox account automation

### Phase 6: Day 2 Operations (Week 11-12)
- [ ] CI/CD for infrastructure
- [ ] Monitoring and alerting
- [ ] Cost optimization setup
- [ ] Documentation and runbooks
- [ ] DR testing procedures

---

## 10. Day 2 Operations

### Operational Runbooks
1. **Account Vending** - Creating new AWS accounts
2. **User Onboarding/Offboarding** - IAM Identity Center management
3. **Security Incident Response** - Handling GuardDuty findings
4. **Cost Anomaly Investigation** - Budget alert responses
5. **Network Changes** - VPC, TGW modifications
6. **Disaster Recovery** - Failover procedures

### Monitoring Dashboard
- Organization health metrics
- Security compliance scores
- Cost trends by department
- Resource utilization

### Automation
- Scheduled compliance scans
- Automated remediation for common issues
- Slack/Teams integration for alerts

---

## 11. Tools & Technologies

| Category | Tool | Purpose |
|----------|------|---------|
| IaC | Terraform | Infrastructure provisioning |
| State Management | S3 + DynamoDB | Terraform remote state |
| CI/CD | GitHub Actions | Automated deployments |
| Secrets | AWS Secrets Manager | Credential management |
| Documentation | Markdown + Diagrams | Project documentation |
| Diagrams | draw.io / Mermaid | Architecture diagrams |
| Testing | Terratest / Checkov | IaC testing & security scanning |
| Cost | Infracost | Cost estimation in PRs |

---

## 12. Success Criteria

- [ ] All accounts follow naming conventions
- [ ] 100% resources tagged properly
- [ ] No public S3 buckets in production
- [ ] All API calls logged to centralized location
- [ ] IAM users managed via Identity Center only
- [ ] All infrastructure deployed via Terraform
- [ ] Security Hub score > 90%
- [ ] Monthly cost reports by department
- [ ] DR tested quarterly

---

## Appendix A: Reference Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              AWS ORGANIZATION                                        │
│  ┌───────────────────────────────────────────────────────────────────────────────┐  │
│  │                         MANAGEMENT ACCOUNT                                     │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐   │  │
│  │  │ AWS Orgs    │  │ IAM Identity│  │ Billing &   │  │ Organization        │   │  │
│  │  │ Management  │  │ Center      │  │ Cost Mgmt   │  │ CloudTrail          │   │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────────────┘   │  │
│  └───────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
│  ┌─────────────────────────────┐     ┌─────────────────────────────────────────┐   │
│  │      SECURITY OU            │     │           INFRASTRUCTURE OU             │   │
│  │  ┌─────────┐ ┌───────────┐  │     │  ┌───────────┐  ┌───────────────────┐   │   │
│  │  │Security │ │Log Archive│  │     │  │ Network   │  │ Shared Services   │   │   │
│  │  │Tooling  │ │Account    │  │     │  │ Hub       │  │ (CI/CD, ECR)      │   │   │
│  │  └─────────┘ └───────────┘  │     │  └───────────┘  └───────────────────┘   │   │
│  └─────────────────────────────┘     └─────────────────────────────────────────┘   │
│                                                                                      │
│  ┌──────────────────────────────────────────────────────────────────────────────┐   │
│  │                            WORKLOADS OU                                       │   │
│  │  ┌────────────────┐   ┌──────────────────┐   ┌────────────────────────────┐  │   │
│  │  │ PRODUCTION OU  │   │ NON-PRODUCTION   │   │    EXPERIMENTAL OU         │  │   │
│  │  │ ┌────────────┐ │   │ ┌──────────────┐ │   │  ┌──────────────────────┐  │  │   │
│  │  │ │Prod-Eng    │ │   │ │ Dev-Eng      │ │   │  │ Sandbox Accounts     │  │  │   │
│  │  │ │Prod-Data   │ │   │ │ Staging-Eng  │ │   │  │ (Auto-cleanup)       │  │  │   │
│  │  │ └────────────┘ │   │ │ Dev-Data     │ │   │  └──────────────────────┘  │  │   │
│  │  └────────────────┘   └──────────────────┘   └────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Appendix B: Naming Conventions

### AWS Resources
```
{org}-{env}-{region}-{service}-{purpose}

Examples:
- techcorp-prod-use1-vpc-main
- techcorp-dev-use1-eks-platform
- techcorp-shared-use1-tgw-hub
```

### Terraform Resources
```
{service}_{purpose}_{detail}

Examples:
- aws_vpc.main
- aws_subnet.private
- aws_security_group.alb_ingress
```

---

*Document Version: 1.0 | Status: Draft | Review Required*
