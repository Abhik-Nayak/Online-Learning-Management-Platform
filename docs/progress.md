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

---

## Task 2 - Ansible

Ansible (on the Management Server) installs PostgreSQL on `lms-db`, and Docker + nginx on `lms-app-1` / `lms-app-2`,
then builds and runs the app container on both app servers.

```
Browser ──:80──> nginx (app1 / app2) ──127.0.0.1:3000──> lms-app container ──:5432 (DB private IP)──> PostgreSQL (db1)
```

- Ansible connects to the servers over their **public** IPs (SSH, key `~/.ssh/lms_key`).
- The app connects to the DB over its **private** IP (`10.0.3.x`). Only the app subnets are allowed, in both `pg_hba.conf` and `lms-db-sg`.

### Files created

| File | Purpose |
|---|---|
| `public/index.html` | The original `index.html`, moved unchanged, plus a status bar at the bottom that calls `/api/db-health` and shows "DB: connected \| served by app1" (green) or the error (red). |
| `server.js` | Express server: serves `public/`, `GET /api/health`, `GET /api/db-health` (runs `SELECT now(), version()`). DB settings only from env vars `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`. |
| `package.json` / `package-lock.json` | Dependencies: `express`, `pg` (exact versions locked). |
| `Dockerfile` | `node:20-alpine`, `npm ci --omit=dev`, runs as the non-root `node` user, `EXPOSE 3000`, `HEALTHCHECK` on `/api/health`. |
| `.dockerignore` | Keeps `node_modules`, `.git`, `infra/`, `docs/` out of the image. |
| `.gitattributes` | Forces LF line endings on `*.sh` so scripts committed from Windows run on Linux. |
| `infra/ansible/ansible.cfg` | Inventory, `ubuntu` user, `~/.ssh/lms_key`, no host-key prompt, vault password file `~/.vault_pass`. |
| `infra/ansible/gen_inventory.sh` | Reads `terraform output -json` and writes `inventory.ini` (`[app]` app1, app2 / `[db]` db1, with `private_ip`). |
| `infra/ansible/inventory.ini.example` | Example of the generated inventory (the real one is git-ignored). |
| `infra/ansible/group_vars/all/main.yml` | Shared variables: DB name/user/port, `db_host` (= DB private IP from the inventory), app port, image, container name, repo URL. |
| `infra/ansible/group_vars/all/vault.yml.example` | Template for the encrypted `vault.yml` that holds `vault_db_password` (the real file is git-ignored). |
| `infra/ansible/ping.yml` | Pings all hosts and prints hostname, public IP and private IP. |
| `infra/ansible/db.yml` | Installs PostgreSQL 14, `listen_addresses='*'`, `pg_hba.conf` rules for the app subnets (scram-sha-256), creates the user and database, restarts via a handler, prints `pg_lsclusters`. |
| `infra/ansible/app.yml` | Installs Docker, nginx and git; clones the repo to `/opt/lms`; builds `lms-app:latest`; runs the container (`restart: always`, `127.0.0.1:3000`); nginx site (`:80` to the container); checks `/api/health` and `/api/db-health` return 200. |
| `infra/ansible/templates/lms.nginx.conf.j2` | nginx site: `listen 80` and `proxy_pass http://127.0.0.1:{{ app_port }}`. |
| `infra/ansible/site.yml` | Runs `db.yml` then `app.yml`. |

> `group_vars/all.yml` from the spec became `group_vars/all/main.yml`: Ansible does not load an `all.yml` file
> when an `all/` folder (needed for `vault.yml`) exists next to it.

**Secrets:** the DB password exists only in `group_vars/all/vault.yml` (AES-256 encrypted with ansible-vault) and in
`~/.vault_pass` on the Management Server. Neither is in git. Tasks that handle the password use `no_log: true`.

### What runs where

| Step | Runs on |
|---|---|
| App + Ansible code, local tests, `git push` | **Laptop** |
| `git pull`, `gen_inventory.sh`, vault, all `ansible-playbook` commands | **Management Server** |
| PostgreSQL | **lms-db** (set up by Ansible) |
| `git clone`, `docker build`, container, nginx | **lms-app-1 / lms-app-2** (set up by Ansible) |
| Final check | **Browser** on the laptop |

