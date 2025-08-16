#!/bin/bash

# Debug and fix script for compose-for-agents issues
# This script first checks the environment and then applies fixes

set -e  # Exit on any error

echo "🔧 Debug and Fix script for compose-for-agents issues..."
echo "======================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Debug: Show current directory and files
echo
print_info "Current directory: $(pwd)"
print_info "Directory contents:"
ls -la

echo
print_info "Looking for Docker Compose files..."

# Check for various compose file names
COMPOSE_FILE=""
COMPOSE_FILES=("docker-compose.yml" "docker-compose.yaml" "compose.yml" "compose.yaml")

for file in "${COMPOSE_FILES[@]}"; do
    if [ -f "$file" ]; then
        COMPOSE_FILE="$file"
        print_status "Found Docker Compose file: $file"
        break
    fi
done

# If no standard compose file found, look for any .yml or .yaml files
if [ -z "$COMPOSE_FILE" ]; then
    print_warning "No standard compose file found. Looking for any .yml/.yaml files..."
    
    # Find any compose-like files
    YAML_FILES=$(find . -maxdepth 1 -name "*.yml" -o -name "*.yaml" 2>/dev/null)
    
    if [ -n "$YAML_FILES" ]; then
        print_info "Found these YAML files:"
        echo "$YAML_FILES"
        
        # Ask user to select
        echo
        print_info "Please specify your Docker Compose file name:"
        read -p "Enter the compose file name (or press Enter if none of these are compose files): " user_file
        
        if [ -n "$user_file" ] && [ -f "$user_file" ]; then
            COMPOSE_FILE="$user_file"
            print_status "Using compose file: $COMPOSE_FILE"
        fi
    fi
fi

if [ -z "$COMPOSE_FILE" ]; then
    print_error "No Docker Compose file found!"
    print_info "Please ensure you're in the correct directory with a docker-compose.yml file"
    print_info "Or create a minimal compose file first"
    exit 1
fi

# Show compose file content (first 20 lines)
echo
print_info "Preview of $COMPOSE_FILE (first 20 lines):"
head -20 "$COMPOSE_FILE"

echo
print_info "Checking for running containers..."
docker compose -f "$COMPOSE_FILE" ps 2>/dev/null || echo "No containers currently running"

echo
echo "🔍 Starting fixes..."
echo "==================="

# 1. Fix mcp-gateway regex issue
echo
print_info "Step 1: Fixing mcp-gateway regex syntax error..."

# Find the mcp-gateway server.js file with more comprehensive search
MCP_SERVER_FILE=""
SEARCH_PATHS=(
    "mcp-gateway/server.js"
    "services/mcp-gateway/server.js" 
    "src/mcp-gateway/server.js"
    "gateway/server.js"
    "mcp/server.js"
)

for path in "${SEARCH_PATHS[@]}"; do
    if [ -f "$path" ]; then
        MCP_SERVER_FILE="$path"
        break
    fi
done

# If still not found, do a comprehensive search
if [ -z "$MCP_SERVER_FILE" ]; then
    print_info "Searching for server.js files..."
    MCP_SERVER_FILE=$(find . -name "server.js" -exec grep -l "(?i)" {} \; 2>/dev/null | head -1)
fi

if [ -n "$MCP_SERVER_FILE" ] && [ -f "$MCP_SERVER_FILE" ]; then
    print_status "Found server.js with regex issue at: $MCP_SERVER_FILE"
    
    # Show the problematic line
    print_info "Current problematic regex line:"
    grep -n "(?i)" "$MCP_SERVER_FILE" || print_warning "Could not find (?i) pattern"
    
    # Create backup
    cp "$MCP_SERVER_FILE" "$MCP_SERVER_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    print_status "Created backup: $MCP_SERVER_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Fix the regex syntax
    # Replace (?i) at the beginning with i flag at the end
    sed -i.tmp 's|/(?i)\([^/]*\)/|/\1/i|g' "$MCP_SERVER_FILE"
    rm -f "$MCP_SERVER_FILE.tmp"
    
    print_status "Fixed regex syntax in $MCP_SERVER_FILE"
    
    # Show the fixed line
    print_info "Fixed regex line:"
    grep -n "/.*[^)]i" "$MCP_SERVER_FILE" | head -5 || echo "  (Fixed - no more (?i) patterns)"
    
else
    print_warning "Could not find mcp-gateway server.js file with regex issues"
    print_info "If you have this file, manually change patterns like:"
    print_info "  FROM: /(?i)(pattern)/   TO: /(pattern)/i"
fi

# 2. Fix nginx permission issues
echo
print_info "Step 2: Fixing nginx permission issues..."

# Create nginx configuration directory
NGINX_CONF_DIR="nginx-config"
mkdir -p "$NGINX_CONF_DIR"

print_status "Created nginx config directory: $NGINX_CONF_DIR"

# Create nginx.conf with proper temp paths
cat > "$NGINX_CONF_DIR/nginx.conf" << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /var/run/nginx.pid;

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
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    server {
        listen 80;
        server_name localhost;
        
        root /usr/share/nginx/html;
        index index.html index.htm;
        
        location / {
            try_files $uri $uri/ /index.html;
        }
        
        # Proxy API requests to pen-mcp-server
        location /api/ {
            proxy_pass http://pen-mcp-server:3001;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }
        
        # Health check endpoint
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
        
        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
            root /usr/share/nginx/html;
        }
    }
}
EOF

