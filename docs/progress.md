# DevOps Assessment – Progress Log

Online Learning Management Platform (LMS) on AWS, region **ap-south-1 (Mumbai)**.

| Machine | What it is |
|---|---|
| **Laptop** | Windows dev machine. Code is written here and pushed to GitHub. |
| **Management Server** | `LMS-Mgmt-Server`, Ubuntu 22.04, t2.medium, default VPC. Created manually (not by Terraform). Runs Terraform (and later Ansible + Jenkins). Public IP at the time of writing: `13.201.69.23`. |
| **AWS** | Resources created by Terraform: `lms-vpc`, `lms-app-1`, `lms-app-2`, `lms-db`. |

---

## Task 0 - Management Server (manual)

- EC2 `LMS-Mgmt-Server` (`i-0cad4f43c8748bb8a`), Ubuntu 22.04, t2.medium, key pair `lms-mgmt`.
- Security group `lms-mgmt-sg`: 22 from my IP, 8080 from anywhere (Jenkins, later).
- Laptop SSH: `ssh -i ~/.ssh/lms-mgmt.pem ubuntu@13.201.69.23`

> The Management Server has no Elastic IP: its public IP **changes if it is stopped and started**.
> If that happens, update `mgmt_cidr` in `terraform.tfvars` and run `terraform apply` again.

---

## Task 1 - Terraform

### Files created

| File | Purpose |
|---|---|
| `infra/terraform/provider.tf` | Pins Terraform (>= 1.5) and the AWS provider (`~> 6.0`), sets region from a variable, adds default `Project`/`ManagedBy` tags. |
| `infra/terraform/variables.tf` | Inputs: `region` (ap-south-1), `project` (lms), `instance_type` (t2.micro), `mgmt_cidr` (SSH source, required), `public_key_path` (~/.ssh/lms_key.pub), and the VPC/subnet CIDRs. |
| `infra/terraform/network.tf` | VPC 10.0.0.0/16 (`lms-vpc`), 2 public subnets in 2 AZs, DB subnet 10.0.3.0/24, Internet Gateway, public route table, and a separate DB route table (with a comment explaining NAT Gateway vs. IGW). |
| `infra/terraform/security.tf` | `aws_key_pair` from `~/.ssh/lms_key.pub`; `lms-app-sg` (22 from mgmt, 80 from anywhere); `lms-db-sg` (5432 only from app-sg, 22 from mgmt). |
| `infra/terraform/ec2.tf` | Latest Ubuntu 22.04 AMI lookup (Canonical) and the 3 instances: `lms-app-1`, `lms-app-2`, `lms-db`. |
| `infra/terraform/outputs.tf` | Prints VPC ID, subnet IDs, and instance ID / public IP / private IP of all 3 servers. |
| `infra/terraform/terraform.tfvars.example` | Template for `terraform.tfvars` (copy it, then set `mgmt_cidr`). |
| `infra/terraform/.terraform.lock.hcl` | Locks the exact AWS provider version (6.73.0) so every machine uses the same one. Commit it. |
| `.gitignore` | Keeps `.terraform/`, `*.tfstate*`, `terraform.tfvars` and `*.pem` out of git. |
| `docs/progress.md` | This file. |

### Design decision: DB internet access

The DB needs the internet once, to `apt install postgresql`. Options:

- **NAT Gateway**: the DB stays fully private, but it costs about $0.056/hour plus data (~$40/month) even when idle. The Management Server is in a *different* VPC, so it also couldn't SSH to a private-only DB without a bastion or VPC peering.
- **Chosen: DB subnet routes to the Internet Gateway, and the DB gets a public IP locked down by `lms-db-sg`.** Only the app servers can reach 5432, and only the Management Server can reach 22. This is free, simple, and Ansible can reach the DB directly.

The DB keeps its own route table (`lms-db-rt`), so moving to a NAT Gateway later is a small change.

### What runs where

| Step | Runs on |
|---|---|
| Write code, `terraform fmt` / `validate`, `git push` | **Laptop** |
| Install tools, `aws configure`, `ssh-keygen`, `git clone`, all `terraform` commands | **Management Server** |
| VPC, subnets, IGW, route tables, SGs, key pair, 3 EC2 instances | Created **in AWS** by Terraform |

### Commands – in order

**On the laptop** (push the code so the Management Server can clone it):

```bash
git add .gitignore infra/ docs/
git commit -m "Task 1: Terraform infrastructure"
git push origin master
```