### Commands – in order

**On the laptop:** push the code (the app servers `git clone` it from GitHub):

```bash
git add -A
git commit -m "Task 2: Ansible + DB-aware app"
git push origin master
```

Everything below runs **on the Management Server** (`ssh -i ~/.ssh/lms-mgmt.pem ubuntu@<mgmt-ip>`).

1. Install Ansible and jq (skip if `ansible --version` already shows core 2.17):
   ```bash
   sudo add-apt-repository --yes --update ppa:ansible/ansible
   sudo apt-get install -y ansible jq
   ansible --version
   ```

2. Get the new code:
   ```bash
   cd ~/Online-Learning-Management-Platform
   git pull
   cd infra/ansible
   ```

3. Generate the inventory from Terraform:
   ```bash
   ./gen_inventory.sh
   ```

4. Create the vault password file and the encrypted DB password (only once):
   ```bash
   openssl rand -base64 32 > ~/.vault_pass
   chmod 600 ~/.vault_pass

   DB_PW=$(openssl rand -base64 24 | tr -d '/+=')
   printf 'vault_db_password: "%s"\n' "$DB_PW" > group_vars/all/vault.yml
   ansible-vault encrypt group_vars/all/vault.yml
   unset DB_PW
   head -1 group_vars/all/vault.yml        # must print $ANSIBLE_VAULT;1.1;AES256
   ```
   (To view or change it later: `ansible-vault view group_vars/all/vault.yml` / `ansible-vault edit ...`.)

5. Connectivity check:
   ```bash
   ansible-playbook ping.yml
   ```
   📸 **Screenshot 1:** the `./gen_inventory.sh` output and the `ping.yml` output (hostname/IPs for app1, app2, db1 and `PLAY RECAP` with `failed=0`).

6. Database:
   ```bash
   ansible-playbook db.yml
   ```
   📸 **Screenshot 2:** the `Show pg_lsclusters` task (`14 main 5432 online`) and the `PLAY RECAP`.

7. App servers:
   ```bash
   ansible-playbook app.yml
   ```
   📸 **Screenshot 3:** the `Show results` task for app1 and app2 (`"db": "connected"`, `served_by`) and the `PLAY RECAP`.

8. Idempotency: run everything again; nothing should change:
   ```bash
   ansible-playbook site.yml
   ```
   📸 **Screenshot 4:** the `PLAY RECAP` with `changed=0` for all hosts.

9. **Browser (laptop):** open `http://<app_1_public_ip>` and `http://<app_2_public_ip>`
   (`terraform -chdir=../terraform output` shows them).
   📸 **Screenshot 5:** both pages with the green bar "DB: connected | served by app1" / "... app2".
   Optional: `http://<app_1_public_ip>/api/db-health` shows the raw JSON.

### Troubleshooting

| Symptom | Check |
|---|---|
| `ping.yml` "UNREACHABLE" | The Management Server's public IP changed: update `mgmt_cidr` in `terraform.tfvars`, `terraform apply`. |
| `/api/db-health` 500 "timeout" | `lms-db-sg` / `listen_addresses`: run `db.yml` again, then `ssh` to db1: `sudo ss -ltnp \| grep 5432` should show `0.0.0.0:5432`. |
| `/api/db-health` 500 "password authentication failed" | The vault password changed after the user was created: run `ansible-playbook site.yml` (it resets the DB password). |
| Container logs | On an app server: `sudo docker logs lms-app` |

### Verified on the laptop (before pushing)

- `node server.js` with no DB: `/` 200, `/api/health` 200, `/api/db-health` 500 `"DB_HOST is not set"`.
- Docker image built and run against a `postgres:14-alpine` container (scram-sha-256): `/api/db-health` 200 `"db":"connected"`,
  container runs as `uid=1000(node)`, Docker health status `healthy`; DB stopped: 500 after a 3 s timeout.
- In a container with ansible-core 2.17.14 (community.postgresql 3.9.0, community.docker 3.13.3):
  `gen_inventory.sh` (with fake terraform output), vault decryption, `db_host` = DB private IP,
  `--syntax-check` on all playbooks, and `ansible-lint`: 0 failures, 0 warnings (production profile).
- **Not** run against the real servers yet: that is steps 1–9 above.
