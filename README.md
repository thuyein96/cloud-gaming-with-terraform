# Cloud Gaming with AWS & Terraform

Spin up a Windows cloud gaming PC on an AWS EC2 GPU Spot Instance using Terraform. On first boot the instance automatically installs NVIDIA drivers, Parsec, Steam, and/or Epic Games Launcher.

## Demo Video

Watch a walkthrough of the setup and first boot experience here:

[Watch the demo video](https://youtu.be/xGS1HfCbT1w)

> Replace `https://youtu.be/xGS1HfCbT1w` with your YouTube, Loom, or hosted MP4 link.

## Prerequisites

| Requirement | Notes |
|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/downloads) ≥ 1.0 | `terraform -v` to verify |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) | For credential management |
| AWS account | With EC2 Spot Instance limits for `g4dn` in your target region |

## Quick Setup

### 1. Configure AWS credentials

```bash
aws configure --profile thu-yein-iam
```

Enter your AWS Access Key ID, Secret Access Key, and default region when prompted.

### 2. Clone and enter the repo

```bash
git clone https://github.com/<your-username>/cloud-gaming-with-aws-terraform
cd cloud-gaming-with-aws-terraform
```

### 3. Configure `terraform.tfvars`

```bash
cp terraform.tfvars.example terraform.tfvars
```

Then edit it:

```hcl
aws_region    = "ap-southeast-1"          # AWS region to deploy in
public_subnet_1 = "ap-southeast-1a"       # Availability zone
instance_type = "g4dn.xlarge"             # GPU instance type (g4dn.xlarge recommended)

my_public_ip  = "YOUR.PUBLIC.IP.HERE"     # Your public IP — restricts RDP access to you only

root_block_device_size_gb = 120           # C:\ drive size in GB
rs_name = "cloud-gaming-instance"
rs_app  = "aws-cloud-gaming"

# Optional software installs (true/false)
install_parsec              = true
install_auto_login          = true
install_graphic_card_driver = true
install_steam               = true
install_epic_games_launcher = false
```

> Find your public IP: `https://api.ipify.org/`

### 4. Deploy

```bash
terraform init
terraform apply
```

Type `yes` when prompted. The deployment takes ~5 minutes. The instance will then reboot once to complete driver and software installation (~5 more minutes).

### 5. Connect via RDP

```bash
# Get the public IP
terraform output instance_ip

# Get the Administrator password
terraform output instance_password
```

Open Remote Desktop Connection and connect to the IP using:
- **Username:** `Administrator`
- **Password:** *(from the command above)*

Once logged in, Parsec will auto-configure on first login if enabled.

## Installed Software

| Variable | Default | What it installs |
|---|---|---|
| `install_graphic_card_driver` | `true` | NVIDIA GRID / G4 driver |
| `install_parsec` | `true` | [Parsec Cloud Preparation Tool](https://github.com/jamesstringerparsec/Parsec-Cloud-Preparation-Tool) |
| `install_auto_login` | `true` | Windows auto-login for Administrator |
| `install_steam` | `true` | Valve Steam |
| `install_epic_games_launcher` | `false` | Epic Games Launcher |

## Resources Created

- VPC + public subnet + internet gateway
- Security group (RDP port 3389 restricted to `my_public_ip`, VNC port 5900 open)
- IAM role + instance profile (allows SSM parameter reads)
- SSM parameter (stores generated Administrator password)
- EC2 Spot Instance (`one-time`) with Elastic IP

## Teardown

```bash
terraform destroy
```

> **Cost note:** A `g4dn.xlarge` Spot Instance in `ap-southeast-1` costs roughly **$0.20–$0.40/hr**. Remember to destroy when not in use.
