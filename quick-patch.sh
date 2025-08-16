#!/bin/bash

# Quick patch for remaining issues

echo "🔧 Quick patch for remaining issues..."
echo "===================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# 1. Fix the version warning in docker-compose.override.yml
echo
print_info "Step 1: Fixing docker-compose.override.yml version warning..."

if [ -f "docker-compose.override.yml" ]; then
    # Remove the version line
    sed -i.bak '/^version:/d' docker-compose.override.yml
    print_status "Removed obsolete version line from docker-compose.override.yml"
else
    print_warning "docker-compose.override.yml not found"
fi

# 2. Check why pen-frontend is missing
echo
print_info "Step 2: Investigating pen-frontend service..."

print_info "Checking if pen-frontend is defined in compose files:"
grep -n "pen-frontend" docker-compose*.yml || print_warning "pen-frontend not found in compose files"

print_info "Checking all services defined:"
docker compose config --services

print_info "Checking for any stopped/failed containers:"
docker compose ps -a

# 3. Check if pen-frontend service is commented out or has syntax issues
echo
print_info "Step 3: Checking compose file syntax and pen-frontend definition..."

print_info "Validating compose file syntax:"
if docker compose config > /dev/null 2>&1; then
    print_status "Compose file syntax is valid"
else
    print_warning "Compose file has syntax issues:"
    docker compose config
fi

# 4. Try to manually start pen-frontend if it exists
echo
print_info "Step 4: Attempting to start pen-frontend service..."

if docker compose config --services | grep -q pen-frontend; then
    print_info "pen-frontend service found, attempting to start it..."
    docker compose up -d pen-frontend
    sleep 5
    docker compose ps
else
    print_warning "pen-frontend service not defined in compose file"
    print_info "Available services:"
    docker compose config --services
fi

# 5. Simple health check without jq dependency
echo
print_info "Step 5: Checking service health (simplified)..."

for i in {1..3}; do
    echo
    print_info "Health check attempt $i/3:"
    
    # Get service status without jq
    SERVICES=$(docker compose ps --format "table {{.Service}}\t{{.Status}}" | tail -n +2)
    echo "$SERVICES"
    
    # Count healthy services manually
    HEALTHY_COUNT=$(echo "$SERVICES" | grep -c "healthy" || echo "0")
    STARTING_COUNT=$(echo "$SERVICES" | grep -c "starting" || echo "0") 
    TOTAL_COUNT=$(echo "$SERVICES" | wc -l)
    
    print_info "Status: $HEALTHY_COUNT healthy, $STARTING_COUNT starting, $TOTAL_COUNT total"
    
    if [ "$i" -lt 3 ]; then
        sleep 15
    fi
done

# 6. Test the actual endpoints
echo
print_info "Step 6: Testing service endpoints..."

print_info "Testing pen-mcp-server health:"
if curl -s -f http://localhost:3001/health > /dev/null 2>&1; then
    print_status "pen-mcp-server is responding"
    curl -s http://localhost:3001/health
else
    print_warning "pen-mcp-server not responding on port 3001"
fi

print_info "Testing mcp-gateway health:"
if curl -s -f http://localhost:8080/health > /dev/null 2>&1; then
    print_status "mcp-gateway is responding"
    curl -s http://localhost:8080/health
else
    print_warning "mcp-gateway not responding on port 8080"
fi

# 7. Show current logs for debugging
echo
print_info "Step 7: Recent logs for debugging..."

print_info "mcp-gateway recent logs:"
docker compose logs --tail=5 mcp-gateway

print_info "pen-mcp-server recent logs:"
docker compose logs --tail=5 pen-mcp-server

if docker compose ps | grep -q pen-frontend; then
    print_info "pen-frontend recent logs:"
    docker compose logs --tail=5 pen-frontend
else
    print_warning "pen-frontend service not running"
fi

# 8. Final status and recommendations
echo
echo "🎯 Summary and Next Steps:"
echo "========================="

print_info "Current status:"
docker compose ps

echo
print_info "If services are still starting, wait a bit longer and check:"
echo "docker compose ps"

echo
print_info "If mcp-gateway is still unhealthy, check its health endpoint manually:"
echo "docker compose exec mcp-gateway curl -f http://localhost:8080/health"

echo
print_info "If pen-mcp-server is still unhealthy, check its health endpoint manually:"
echo "docker compose exec pen-mcp-server curl -f http://localhost:3001/health"

echo
print_info "To see detailed logs:"
echo "docker compose logs -f mcp-gateway"
echo "docker compose logs -f pen-mcp-server"

print_status "Quick patch completed!"
