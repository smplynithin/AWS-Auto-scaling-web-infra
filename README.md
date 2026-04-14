# ⚡ Auto Scaling Web Infrastructure on AWS
### Production-Grade EC2 Auto Scaling with Custom AMI (Packer), ALB, CloudWatch & Multi-Metric Scaling Policies

![AWS](https://img.shields.io/badge/AWS-EC2%20%7C%20ASG%20%7C%20ALB%20%7C%20CloudWatch%20%7C%20SNS-orange?style=flat-square&logo=amazonaws)
![Packer](https://img.shields.io/badge/Packer-Custom%20AMI-blue?style=flat-square&logo=packer)
![Nginx](https://img.shields.io/badge/Nginx-Web%20Server-green?style=flat-square&logo=nginx)
![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-purple?style=flat-square&logo=ubuntu)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)
![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen?style=flat-square)

---

## 📌 What This Project Does

This project deploys a **production-grade auto-scaling web infrastructure** on AWS. The system automatically adds or removes EC2 instances based on real-time traffic — ensuring the application stays available under any load while keeping costs minimal during quiet periods.

Key highlights:

- 🖼️ **Custom AMI via Packer** — pre-baked image with Nginx, website files, Git and Docker already installed. Every new EC2 launched by the ASG is **production-ready in seconds** with zero manual setup
- ⚖️ **Application Load Balancer** — single entry point that distributes traffic across all running instances
- 📈 **Multi-Metric Auto Scaling** — scales based on 3 conditions: CPU utilization, network traffic, and request count
- 🔔 **SNS Email Alerts** — instant notification every time a scale-up or scale-down event fires
- 🧪 **Stress tested** — verified with Linux `stress` tool to confirm scaling behaviour end to end

---

## 💰 Real World Value

| Scenario | Without Auto Scaling | With Auto Scaling |
|---|---|---|
| Normal traffic | 2 instances running | 2 instances running |
| Traffic spike (IPL, sale) | Server crashes | Scales to 4 instances automatically |
| Low traffic (midnight) | 2 instances wasting money | Scales down to 1 instance |
| New instance launched | Manual setup — 30 mins | Auto — 60 seconds (pre-baked AMI) |

---

## 🏗️ Architecture

```
                        Internet
                            ↓
               ┌────────────────────────┐
               │  Application Load      │
               │  Balancer (ALB)        │
               │  Single DNS endpoint   │
               └────────────────────────┘
                            ↓
               ┌────────────────────────┐
               │   Auto Scaling Group   │
               │   Min: 1               │
               │   Desired: 2           │
               │   Max: 4               │
               ├────────────────────────┤
               │  EC2 #1  │  EC2 #2     │
               │  Nginx   │  Nginx      │
               │  Ubuntu  │  Ubuntu     │
               └────────────────────────┘
                            ↑
               ┌────────────────────────┐
               │   CloudWatch Alarms    │
               │   • CPU > 60%          │
               │   • Network traffic ↑  │
               │   • Request count ↑    │
               └────────────────────────┘
                            ↑
               ┌────────────────────────┐
               │   Launch Template      │
               │   Custom AMI (Packer)  │
               │   Nginx + Docker       │
               │   + Website pre-loaded │
               └────────────────────────┘
                            ↑
               ┌────────────────────────┐
               │   Packer Build         │
               │   Ubuntu base AMI      │
               │   → installs Nginx     │
               │   → clones website     │
               │   → installs Docker    │
               │   → bakes custom AMI   │
               └────────────────────────┘
```

---

## ☁️ AWS Services Used

| Service | Purpose |
|---|---|
| **EC2** | Web servers running Nginx |
| **Auto Scaling Group (ASG)** | Manages instance count based on demand |
| **Launch Template** | Defines EC2 config — uses custom Packer AMI |
| **Application Load Balancer** | Distributes traffic, health checks instances |
| **Target Group** | Registers EC2 instances with ALB |
| **CloudWatch** | Monitors metrics, triggers alarms |
| **SNS** | Email alerts on scale events |
| **IAM** | EC2 instance role with least privilege |

---

## 🖼️ Custom AMI — Built with Packer

Instead of using a plain Ubuntu AMI and running setup scripts at launch time, this project uses **Packer** to pre-bake everything into a custom AMI.

### What the Packer build does:

```
Base Ubuntu AMI
      ↓
apt update
      ↓
Install Nginx
      ↓
Install Git → Clone website repo
      ↓
Copy index.html + style.css + scorekeeper.js → /var/www/html/
      ↓
Start Nginx + enable on boot
      ↓
Install Docker + configure docker.service
      ↓
Add ubuntu user to docker group
      ↓
Bake → Custom AMI saved to AWS
```

### Why Packer over User Data scripts?

| Approach | Launch time | Reliability | Reusability |
|---|---|---|---|
| **User Data script** | Slow — installs at every launch | Can fail if internet is slow | Re-runs every time |
| **Packer AMI** | Fast — everything pre-installed | Always consistent | Reuse across regions/accounts |

> In production, every second of launch time matters during a traffic spike. Pre-baked AMIs are the industry standard for Auto Scaling groups.

### Packer template: `packer/template.json`

```json
{
  "builders": [{
    "type": "amazon-ebs",
    "ssh_username": "ubuntu",
    "ami_name": "nithin-packers-Build-{{isotime | clean_resource_name}}"
  }],
  "provisioners": [
    {
      "type": "shell",
      "inline": [
        "sudo apt update -y",
        "sudo apt install nginx -y",
        "sudo apt install git -y",
        "sudo git clone https://github.com/saikiranpi/webhooktesting.git",
        "sudo cp webhooktesting/index.html /var/www/html/index.nginx-debian.html",
        "sudo service nginx start",
        "sudo systemctl enable nginx",
        "curl https://get.docker.com | bash"
      ]
    }
  ]
}
```

---

## 📈 Auto Scaling Policies — 3 Conditions

This ASG scales based on **three independent CloudWatch scale-up alarms** and one scale-down alarm.

Using 3 conditions makes this production-grade — a single CPU alarm would miss scenarios where Nginx gets flooded with thousands of small requests (CPU stays low but server is overwhelmed).

### Scale Up — 3 independent alarms (any one can trigger):

| File | Metric | Threshold | Action |
|---|---|---|---|
| `scale-up-cpu.json` | CPU Utilization | > 60% for 2 min | Add 1 instance |
| `scale-up-network.json` | NetworkIn | > 5MB/sec for 2 min | Add 1 instance |
| `scale-up-requests.json` | RequestCountPerTarget | > 1000 req/min | Add 1 instance |

### Scale Down — 1 alarm:

| File | Metric | Threshold | Action |
|---|---|---|---|
| `scale-down-cpu.json` | CPU Utilization | < 60% for 10 min | Remove 1 instance |

### Why each metric catches different problems:

| Metric | What it catches |
|---|---|
| **CPU > 60%** | Compute-heavy traffic (processing, rendering) |
| **NetworkIn high** | Bandwidth-heavy traffic (file uploads, large requests) |
| **RequestCount high** | Many small requests (API calls, bot traffic) |

### ASG Limits:

```
Minimum instances:  1   ← always at least 1 running
Desired instances:  2   ← normal state
Maximum instances:  4   ← hard ceiling during spikes
```

---

## 📂 Project Structure

```
aws-auto-scaling-web-infra/
│
├── packer/
│   ├── template.json            # Packer build template
│   ├── packer-vars.json         # Variables (region, AMI, instance type)
│   └── docker.service           # Custom Docker systemd service file
│
├── scripts/
│   └── stress-test.sh           # Linux stress test script
│
├── cloudwatch/
│   ├── scale-up-cpu.json        # Scale up alarm — CPU > 60%
│   ├── scale-up-network.json    # Scale up alarm — NetworkIn high
│   ├── scale-up-requests.json   # Scale up alarm — RequestCount high
│   └── scale-down-cpu.json      # Scale down alarm — CPU < 60%
│
├── screenshots/
│   ├── asg-instances.png        # ASG launching new instances
│   ├── cloudwatch-alarm.png     # Alarm in ALARM state
│   └── email-alert.png          # SNS scale notification email
│
└── README.md
```

---

## 🚀 Setup Guide

### Prerequisites
- AWS Account with IAM admin access
- Packer installed locally (`packer --version`)
- AWS CLI configured (`aws configure`)
- Key pair created in us-east-1

---

### Step 1 — Build Custom AMI with Packer

```bash
# Clone this repo
git clone https://github.com/yourusername/aws-auto-scaling-web-infra.git
cd aws-auto-scaling-web-infra/packer

# Build the AMI (takes ~5 minutes)
packer build -var-file packer-vars.json template.json

# Note the AMI ID from output:
# ==> Builds finished. The artifacts of successful builds are:
# --> amazon-ebs: AMIs were created:
# us-east-1: ami-0xxxxxxxxxxxxxxxxx
```

---

### Step 2 — Create Launch Template

```
AMI:           Your custom Packer AMI ID
Instance type: t2.micro
Key pair:      your-key-pair
Security group: allow HTTP (80) + SSH (22)
```

---

### Step 3 — Create Target Group

```
Target type:  Instances
Protocol:     HTTP
Port:         80
Health check: HTTP → /
```

---

### Step 4 — Create Application Load Balancer

```
Type:          Application
Scheme:        Internet-facing
Listener:      HTTP port 80
Target group:  your target group
```

---

### Step 5 — Create Auto Scaling Group

```
Launch template:  your launch template
Region:           us-east-1
Min:              1
Desired:          2
Max:              4
Load balancer:    attach your ALB target group
```

---

### Step 6 — Create CloudWatch Alarms + SNS

```
Scale Up alarm 1:  CPU > 60%           → trigger scale up policy
Scale Up alarm 2:  NetworkIn > 5MB/s   → trigger scale up policy
Scale Up alarm 3:  Requests > 1000/min → trigger scale up policy
Scale Down alarm:  CPU < 60%           → trigger scale down policy
SNS topic:         email alert on every scaling event
```

---

## 🧪 Stress Testing

### SSH into an EC2 instance and simulate load:

```bash
# Connect to instance
ssh -i your-key.pem ubuntu@your-ec2-public-ip

# Install stress tool
sudo apt install stress -y

# Simulate CPU spike (run for 5 minutes)
stress --cpu 4 --timeout 300

# Watch CPU in real time
top

# Watch nginx access logs
tail -f /var/log/nginx/access.log
```

### What to observe:

```
1. stress command runs → CPU spikes above 60%
2. CloudWatch alarm fires → state changes to ALARM
3. SNS email arrives → "Scaling up: launching new instance"
4. ASG launches new EC2 → instance count goes from 2 → 3
5. stress command ends → CPU drops
6. CloudWatch alarm resets → scale down fires
7. Instance count returns to 2
```

---

## 🔔 SNS Email Alert Sample

```
Subject: Auto Scaling: Launch for group "nithin-asg"

Auto Scaling Group:  nithin-asg
Event:               Launch
Cause:               CPU utilization > 60%
New instance:        i-0xxxxxxxxxxxxxxxxx
Current capacity:    3
```

---

## 🔐 Security

- EC2 instances only accept HTTP (80) from ALB security group
- SSH (22) restricted to your IP only
- IAM role follows least privilege
- No hardcoded credentials — Packer uses IAM role or env variables

---

## 💡 Key DevOps Concepts Demonstrated

- **Immutable infrastructure** — Packer bakes AMIs instead of configuring live servers
- **Auto Scaling** — system self-heals and right-sizes based on real demand
- **Multi-metric scaling** — more reliable than single-metric (CPU alone can miss network-heavy workloads)
- **Load balancing** — zero-downtime traffic distribution across instances
- **Infrastructure as Code** — Packer template is version controlled in Git
- **Observability** — CloudWatch alarms + SNS alerts for full visibility

---

## 🧠 Interview Talking Points

> *"I built a production-grade auto scaling web infrastructure on AWS. I used Packer to bake a custom Ubuntu AMI with Nginx, Docker and my website pre-installed — so every new EC2 launched by the Auto Scaling Group is production-ready in seconds with no manual setup. The ASG scales between 1 and 4 instances based on three CloudWatch alarms — CPU utilization above 60%, network traffic increase, and ALB request count increase. I stress tested it using the Linux stress tool, confirmed instances launched automatically, and received SNS email alerts for every scaling event."*

---

## 👨‍💻 Author

**Nithin**
📍 Bangalore, India
🔗 [GitHub](https://github.com/yourusername)

---

## 📄 License

MIT License — feel free to use and modify.
