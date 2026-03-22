# Step-by-Step Guide to Setting Up Terraform, AWS CLI, and Your AWS Environment

## Introduction
Before deploying infrastructure, you need a properly configured environment. In this guide, I walk through how I set up Terraform, AWS CLI, and my AWS account to start building infrastructure as code.

---

## Step 1: AWS Account Setup

I used an existing AWS account and ensured the following:

- Enabled MFA on the root account
- Created a billing alert to avoid unexpected charges

### IAM User Setup
Instead of using root credentials, I created an IAM user with programmatic access.

Permissions assigned:
- AdministratorAccess (for learning purposes — will restrict later)

---

## Step 2: Install AWS CLI

### Installation
On Linux:

```bash
sudo apt update
sudo apt install awscli -y
```

## Step 3: Install Terraform

### Installation

```bash
sudo apt install -y gnupg software-properties-common

wget -O- https://apt.releases.hashicorp.com/gpg | \
gpg --dearmor | \
sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update
sudo apt install terraform
```

## Step 4: Validation

```bash
terraform version
aws --version
aws sts get-caller-identity
aws configure list
```