**SSH from the laptop into the Management Server:**

```bash
ssh -i ~/.ssh/lms-mgmt.pem ubuntu@13.201.69.23
```

Everything below runs **on the Management Server**.

1. Install base tools:
   ```bash
   sudo apt-get update
   sudo apt-get install -y git curl unzip gnupg software-properties-common
   ```

2. Install Terraform (HashiCorp apt repository):
   ```bash
   wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
   echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
   sudo apt-get update
   sudo apt-get install -y terraform
   terraform -version
   ```
   📸 **Screenshot 1:** `terraform -version` output.

3. Install AWS CLI v2:
   ```bash
   cd ~
   curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
   unzip -q awscliv2.zip
   sudo ./aws/install
   aws --version
   ```
   📸 **Screenshot 2:** `aws --version` output.

4. Configure AWS credentials (access key, secret, region `ap-south-1`, output `json`):
   ```bash
   aws configure
   aws sts get-caller-identity
   ```
   📸 **Screenshot 3:** `aws sts get-caller-identity` output (account + IAM user). Blur the account ID if the report is shared publicly.

5. Create the SSH key pair Terraform uploads and Ansible will use:
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/lms_key -N ""
   ls -l ~/.ssh/lms_key ~/.ssh/lms_key.pub
   ```
   📸 **Screenshot 4:** the `ls -l` output (never screenshot the private key's contents).

6. Clone the repo:
   ```bash
   git clone https://github.com/Abhik-Nayak/Online-Learning-Management-Platform.git
   cd Online-Learning-Management-Platform/infra/terraform
   ```

7. Create `terraform.tfvars` with this server's public IP as `mgmt_cidr`:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   MY_IP=$(curl -s https://checkip.amazonaws.com)
   sed -i "s|^mgmt_cidr.*|mgmt_cidr = \"${MY_IP}/32\"|" terraform.tfvars
   cat terraform.tfvars
   ```
   📸 **Screenshot 5:** `cat terraform.tfvars`.

8. Initialise, format-check and validate:
   ```bash
   terraform init
   terraform fmt -check
   terraform validate
   ```
   📸 **Screenshot 6:** `terraform init` ("Terraform has been successfully initialized!").
   📸 **Screenshot 7:** `terraform validate` ("Success! The configuration is valid.").

9. Plan:
   ```bash
   terraform plan -out=tfplan
   ```
   📸 **Screenshot 8:** the end of the plan: `Plan: 16 to add, 0 to change, 0 to destroy.`

10. Apply:
    ```bash
    terraform apply tfplan
    ```
    📸 **Screenshot 9:** `Apply complete! Resources: 16 added, 0 changed, 0 destroyed.` and the outputs below it.

11. Show the outputs (needed for the Ansible inventory in Task 2):
    ```bash
    terraform output
    ```
    📸 **Screenshot 10:** `terraform output`.

12. Quick SSH check from the Management Server (passwordless):
    ```bash
    ssh -i ~/.ssh/lms_key -o StrictHostKeyChecking=accept-new ubuntu@$(terraform output -raw app_1_public_ip) hostname
    ssh -i ~/.ssh/lms_key -o StrictHostKeyChecking=accept-new ubuntu@$(terraform output -raw db_public_ip) hostname
    ```
    📸 **Screenshot 11:** both hostnames printed with no password prompt.

**In the AWS Console (browser)**, for the report:

- 📸 **Screenshot 12:** EC2 → Instances: `lms-app-1`, `lms-app-2`, `lms-db` running (plus `LMS-Mgmt-Server`).
- 📸 **Screenshot 13:** VPC → Your VPCs: `lms-vpc` (10.0.0.0/16), and Subnets: `lms-public-1`, `lms-public-2`, `lms-db-subnet`.
- 📸 **Screenshot 14:** EC2 → Security Groups → `lms-db-sg` → Inbound rules (5432 source = `lms-app-sg`).

### Notes

- Cost: 3 × t2.micro (free-tier eligible for 750 hours/month in total, so 3 running all month exceeds it). No NAT Gateway and no Elastic IPs.
- To remove everything Terraform created: `terraform destroy` (on the Management Server, in `infra/terraform`). This does **not** touch the Management Server.
- Verified on the laptop: `terraform fmt`, `terraform validate`, and a read-only `terraform plan` (16 to add; AMI `ami-009a37f62c7ea3f0a`, AZs ap-south-1a / ap-south-1b). Nothing was applied from the laptop.
