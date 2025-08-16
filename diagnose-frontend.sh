#!/bin/bash

# Diagnostic script for pen-frontend issues

echo "🔍 Diagnosing pen-frontend issues..."
echo "=================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_status() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

echo
print_info "Step 1: Checking all containers (including stopped ones)"
docker compose ps -a

echo
print_info "Step 2: Checking what services are defined in compose file"
SERVICES=$(docker compose config --services)
echo "Defined services:"
echo "$SERVICES"

if echo "$SERVICES" | grep -q "pen-frontend"; then
    print_status "pen-frontend service is defined"
else
    print_error "pen-frontend service is NOT defined in compose file!"
fi

echo
print_info "Step 3: Checking pen-frontend logs"
if docker compose logs pen-frontend 2>/dev/null; then
    print_info "pen-frontend logs shown above"
else
    print_warning "No pen-frontend logs available (service may not exist or never started)"
fi

echo
print_info "Step 4: Checking port 80 usage"
if command -v lsof >/dev/null 2>&1; then
    LSOF_OUTPUT=$(lsof -i :80 2>/dev/null)
    if [ -n "$LSOF_OUTPUT" ]; then
        print_info "Port 80 is being used by:"
        echo "$LSOF_OUTPUT"
    else
        print_warning "Port 80 is not being used by any process"
    fi
elif command -v netstat >/dev/null 2>&1; then
    NETSTAT_OUTPUT=$(netstat -tlnp 2>/dev/null | grep :80)
    if [ -n "$NETSTAT_OUTPUT" ]; then
        print_info "Port 80 is being used by:"
        echo "$NETSTAT_OUTPUT"
    else
        print_warning "Port 80 is not being used by any process"
    fi
else
    print_warning "Cannot check port 80 usage (lsof and netstat not available)"
fi

echo
print_info "Step 5: Checking compose file configuration for pen-frontend"
if [ -f "docker-compose.yml" ]; then
    print_info "Checking docker-compose.yml for pen-frontend:"
    grep -A 10 -B 2 "pen-frontend" docker-compose.yml || print_warning "pen-frontend not found in docker-compose.yml"
fi

if [ -f "docker-compose.override.yml" ]; then
    print_info "Checking docker-compose.override.yml for pen-frontend:"
    grep -A 10 -B 2 "pen-frontend" docker-compose.override.yml || print_warning "pen-frontend not found in docker-compose.override.yml"
fi

echo
print_info "Step 6: Testing if we can manually start pen-frontend"
print_info "Attempting to start pen-frontend service specifically..."
docker compose up -d pen-frontend

echo
print_info "Waiting 5 seconds for startup..."
sleep 5

echo
print_info "Checking status after manual start attempt:"
docker compose ps -a

echo
print_info "Recent pen-frontend logs after start attempt:"
docker compose logs --tail=20 pen-frontend 2>/dev/null || print_warning "Still no pen-frontend logs"

echo
print_info "Step 7: Alternative - try running nginx manually to test config"
print_info "Testing nginx config syntax:"
if [ -f "nginx-config/nginx-no-tmp.conf" ]; then
    docker run --rm -v "$(pwd)/nginx-config/nginx-no-tmp.conf:/etc/nginx/nginx.conf:ro" nginx:alpine nginx -t
else
    print_warning "nginx-no-tmp.conf not found"
fi

echo
echo "🔧 Quick Fixes to Try:"
echo "====================="

echo
print_info "Fix 1: If pen-frontend is not defined, add it to docker-compose.yml:"
cat << 'EOF'
  pen-frontend:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx-config/nginx-no-tmp.conf:/etc/nginx/nginx.conf:ro
      - ./nginx-config/html:/usr/share/nginx/html:ro
    depends_on:
      - pen-mcp-server
EOF

echo
print_info "Fix 2: If nginx config is wrong, try minimal config:"
print_info "Create minimal-nginx.conf and test with that"

echo
print_info "Fix 3: If port 80 is blocked, try different port:"
print_info "Change ports to '8081:80' and access http://localhost:8081"

echo
print_info "Fix 4: Check Docker daemon and restart if needed:"
echo "docker system prune -f"
echo "docker compose down"
echo "docker compose up -d"

print_status "Diagnosis complete! Check the output above for issues."
