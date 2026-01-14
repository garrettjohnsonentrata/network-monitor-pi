#!/bin/bash
# =============================================================================
# Pi Network Tester - Setup Script
# Installs Docker and Docker Compose on Raspberry Pi OS (Debian-based)
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print banner
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║           Pi Network Tester - Setup Script                    ║"
echo "║   Gaming Network Monitoring for Raspberry Pi 3 Model B        ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Please do not run this script as root.${NC}"
    echo "Run as a regular user - sudo will be used where needed."
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${YELLOW}[1/7]${NC} Updating system packages..."
sudo apt-get update

echo -e "${YELLOW}[2/7]${NC} Installing prerequisites..."
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

echo -e "${YELLOW}[3/7]${NC} Checking for Docker installation..."
if command -v docker &> /dev/null; then
    echo -e "${GREEN}Docker is already installed.${NC}"
    docker --version
else
    echo -e "${BLUE}Installing Docker using the convenience script...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    echo -e "${GREEN}Docker installed successfully.${NC}"
fi

echo -e "${YELLOW}[4/7]${NC} Adding current user to docker group..."
if groups "$USER" | grep -q docker; then
    echo -e "${GREEN}User '$USER' is already in the docker group.${NC}"
else
    sudo usermod -aG docker "$USER"
    echo -e "${GREEN}User '$USER' added to docker group.${NC}"
    echo -e "${YELLOW}Note: You may need to log out and back in for group changes to take effect.${NC}"
fi

echo -e "${YELLOW}[5/7]${NC} Checking Docker Compose..."
if docker compose version &> /dev/null; then
    echo -e "${GREEN}Docker Compose plugin is already installed.${NC}"
    docker compose version
else
    echo -e "${BLUE}Docker Compose plugin should be included with Docker.${NC}"
    echo "If not available, install with: sudo apt-get install docker-compose-plugin"
fi

echo -e "${YELLOW}[6/7]${NC} Creating required directories..."
mkdir -p "${SCRIPT_DIR}/prometheus/targets"
mkdir -p "${SCRIPT_DIR}/grafana/provisioning/datasources"
mkdir -p "${SCRIPT_DIR}/grafana/provisioning/dashboards"
mkdir -p "${SCRIPT_DIR}/grafana/dashboards"
mkdir -p "${SCRIPT_DIR}/scripts"
echo -e "${GREEN}Directories created.${NC}"

echo -e "${YELLOW}[7/7]${NC} Setting file permissions..."
chmod +x "${SCRIPT_DIR}/scripts/gateway_finder.sh"
chmod +x "${SCRIPT_DIR}/setup.sh"
echo -e "${GREEN}Permissions set.${NC}"

# Enable Docker to start on boot
echo -e "${BLUE}Enabling Docker to start on boot...${NC}"
sudo systemctl enable docker
sudo systemctl start docker

# Print completion message
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    Setup Complete!                            ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo ""
echo "  1. If you were added to the docker group, log out and back in:"
echo -e "     ${YELLOW}exit${NC} (then reconnect via SSH)"
echo ""
echo "  2. Start the monitoring stack:"
echo -e "     ${YELLOW}cd ${SCRIPT_DIR}${NC}"
echo -e "     ${YELLOW}docker compose up -d${NC}"
echo ""
echo "  3. Access the services:"
echo -e "     • Grafana:    ${GREEN}http://<pi-ip>:3000${NC} (admin/admin)"
echo -e "     • Prometheus: ${GREEN}http://<pi-ip>:9090${NC}"
echo ""
echo "  4. View logs:"
echo -e "     ${YELLOW}docker compose logs -f${NC}"
echo ""
echo "  5. Stop the stack:"
echo -e "     ${YELLOW}docker compose down${NC}"
echo ""
echo -e "${BLUE}Dashboard:${NC} The 'Gaming Network Health' dashboard will be"
echo "automatically available in Grafana after first login."
echo ""
echo -e "${YELLOW}Memory Note:${NC} This stack is optimized for Raspberry Pi 3 (1GB RAM)."
echo "Monitor with: ${YELLOW}docker stats${NC}"
echo ""