print_status "Created optimized nginx.conf"

# Create init script for nginx
cat > "$NGINX_CONF_DIR/init-nginx.sh" << 'EOF'
#!/bin/sh
echo "Initializing nginx temp directories..."
mkdir -p /tmp/nginx_client_temp
mkdir -p /tmp/nginx_proxy_temp  
mkdir -p /tmp/nginx_fastcgi_temp
mkdir -p /tmp/nginx_uwsgi_temp
mkdir -p /tmp/nginx_scgi_temp
chmod 755 /tmp/nginx_*
echo "Nginx temp directories created successfully"
EOF

chmod +x "$NGINX_CONF_DIR/init-nginx.sh"
print_status "Created nginx initialization script"

# 3. Show docker-compose modifications needed
echo
print_info "Step 3: Docker Compose modifications needed..."

# Create a backup of compose file
cp "$COMPOSE_FILE" "$COMPOSE_FILE.backup.$(date +%Y%m%d_%H%M%S)"
print_status "Created backup: $COMPOSE_FILE.backup.$(date +%Y%m%d_%H%M%S)"

echo
print_warning "MANUAL STEP REQUIRED:"
print_info "Add these volumes to your pen-frontend service in $COMPOSE_FILE:"
echo
echo "  pen-frontend:"
echo "    volumes:"
echo "      - ./$NGINX_CONF_DIR/nginx.conf:/etc/nginx/nginx.conf:ro"
echo "      - ./$NGINX_CONF_DIR/init-nginx.sh:/docker-entrypoint.d/99-init.sh:ro"
echo

# Ask if user wants to attempt automatic modification
read -p "Should I try to automatically add these volumes to your compose file? (y/N): " auto_modify

if [[ $auto_modify =~ ^[Yy]$ ]]; then
    print_info "Attempting to modify $COMPOSE_FILE..."
    
    # Simple approach: add volumes if pen-frontend service exists
    if grep -q "pen-frontend:" "$COMPOSE_FILE"; then
        # Create a modified version
        awk -v nginx_dir="$NGINX_CONF_DIR" '
        /pen-frontend:/ { in_frontend=1 }
        /^[[:space:]]*[a-zA-Z-]+:/ && !/pen-frontend:/ { in_frontend=0 }
        /^[[:space:]]*volumes:/ && in_frontend==1 { 
            print $0
            print "      - ./" nginx_dir "/nginx.conf:/etc/nginx/nginx.conf:ro"
            print "      - ./" nginx_dir "/init-nginx.sh:/docker-entrypoint.d/99-init.sh:ro"
            next
        }
        /^[[:space:]]*image:/ && in_frontend==1 && !volumes_added {
            print $0
            print "    volumes:"
            print "      - ./" nginx_dir "/nginx.conf:/etc/nginx/nginx.conf:ro"  
            print "      - ./" nginx_dir "/init-nginx.sh:/docker-entrypoint.d/99-init.sh:ro"
            volumes_added=1
            next
        }
        { print }
        ' "$COMPOSE_FILE" > "$COMPOSE_FILE.tmp" && mv "$COMPOSE_FILE.tmp" "$COMPOSE_FILE"
        
        print_status "Automatically added volumes to $COMPOSE_FILE"
    else
        print_warning "Could not find pen-frontend service in compose file"
    fi
fi

# 4. Restart services
echo
print_info "Step 4: Restarting services..."

print_status "Stopping all services..."
docker compose -f "$COMPOSE_FILE" down

print_status "Removing old containers and images..."
docker compose -f "$COMPOSE_FILE" down --remove-orphans
docker compose -f "$COMPOSE_FILE" build --no-cache

print_status "Starting services..."
docker compose -f "$COMPOSE_FILE" up -d

# 5. Wait and check status
echo
print_info "Waiting for services to start..."
sleep 15

echo
print_info "Final service status:"
docker compose -f "$COMPOSE_FILE" ps

echo
print_info "Service logs (last 10 lines each):"
echo "----------------------------------------"

# Show recent logs for each service
for service in $(docker compose -f "$COMPOSE_FILE" config --services); do
    echo
    print_info "Logs for $service:"
    docker compose -f "$COMPOSE_FILE" logs --tail=10 "$service" 2>/dev/null || echo "  No logs available"
done

echo
echo "🎉 Fix script completed!"
echo "======================="

print_status "Summary of changes made:"
echo "  ✅ Fixed regex syntax errors (if found)"
echo "  ✅ Created nginx configuration with proper temp directories"
echo "  ✅ Created backups of modified files"
echo "  ✅ Restarted all services"

echo
print_info "If issues persist, check individual service logs:"
echo "  docker compose logs mcp-gateway"
echo "  docker compose logs pen-frontend" 
echo "  docker compose logs pen-mcp-server"

echo
print_info "Test your application:"
echo "  curl http://localhost:3001/health  # pen-mcp-server health"
echo "  curl http://localhost/health       # nginx health (if exposed)"
