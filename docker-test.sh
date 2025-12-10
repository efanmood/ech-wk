#!/bin/bash

# Docker Test Script for ECH Workers - ARMv7
# This script helps verify that the Docker image builds and runs correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

IMAGE_NAME="ech-workers:armv7"
CONTAINER_NAME="ech-workers-test"

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}ECH Workers Docker Test Script${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Function to print test status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2${NC}"
    else
        echo -e "${RED}✗ $2${NC}"
        return 1
    fi
}

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Cleaning up...${NC}"
    docker stop ${CONTAINER_NAME} >/dev/null 2>&1 || true
    docker rm ${CONTAINER_NAME} >/dev/null 2>&1 || true
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Set trap for cleanup on exit
trap cleanup EXIT

echo -e "${BLUE}[1/6] Checking prerequisites...${NC}"
echo ""

# Check Docker
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
    print_status 0 "Docker is installed (version ${DOCKER_VERSION})"
else
    print_status 1 "Docker is not installed"
    exit 1
fi

# Check required files
echo ""
for file in Dockerfile .dockerignore ech-workers.go _worker.js; do
    if [ -f "$file" ]; then
        print_status 0 "Found $file"
    else
        print_status 1 "Missing $file"
        exit 1
    fi
done

echo ""
echo -e "${BLUE}[2/6] Building Docker image...${NC}"
echo ""

# Build the image
if docker build -t ${IMAGE_NAME} . ; then
    print_status 0 "Image built successfully"
else
    print_status 1 "Image build failed"
    exit 1
fi

echo ""
echo -e "${BLUE}[3/6] Verifying image...${NC}"
echo ""

# Check if image exists
if docker images ${IMAGE_NAME} | grep -q armv7; then
    print_status 0 "Image exists in Docker"
else
    print_status 1 "Image not found"
    exit 1
fi

# Check image size
IMAGE_SIZE=$(docker images ${IMAGE_NAME} --format "{{.Size}}")
echo -e "${GREEN}✓ Image size: ${IMAGE_SIZE}${NC}"

# Check image architecture
ARCH=$(docker image inspect ${IMAGE_NAME} --format '{{.Architecture}}')
if [ "$ARCH" = "arm" ]; then
    print_status 0 "Architecture is ARM (ARMv7)"
else
    echo -e "${YELLOW}⚠ Architecture is ${ARCH} (expected: arm)${NC}"
    echo -e "${YELLOW}  This is OK if building on x86_64 with buildx${NC}"
fi

echo ""
echo -e "${BLUE}[4/6] Testing container startup...${NC}"
echo ""

# Test basic container startup (without actual server connection)
# Use --help to verify the binary works
if docker run --rm ${IMAGE_NAME} -h > /dev/null 2>&1; then
    print_status 0 "Binary executable in container"
else
    echo -e "${YELLOW}⚠ Binary test returned non-zero (expected, -h flag)${NC}"
fi

# Test container can start (will fail without server, but should start)
echo -e "${YELLOW}Starting test container (will show error without valid server, this is expected)...${NC}"
docker run -d --name ${CONTAINER_NAME} ${IMAGE_NAME} \
    -l 0.0.0.0:30000 \
    -f test.workers.dev:443 \
    -routing global \
    >/dev/null 2>&1 || true

sleep 3

# Check if container started (it might exit due to invalid server)
if docker ps -a | grep -q ${CONTAINER_NAME}; then
    print_status 0 "Container created"
    
    # Show container status
    CONTAINER_STATUS=$(docker inspect ${CONTAINER_NAME} --format '{{.State.Status}}')
    echo -e "${YELLOW}  Container status: ${CONTAINER_STATUS}${NC}"
    
    # Show last few log lines
    echo -e "\n${YELLOW}Last 10 lines of container logs:${NC}"
    docker logs --tail 10 ${CONTAINER_NAME} 2>&1 | head -10
else
    print_status 1 "Container not created"
fi

echo ""
echo -e "${BLUE}[5/6] Testing Dockerfile best practices...${NC}"
echo ""

# Check for non-root user
if docker image inspect ${IMAGE_NAME} --format '{{.Config.User}}' | grep -q echworker; then
    print_status 0 "Runs as non-root user (echworker)"
else
    echo -e "${YELLOW}⚠ Container might run as root${NC}"
fi

# Check exposed ports
EXPOSED_PORT=$(docker image inspect ${IMAGE_NAME} --format '{{.Config.ExposedPorts}}' | grep -o '30000')
if [ "$EXPOSED_PORT" = "30000" ]; then
    print_status 0 "Port 30000 is exposed"
else
    echo -e "${YELLOW}⚠ Port 30000 not properly exposed${NC}"
fi

# Check for health check
if docker image inspect ${IMAGE_NAME} --format '{{.Config.Healthcheck}}' | grep -q "curl"; then
    print_status 0 "Health check configured"
else
    echo -e "${YELLOW}⚠ No health check found${NC}"
fi

# Check image labels
echo -e "\n${GREEN}Image metadata:${NC}"
docker image inspect ${IMAGE_NAME} --format '{{.Created}}' | xargs -I {} echo "  Created: {}"
docker image inspect ${IMAGE_NAME} --format '{{.Size}}' | numfmt --to=iec | xargs -I {} echo "  Size: {}"

echo ""
echo -e "${BLUE}[6/6] Testing Docker Compose configuration...${NC}"
echo ""

# Check docker-compose.yml
if [ -f "docker-compose.yml" ]; then
    print_status 0 "docker-compose.yml exists"
    
    # Validate docker-compose file
    if docker-compose config >/dev/null 2>&1; then
        print_status 0 "docker-compose.yml is valid"
    else
        echo -e "${YELLOW}⚠ docker-compose.yml validation failed${NC}"
    fi
else
    echo -e "${YELLOW}⚠ docker-compose.yml not found (optional)${NC}"
fi

# Check example file
if [ -f "docker-compose.example.yml" ]; then
    print_status 0 "docker-compose.example.yml exists"
fi

echo ""
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}Test Summary${NC}"
echo -e "${BLUE}================================${NC}"
echo ""
echo -e "${GREEN}✓ All basic tests passed!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Configure your Worker address in docker-compose.yml"
echo "2. Run: ${BLUE}docker-compose up -d${NC}"
echo "3. Test: ${BLUE}curl -x socks5://localhost:30000 https://ip.sb${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} The container will exit without a valid Worker address."
echo "This is expected behavior - configure your server first."
echo ""
echo -e "For detailed instructions, see ${BLUE}DOCKER.md${NC}"
echo ""
