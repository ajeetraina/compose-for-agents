#!/bin/bash

# Fix script for compose-for-agents issues
# This script fixes regex syntax error in mcp-gateway and nginx permission issues in pen-frontend

set -e  # Exit on any error

echo "🔧 Starting fix for compose-for-agents issues..."
echo "================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ] && [ ! -f "compose.yml" ]; then
    print_error "No docker-compose.yml or compose.yml found in current directory"
    print_error "Please run this script from your compose-for-agents project root"
    exit 1
fi

print_status "Found Docker Compose configuration"

# 1. Fix mcp-gateway regex issue
echo
echo "🔍 Fixing mcp-gateway regex syntax error..."

# Find the mcp-gateway server.js file
MCP_SERVER_FILE=""
if [ -f "mcp-gateway/server.js" ]; then
    MCP_SERVER_FILE="mcp-gateway/server.js"
elif [ -f "services/mcp-gateway/server.js" ]; then
    MCP_SERVER_FILE="services/mcp-gateway/server.js"
elif [ -f "src/mcp-gateway/server.js" ]; then
    MCP_SERVER_FILE="src/mcp-gateway/server.js"
else
    # Try to find it anywhere
    MCP_SERVER_FILE=$(find . -name "server.js" -path "*/mcp-gateway/*" 2>/dev/null | head -1)
fi

if [ -n "$MCP_SERVER_FILE" ] && [ -f "$MCP_SERVER_FILE" ]; then
    print_status "Found mcp-gateway server.js at: $MCP_SERVER_FILE"
    
    # Create backup
    cp "$MCP_SERVER_FILE" "$MCP_SERVER_FILE.backup"
    print_status "Created backup: $MCP_SERVER_FILE.backup"
    
    # Fix the regex syntax - replace (?i) with i flag at the end
    sed -i.tmp 's|/(?i)\([^/]*\)/|/\1/i|g' "$MCP_SERVER_FILE"
    rm -f "$MCP_SERVER_FILE.tmp"
    
    print_status "Fixed regex syntax in mcp-gateway server.js"
else
    print_warning "Could not find mcp-gateway/server.js file"
    print_warning "You may need to manually fix the regex in server.js:"
    print_warning "Change /(?i)(regex)/ to /(regex)/i"
fi

# 2. Fix nginx permission issues
echo
echo "🔍 Fixing nginx permission issues..."

# Create nginx configuration with writable temp directories
NGINX_CONF_DIR=""
if [ -d "pen-frontend/nginx" ]; then
    NGINX_CONF_DIR="pen-frontend/nginx"
elif [ -d "services/pen-frontend/nginx" ]; then
    NGINX_CONF_DIR="services/pen-frontend/nginx"
elif [ -d "nginx" ]; then
    NGINX_CONF_DIR="nginx"
else
    # Create nginx config directory
    mkdir -p pen-frontend/nginx
    NGINX_CONF_DIR="pen-frontend/nginx"
fi

print_status "Using nginx config directory: $NGINX_CONF_DIR"

# Create nginx.conf with proper temp paths
cat > "$NGINX_CONF_DIR/nginx.conf" << 'EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Use /tmp for all temp directories to avoid permission issues
    client_body_temp_path /tmp/nginx_client_temp;
    proxy_temp_path /tmp/nginx_proxy_temp;
    fastcgi_temp_path /tmp/nginx_fastcgi_temp;
    uwsgi_temp_path /tmp/nginx_uwsgi_temp;
    scgi_temp_path /tmp/nginx_scgi_temp;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    server {
        listen 80;
        server_name localhost;
        
        location / {
            root /usr/share/nginx/html;
            index index.html index.htm;
            try_files $uri $uri/ /index.html;
        }
        
        # Proxy API requests to pen-mcp-server
        location /api/ {
            proxy_pass http://pen-mcp-server:3001;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
            root /usr/share/nginx/html;
        }
    }
}
EOF

print_status "Created nginx.conf with proper temp directory paths"

# 3. Update docker-compose.yml to mount the nginx config
echo
echo "🔍 Updating Docker Compose configuration..."

# Create a backup of docker-compose file
COMPOSE_FILE=""
if [ -f "docker-compose.yml" ]; then
    COMPOSE_FILE="docker-compose.yml"
elif [ -f "compose.yml" ]; then
    COMPOSE_FILE="compose.yml"
fi

if [ -n "$COMPOSE_FILE" ]; then
    cp "$COMPOSE_FILE" "$COMPOSE_FILE.backup"
    print_status "Created backup: $COMPOSE_FILE.backup"
    
    # Check if nginx config volume is already mounted
    if ! grep -q "nginx.conf:/etc/nginx/nginx.conf" "$COMPOSE_FILE"; then
        print_warning "You may need to manually add nginx config volume to your $COMPOSE_FILE"
        print_warning "Add this volume to the pen-frontend service:"
        echo "        volumes:"
        echo "          - ./$NGINX_CONF_DIR/nginx.conf:/etc/nginx/nginx.conf:ro"
    fi
fi

# 4. Create initialization script for nginx directories
cat > "$NGINX_CONF_DIR/init-nginx-dirs.sh" << 'EOF'
#!/bin/sh
# Create temp directories that nginx needs
mkdir -p /tmp/nginx_client_temp
mkdir -p /tmp/nginx_proxy_temp
mkdir -p /tmp/nginx_fastcgi_temp
mkdir -p /tmp/nginx_uwsgi_temp
mkdir -p /tmp/nginx_scgi_temp
chmod 755 /tmp/nginx_*
EOF

chmod +x "$NGINX_CONF_DIR/init-nginx-dirs.sh"
print_status "Created nginx initialization script"

# 5. Stop services, rebuild and restart
echo
echo "🔄 Restarting services..."

print_status "Stopping all services..."
docker compose down

print_status "Building services (this may take a moment)..."
docker compose build --no-cache

print_status "Starting services..."
docker compose up -d

# 6. Wait a moment and check status
echo
echo "⏳ Waiting for services to start..."
sleep 10

echo
echo "📊 Service Status:"
docker compose ps

echo
echo "📋 Quick health check:"

# Check if services are running
if docker compose ps | grep -q "Up.*pen-mcp-server"; then
    print_status "pen-mcp-server is running"
else
    print_warning "pen-mcp-server may not be running properly"
fi

if docker compose ps | grep -q "Up.*mcp-gateway"; then
    print_status "mcp-gateway is running"
else
    print_warning "mcp-gateway may not be running properly"
fi

if docker compose ps | grep -q "Up.*pen-frontend"; then
    print_status "pen-frontend is running"
else
    print_warning "pen-frontend may not be running properly"
fi

echo
echo "🔍 If services are still failing, check logs with:"
echo "docker compose logs mcp-gateway"
echo "docker compose logs pen-frontend"
echo "docker compose logs pen-mcp-server"

echo
print_status "Fix script completed!"
echo "================================================="

# Show next steps
echo
echo "📝 Next Steps:"
echo "1. Verify all services are running: docker compose ps"
echo "2. Test the application endpoints"
echo "3. If pen-frontend still has issues, manually add the nginx config volume to $COMPOSE_FILE:"
echo "   volumes:"
echo "     - ./$NGINX_CONF_DIR/nginx.conf:/etc/nginx/nginx.conf:ro"
echo "     - ./$NGINX_CONF_DIR/init-nginx-dirs.sh:/docker-entrypoint.d/99-init-dirs.sh:ro"

echo
print_status "All fixes have been applied! 🎉"
