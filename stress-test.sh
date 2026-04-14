#!/bin/bash

# ──────────────────────────────────────────────
# stress-test.sh
# Simulates CPU load to trigger Auto Scaling
# Run this on any EC2 instance in the ASG
# ──────────────────────────────────────────────

echo "Installing stress tool..."
sudo apt install stress -y

echo ""
echo "Starting CPU stress test..."
echo "This will spike CPU above 60% for 5 minutes"
echo "Watch your CloudWatch alarm and ASG in AWS console"
echo ""

# Stress 4 CPU cores for 300 seconds (5 minutes)
stress --cpu 4 --timeout 300

echo ""
echo "Stress test complete."
echo "Check your email for SNS scale-up alert."
echo "Check ASG in AWS console — new instance should have launched."
