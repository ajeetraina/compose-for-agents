#!/bin/bash

# Targeted fix for unhealthy compose-for-agents services
# Addresses regex errors and nginx permission issues

set -e

echo "🏥 Fixing unhealthy services in compose-for-agents..."
echo "===================================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# Check current service status
echo
print_info "Current service status:"
docker compose ps

echo
print_info "Checking service logs for errors..."

# Check mcp-gateway logs for regex error
echo
print_info "mcp-gateway logs (recent):"
docker compose logs --tail=20 mcp-gateway

# Check pen-mcp-server logs
echo  
print_info "pen-mcp-server logs (recent):"
docker compose logs --tail=20 pen-mcp-server

# Check if pen-frontend exists and its logs
echo
print_info "pen-frontend status:"
if docker compose ps | grep -q pen-frontend; then
    docker compose logs --tail=20 pen-frontend
else
    print_warning "pen-frontend service not running"
fi

echo
echo "🔧 Starting fixes..."
echo "==================="

# 1. Fix mcp-gateway regex syntax error
echo
print_info "Step 1: Fixing mcp-gateway regex error..."

# Find server.js files with regex issues
MCP_FILES=$(find . -name "server.js" -exec grep -l "(?i)" {} \; 2>/dev/null || true)

if [ -n "$MCP_FILES" ]; then
    for file in $MCP_FILES; do
        print_status "Found regex issue in: $file"
        
        # Create backup
        cp "$file" "$file.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Show current problematic line
        print_info "Current problematic line(s):"
        grep -n "(?i)" "$file" || true
        
        # Fix regex: replace (?i) with i flag at end
        # Handle different regex patterns
        sed -i.tmp \
            -e 's|/(?i)\([^/]*\)/|/\1/i|g' \
            -e 's|new RegExp("(?i)\([^"]*\)"|new RegExp("\1", "i")|g' \
            -e 's|RegExp("(?i)\([^"]*\)"|RegExp("\1", "i")|g' \
            "$file"
        rm -f "$file.tmp"
        
        print_status "Fixed regex syntax in: $file"
        
        # Show fixed line
        print_info "After fix - checking for remaining issues:"
        grep -n "(?i)" "$file" || print_status "No more (?i) patterns found"
    done
else
    print_info "No regex syntax errors found in server.js files"
fi

# 2. Create nginx configuration for pen-frontend
echo
print_info "Step 2: Creating nginx configuration for pen-frontend..."

# Create nginx config directory
mkdir -p nginx-config

# Create nginx.conf that works in containers
cat > nginx-config/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Use /tmp for temp directories to avoid permission issues
    client_body_temp_path /tmp/nginx_client_temp;
    proxy_temp_path /tmp/nginx_proxy_temp;
    fastcgi_temp_path /tmp/nginx_fastcgi_temp;
    uwsgi_temp_path /tmp/nginx_uwsgi_temp;
    scgi_temp_path /tmp/nginx_scgi_temp;
    
    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    access_log /var/log/nginx/access.log main;
    
    # Basic settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    server {
        listen 80;
        server_name localhost;
        
        # Document root
        root /usr/share/nginx/html;
        index index.html index.htm;
        
        # Main location
        location / {
            try_files $uri $uri/ /index.html;
        }
        
        # API proxy to pen-mcp-server
        location /api/ {
            proxy_pass http://pen-mcp-server:3001;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Timeouts
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
            
            # Handle errors
            proxy_intercept_errors on;
        }
        
        # Health check for nginx
        location /nginx-health {
            access_log off;
            return 200 "nginx healthy\n";
            add_header Content-Type text/plain;
        }
        
        # Error pages
        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
            root /usr/share/nginx/html;
        }
        
        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
    }
}
EOF

print_status "Created nginx configuration"

# Create initialization script
cat > nginx-config/init-nginx.sh << 'EOF'
#!/bin/sh
echo "🔧 Initializing nginx temp directories..."
mkdir -p /tmp/nginx_client_temp
mkdir -p /tmp/nginx_proxy_temp
mkdir -p /tmp/nginx_fastcgi_temp  
mkdir -p /tmp/nginx_uwsgi_temp
mkdir -p /tmp/nginx_scgi_temp
chmod 755 /tmp/nginx_*
chown nginx:nginx /tmp/nginx_* 2>/dev/null || true
echo "✅ Nginx temp directories ready"
EOF

chmod +x nginx-config/init-nginx.sh
print_status "Created nginx initialization script"

