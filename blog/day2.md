# Step-by-Step Guide to Setting Up Terraform, AWS CLI, and Your AWS Environment

## Introduction
A solid foundation determines everything that follows. Yesterday I learned why Terraform matters; today I'm ensuring my environment is bulletproof. Whether you're starting fresh or verifying your setup, this guide walks through every step I took to get Terraform and AWS CLI running smoothly on my system.

## Step 1: AWS Account Setup
If you don't have an AWS account, create one at aws.amazon.com. The free tier covers everything we'll do in this challenge.

### Critical Security Steps:
1. Enable MFA on Root Account: Navigate to IAM → Dashboard → "Add MFA" for root user. Use Google Authenticator or similar.
2. Set Up Billing Alerts: Go to Billing → Budgets → Create Budget. I set a $10/month alert—more than enough for this challenge, but catches runaway resources early.

## Step 2: Create an IAM User for Terraform
Never use root credentials for Terraform. Here's exactly what I did:
1. Navigate to IAM → Users → Add Users
2. Username: terraform-user
3. Access type: Programmatic access (generates Access Key ID and Secret)
4. Permissions: Attach AdministratorAccess policy (for learning; in production, use least-privilege)
5. Save the Access Key ID and Secret Access Key immediately as they're shown only once

## Step 3: Install AWS CLI
I installed AWS CLI version 2 using the official installer:
```bash
Copy
# For Ubuntu/Debian
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version
# Output: aws-cli/2.15.0 Python/3.11.6 Linux/5.15.0 botocore/2.4.8
```

## Step 4: Configure AWS CLI
Run aws configure and enter your credentials:

```bash
Copy
$ aws configure
AWS Access Key ID [None]: AKIAIOSxxxxxxxx
AWS Secret Access Key [None]: wJalrXUtnFEMI/xxxxxxxxxxxxx
Default region name [None]: us-east-1
Default output format [None]: json
```

I chose us-east-1 because it has the most complete service availability and lowest latency for most global users. For production, choose the region closest to your users.

## Step 5: Install Terraform
I used the official HashiCorp repository to get the latest version:

```bash
Copy
# Add HashiCorp GPG key
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Add repository
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Install
sudo apt update && sudo apt install terraform

# Verify
terraform version
```

## Step 6: Visual Studio Code Setup
Extensions installed:
- HashiCorp Terraform (hashicorp.terraform) — Syntax highlighting, autocompletion, validation
- AWS Toolkit (amazonwebservices.aws-toolkit-vscode) — AWS resource browsing and deployment support

## Step 7: Full Validation
Before proceeding, I ran all four validation commands to confirm everything works:

```bash
Copy
terraform version
aws --version
aws sts get-caller-identity
aws configure list
```

All returned clean output (see documentation section below for actual outputs).

## Troubleshooting Common Issues
1. Issue: "Unable to locate credentials" error when running AWS commands
    Solution: Run aws configure again. Check ~/.aws/credentials file exists with proper formatting.
2. Issue: Terraform commands not found after installation
    Solution: Add to PATH: export PATH=$PATH:/usr/local/bin/terraform (add to ~/.bashrc for persistence)
3. Issue: Permission denied when running terraform init
    Solution: Ensure you're in a directory where you have write permissions, or use sudo (not recommended for production)

## Understanding Terraform-AWS Authentication
From Chapter 2, I learned Terraform doesn't store your AWS credentials. Instead, it uses the AWS SDK, which looks for credentials in this order:
1. Environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
2. Shared credentials file (~/.aws/credentials)
3. AWS config file (~/.aws/config)
4. IAM role (if running on EC2/ECS/Lambda)

This is why aws configure sets up Terraform automatically—the SDK finds the same credentials the CLI uses.

## Why Not Root Credentials?
Using root credentials is dangerous because:
1. They have unrestricted access to your entire AWS account
2. They can't be restricted by IAM policies
3. If compromised, an attacker has full control
4. They bypass all security guardrails

IAM users allow principle of least privilege, credential rotation, and activity auditing. Always use dedicated IAM users for automation.

## Conclusion
A proper setup takes time but pays dividends. With MFA-protected root access, billing alerts, dedicated IAM credentials, and verified tooling, I'm ready to start deploying real infrastructure tomorrow. The validation commands aren't just checkboxes rather they're your safety net ensuring every tool can authenticate and communicate correctly.