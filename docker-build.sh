#!/bin/bash

# Docker Build Script for ECH Workers - ARMv7
# This script helps build the Docker image for ARMv7 (Armbian) devices

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
IMAGE_NAME="ech-workers"
IMAGE_TAG="armv7"
PLATFORM="linux/arm/v7"
PUSH=false
REGISTRY=""

# Print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Build Docker image for ECH Workers (ARMv7/Armbian)

OPTIONS:
    -h, --help              Show this help message
    -n, --name NAME         Image name (default: ech-workers)
    -t, --tag TAG           Image tag (default: armv7)
    -p, --platform PLATFORM Platform to build for (default: linux/arm/v7)
    -r, --registry REGISTRY Registry to push to (e.g., docker.io/username)
    --push                  Push image to registry after building
    --no-cache              Build without cache
    -v, --verbose           Verbose output

EXAMPLES:
    # Basic build
    $0

    # Build with custom name and tag
    $0 -n myapp -t latest

    # Build and push to Docker Hub
    $0 -r docker.io/username --push

    # Build without cache
    $0 --no-cache

EOF
    exit 0
}

# Parse arguments
NO_CACHE=""
VERBOSE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -n|--name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -p|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        -r|--registry)
            REGISTRY="$2"
            shift 2
            ;;
        --push)
            PUSH=true
            shift
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        -v|--verbose)
            VERBOSE="--progress=plain"
            shift
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            usage
            ;;
    esac
done

# Construct full image name
if [ -n "$REGISTRY" ]; then
    FULL_IMAGE_NAME="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
else
    FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
fi

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}ECH Workers Docker Build Script${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "Image Name: ${YELLOW}${FULL_IMAGE_NAME}${NC}"
echo -e "Platform:   ${YELLOW}${PLATFORM}${NC}"
echo -e "Push:       ${YELLOW}${PUSH}${NC}"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# Check if Dockerfile exists
if [ ! -f "Dockerfile" ]; then
    echo -e "${RED}Error: Dockerfile not found in current directory${NC}"
    exit 1
fi

# Check if running on ARM device or if buildx is available for cross-compilation
ARCH=$(uname -m)
echo -e "Current architecture: ${YELLOW}${ARCH}${NC}"

if [ "$ARCH" != "armv7l" ] && [ "$ARCH" != "arm" ]; then
    echo -e "${YELLOW}Note: Not running on ARMv7. Will use buildx for cross-compilation.${NC}"
    
    # Check if buildx is available
    if ! docker buildx version &> /dev/null; then
        echo -e "${RED}Error: Docker buildx is required for cross-compilation${NC}"
        echo -e "Please install Docker buildx or run this script on an ARMv7 device"
        exit 1
    fi
    
    # Create builder if not exists
    if ! docker buildx inspect armv7-builder &> /dev/null; then
        echo -e "${YELLOW}Creating buildx builder for ARMv7...${NC}"
        docker buildx create --name armv7-builder --platform ${PLATFORM} || true
    fi
    
    echo -e "${YELLOW}Using buildx for cross-compilation...${NC}"
    docker buildx use armv7-builder
    
    # Build with buildx
    BUILD_CMD="docker buildx build"
    BUILD_ARGS="--platform ${PLATFORM}"
    
    if [ "$PUSH" = true ]; then
        BUILD_ARGS="${BUILD_ARGS} --push"
    else
        BUILD_ARGS="${BUILD_ARGS} --load"
    fi
else
    echo -e "${GREEN}Running on ARMv7 device, using standard docker build${NC}"
    BUILD_CMD="docker build"
    BUILD_ARGS=""
fi

# Build the image
echo -e "${GREEN}Building Docker image...${NC}"
echo -e "Command: ${YELLOW}${BUILD_CMD} ${BUILD_ARGS} ${NO_CACHE} ${VERBOSE} -t ${FULL_IMAGE_NAME} .${NC}"
echo ""

if ${BUILD_CMD} ${BUILD_ARGS} ${NO_CACHE} ${VERBOSE} -t ${FULL_IMAGE_NAME} . ; then
    echo ""
    echo -e "${GREEN}✓ Build successful!${NC}"
    echo ""
    
    # Show image info
    if [ "$PUSH" != true ] || [ "$ARCH" = "armv7l" ] || [ "$ARCH" = "arm" ]; then
        echo -e "${GREEN}Image information:${NC}"
        docker images ${FULL_IMAGE_NAME}
        echo ""
        
        # Verify architecture
        echo -e "${GREEN}Verifying image architecture...${NC}"
        BUILT_ARCH=$(docker image inspect ${FULL_IMAGE_NAME} | grep -o '"Architecture": "[^"]*"' | cut -d'"' -f4)
        echo -e "Built architecture: ${YELLOW}${BUILT_ARCH}${NC}"
        
        if [ "$BUILT_ARCH" = "arm" ]; then
            echo -e "${GREEN}✓ Architecture verified: ARM (ARMv7)${NC}"
        else
            echo -e "${YELLOW}⚠ Warning: Architecture mismatch. Expected 'arm', got '${BUILT_ARCH}'${NC}"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}Next steps:${NC}"
    echo -e "1. Run the container:"
    echo -e "   ${YELLOW}docker run -d --name ech-workers-proxy -p 30000:30000 ${FULL_IMAGE_NAME} -l 0.0.0.0:30000 -f your-worker.workers.dev:443 -token your-token${NC}"
    echo ""
    echo -e "2. Or use Docker Compose:"
    echo -e "   ${YELLOW}docker-compose up -d${NC}"
    echo ""
    
    if [ "$PUSH" != true ] && [ -n "$REGISTRY" ]; then
        echo -e "3. Push to registry:"
        echo -e "   ${YELLOW}docker push ${FULL_IMAGE_NAME}${NC}"
        echo ""
    fi
    
    echo -e "For detailed documentation, see ${YELLOW}DOCKER.md${NC}"
    
else
    echo ""
    echo -e "${RED}✗ Build failed!${NC}"
    exit 1
fi