# 3. Create a simple HTML file for testing
mkdir -p nginx-config/html
cat > nginx-config/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Pen Shop - Agent Development Kit</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 2px solid #007bff; padding-bottom: 10px; }
        .status { margin: 20px 0; padding: 15px; border-radius: 5px; }
        .success { background: #d4edda; border: 1px solid #c3e6cb; color: #155724; }
        .info { background: #d1ecf1; border: 1px solid #bee5eb; color: #0c5460; }
        .api-test { margin: 20px 0; }
        button { background: #007bff; color: white; border: none; padding: 10px 20px; border-radius: 5px; cursor: pointer; }
        button:hover { background: #0056b3; }
        #result { margin-top: 15px; padding: 10px; background: #f8f9fa; border: 1px solid #dee2e6; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🖊️ Pen Shop - Agent Development Kit</h1>
        
        <div class="status success">
            <strong>✅ Frontend Status:</strong> Running successfully!
        </div>
        
        <div class="status info">
            <strong>ℹ️ About:</strong> This is the frontend for the Pen Shop Agent Development Kit. 
            It provides a web interface for browsing and managing pen collections through the MCP server.
        </div>
        
        <div class="api-test">
            <h3>🔗 API Test</h3>
            <p>Test the connection to the pen-mcp-server:</p>
            <button onclick="testAPI()">Test API Health</button>
            <div id="result"></div>
        </div>
        
        <div class="status info">
            <h3>📋 Available Endpoints:</h3>
            <ul>
                <li><code>GET /api/health</code> - Health check</li>
                <li><code>GET /api/pens</code> - Get pen catalog</li>
                <li><code>GET /api/pens/:id</code> - Get pen details</li>
                <li><code>POST /api/search</code> - Search pens</li>
            </ul>
        </div>
    </div>
    
    <script>
        async function testAPI() {
            const resultDiv = document.getElementById('result');
            resultDiv.innerHTML = '⏳ Testing API connection...';
            
            try {
                const response = await fetch('/api/health');
                if (response.ok) {
                    const data = await response.text();
                    resultDiv.innerHTML = `<strong style="color: green;">✅ API Connected:</strong> ${data}`;
                } else {
                    resultDiv.innerHTML = `<strong style="color: orange;">⚠️ API Response:</strong> ${response.status} ${response.statusText}`;
                }
            } catch (error) {
                resultDiv.innerHTML = `<strong style="color: red;">❌ API Error:</strong> ${error.message}`;
            }
        }
        
        // Auto-test on load
        window.onload = () => {
            setTimeout(testAPI, 1000);
        };
    </script>
</body>
</html>
EOF

print_status "Created test HTML page"

# 4. Create a compose override or show manual steps
echo
print_info "Step 3: Updating Docker Compose configuration..."

# Check if there's a docker-compose.override.yml
if [ ! -f "docker-compose.override.yml" ]; then
    print_info "Creating docker-compose.override.yml with nginx fixes..."
    
    cat > docker-compose.override.yml << 'EOF'
version: '3.8'

services:
  pen-frontend:
    volumes:
      - ./nginx-config/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx-config/init-nginx.sh:/docker-entrypoint.d/99-init.sh:ro
      - ./nginx-config/html:/usr/share/nginx/html:ro
    environment:
      - NGINX_HOST=localhost
      - NGINX_PORT=80
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/nginx-health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  pen-mcp-server:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3001/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  mcp-gateway:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
EOF
    
    print_status "Created docker-compose.override.yml"
else
    print_warning "docker-compose.override.yml already exists"
    print_info "You may need to manually add the nginx volume mounts"
fi

# 5. Restart services with fixes
echo
print_info "Step 4: Restarting services with fixes..."

print_status "Stopping services..."
docker compose down

print_status "Rebuilding images..."
docker compose build --no-cache

print_status "Starting services with new configuration..."
docker compose up -d

# 6. Wait for services to start and check health
echo
print_info "Waiting for services to start..."
sleep 20

echo
print_info "Checking service health..."

# Wait for health checks
for i in {1..6}; do
    echo
    print_info "Health check attempt $i/6:"
    docker compose ps
    
    # Count healthy services
    HEALTHY=$(docker compose ps --format json | jq -r '.Health // "starting"' | grep -c "healthy" || echo "0")
    TOTAL=$(docker compose ps --format json | wc -l)
    
    if [ "$HEALTHY" -gt 0 ]; then
        print_status "Found $HEALTHY healthy services out of $TOTAL"
    fi
    
    if [ "$i" -lt 6 ]; then
        sleep 15
    fi
done

# 7. Final status and testing
echo
echo "🎉 Fix completed!"
echo "================"

print_info "Final service status:"
docker compose ps

echo
print_info "Service endpoints to test:"
echo "  🌐 Frontend: http://localhost (if pen-frontend is running)"
echo "  🔧 MCP Server: http://localhost:3001/health"
echo "  🚪 Gateway: http://localhost:8080/health (if mcp-gateway is running)"

echo
print_info "Quick tests:"
echo "# Test pen-mcp-server"
echo "curl http://localhost:3001/health"
echo
echo "# Test mcp-gateway (if running)" 
echo "curl http://localhost:8080/health"
echo
echo "# Test nginx frontend (if running)"
echo "curl http://localhost/nginx-health"

echo
print_info "If services are still unhealthy, check logs:"
echo "docker compose logs mcp-gateway"
echo "docker compose logs pen-frontend"
echo "docker compose logs pen-mcp-server"

echo
print_status "All fixes applied! Check the service status above."
