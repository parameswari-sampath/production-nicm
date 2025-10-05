#!/bin/bash

set -e  # Exit on error

echo "=================================================="
echo "  SmartMCQ Production Deployment Script"
echo "=================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is installed
print_info "Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

print_info "Docker is installed and running."
echo ""

# Stop all running containers
print_warning "Stopping all running Docker containers..."
if [ "$(docker ps -q)" ]; then
    docker stop $(docker ps -q)
    print_info "All containers stopped."
else
    print_info "No running containers found."
fi
echo ""

# Remove all containers
print_warning "Removing all Docker containers..."
if [ "$(docker ps -aq)" ]; then
    docker rm $(docker ps -aq)
    print_info "All containers removed."
else
    print_info "No containers to remove."
fi
echo ""

# Remove all images
print_warning "Removing all Docker images..."
if [ "$(docker images -q)" ]; then
    docker rmi -f $(docker images -q)
    print_info "All images removed."
else
    print_info "No images to remove."
fi
echo ""

# Remove all volumes (optional - comment out if you want to keep data)
print_warning "Removing all Docker volumes..."
if [ "$(docker volume ls -q)" ]; then
    docker volume rm $(docker volume ls -q) 2>/dev/null || print_warning "Some volumes are in use and cannot be removed."
else
    print_info "No volumes to remove."
fi
echo ""

# Remove all networks (except default ones)
print_warning "Removing custom Docker networks..."
docker network prune -f
print_info "Custom networks removed."
echo ""

# Clean up Docker system
print_info "Running Docker system prune..."
docker system prune -af --volumes
print_info "Docker system cleaned."
echo ""

# Load environment variables
if [ -f .env.production ]; then
    print_info "Loading production environment variables..."
    export $(cat .env.production | grep -v '^#' | xargs)
    print_info "Environment variables loaded."
else
    print_warning ".env.production file not found. Using default values from docker-compose.yml"
fi
echo ""

# Build and start containers
print_info "Building and starting Docker containers..."
if docker compose version &> /dev/null; then
    docker compose up -d --build
else
    docker-compose up -d --build
fi
echo ""

# Wait for services to be healthy
print_info "Waiting for services to be healthy..."
sleep 10

# Check container status
print_info "Container Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# Check logs for any errors
print_info "Checking logs for errors..."
if docker compose version &> /dev/null; then
    docker compose logs --tail=50
else
    docker-compose logs --tail=50
fi
echo ""

print_info "=================================================="
print_info "  Deployment Complete!"
print_info "=================================================="
echo ""
print_info "Services are running on:"
print_info "  - Nginx Reverse Proxy: http://smart-mcq.com (Port 80)"
print_info "  - Frontend: Internal (Port 3000)"
print_info "  - Backend API: Internal (Port 8080)"
print_info "  - PostgreSQL: localhost:5432"
echo ""
print_info "To view logs:"
if docker compose version &> /dev/null; then
    print_info "  docker compose logs -f [service_name]"
else
    print_info "  docker-compose logs -f [service_name]"
fi
echo ""
print_info "To stop services:"
if docker compose version &> /dev/null; then
    print_info "  docker compose down"
else
    print_info "  docker-compose down"
fi
echo ""
print_warning "IMPORTANT: Make sure your domain 'smart-mcq.com' points to this server's IP address!"
print_warning "IMPORTANT: Update the JWT_SECRET_KEY in .env.production before going live!"
echo ""
