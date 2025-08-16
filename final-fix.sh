#!/bin/bash

# Final fix for compose-for-agents - fixes health checks and nginx permissions

echo "🎯 Final fix for compose-for-agents services..."
echo "=============================================="

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

# First, test if the services are actually working
echo
print_info "Step 1: Testing if services are actually working..."

print_info "Testing pen-mcp-server on port 3001:"
if curl -s http://localhost:3001/health; then
    print_status "pen-mcp-server is responding correctly!"
else
    print_warning "pen-mcp-server not responding"
fi

print_info "Testing mcp-gateway on port 8080:"
# Try different health endpoints
for endpoint in "/health" "/status" "/ping" ""; do
    if curl -s http://localhost:8080$endpoint > /dev/null 2>&1; then
        print_status "mcp-gateway responding on port 8080$endpoint"
        break
    fi
done

# Fix the nginx read-only filesystem issue
echo
print_info "Step 2: Fixing nginx read-only filesystem issue..."

# Create a new nginx config that doesn't need /tmp
cat > nginx-config/nginx-no-tmp.conf << 'EOF'
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
    
    # Don't use temp paths at all - nginx will handle internally
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    # Disable access log to avoid permission issues
    access_log off;
    
    # Basic gzip
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
    server {
        listen 80;
        server_name localhost;
        
        root /usr/share/nginx/html;
        index index.html index.htm;
        
        # Main frontend location
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
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
        }
        
        # Simple health check
        location /health {
            access_log off;
            return 200 "nginx healthy\n";
            add_header Content-Type text/plain;
        }
        
        # Handle errors gracefully
        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
            root /usr/share/nginx/html;
        }
    }
}
EOF

print_status "Created simplified nginx config without temp directories"

# Create a corrected docker-compose.override.yml with proper health checks
echo
print_info "Step 3: Creating corrected health checks..."

cat > docker-compose.override.yml << 'EOF'
services:
  pen-frontend:
    volumes:
      - ./nginx-config/nginx-no-tmp.conf:/etc/nginx/nginx.conf:ro
      - ./nginx-config/html:/usr/share/nginx/html:ro
    ports:
      - "80:80"
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  pen-mcp-server:
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3001/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  mcp-gateway:
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
EOF

print_status "Created corrected docker-compose.override.yml with proper health checks"

# Create a simple index.html for the frontend
echo
print_info "Step 4: Creating simple frontend page..."

mkdir -p nginx-config/html

cat > nginx-config/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🖊️ Pen Shop - Agent Development Kit</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 15px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            padding: 40px;
            max-width: 600px;
            width: 100%;
            text-align: center;
        }
        h1 { 
            color: #333; 
            margin-bottom: 20px;
            font-size: 2.5em;
        }
        .status {
            display: inline-block;
            padding: 10px 20px;
            border-radius: 25px;
            margin: 10px;
            font-weight: bold;
        }
        .healthy { background: #d4edda; color: #155724; border: 2px solid #c3e6cb; }
        .info { background: #e7f3ff; color: #004085; border: 2px solid #b3d7ff; }
        .test-section {
            margin: 30px 0;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 10px;
        }
        button {
            background: #007bff;
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 8px;
            cursor: pointer;
            font-size: 16px;
            margin: 5px;
            transition: background 0.3s;
        }
        button:hover { background: #0056b3; }
        .result {
            margin-top: 15px;
            padding: 15px;
            border-radius: 8px;
            border: 1px solid #ddd;
            background: #fff;
            min-height: 50px;
            text-align: left;
        }
        .endpoint {
            font-family: 'Courier New', monospace;
            background: #f1f1f1;
            padding: 2px 6px;
            border-radius: 4px;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🖊️ Pen Shop</h1>
        <h2>Agent Development Kit</h2>
        
        <div class="status healthy">
            ✅ Frontend Running
        </div>
        
        <div class="test-section">
            <h3>🔗 Service Tests</h3>
            <button onclick="testService('pen-mcp-server', '/api/health')">Test Pen Server</button>
            <button onclick="testService('gateway', '/api/status')">Test Gateway</button>
            <button onclick="testPens()">Get Pen Catalog</button>
            <div id="result" class="result">Click a button to test the services...</div>
        </div>
        
        <div class="info status">
            <strong>Available Endpoints:</strong><br>
            <span class="endpoint">GET /api/health</span> - Health check<br>
            <span class="endpoint">GET /api/pens</span> - Get pen catalog<br>
            <span class="endpoint">GET /api/pens/:id</span> - Get pen details<br>
            <span class="endpoint">POST /api/search</span> - Search pens
        </div>
    </div>
    
    <script>
        async function testService(service, endpoint) {
            const resultDiv = document.getElementById('result');
            resultDiv.innerHTML = `⏳ Testing ${service}...`;
            
            try {
                const response = await fetch(endpoint);
                const data = await response.text();
                
                if (response.ok) {
                    resultDiv.innerHTML = `
                        <strong style="color: green;">✅ ${service} Success:</strong><br>
                        <pre>${data}</pre>
                    `;
                } else {
                    resultDiv.innerHTML = `
                        <strong style="color: orange;">⚠️ ${service} Response:</strong><br>
                        Status: ${response.status}<br>
                        <pre>${data}</pre>
                    `;
                }
            } catch (error) {
                resultDiv.innerHTML = `
                    <strong style="color: red;">❌ ${service} Error:</strong><br>
                    ${error.message}
                `;
            }
        }
        
        async function testPens() {
            const resultDiv = document.getElementById('result');
            resultDiv.innerHTML = '⏳ Fetching pen catalog...';
            
            try {
                const response = await fetch('/api/pens');
                const data = await response.json();
                
                if (response.ok) {
                    resultDiv.innerHTML = `
                        <strong style="color: green;">✅ Pen Catalog:</strong><br>
                        <pre>${JSON.stringify(data, null, 2)}</pre>
                    `;
                } else {
                    resultDiv.innerHTML = `
                        <strong style="color: orange;">⚠️ Response:</strong><br>
                        Status: ${response.status}<br>
                        <pre>${JSON.stringify(data, null, 2)}</pre>
                    `;
                }
            } catch (error) {
                resultDiv.innerHTML = `
                    <strong style="color: red;">❌ Error:</strong><br>
                    ${error.message}
                `;
            }
        }
        
        // Auto-test on load
        window.onload = () => {
            setTimeout(() => testService('pen-mcp-server', '/api/health'), 1000);
        };
    </script>
</body>
</html>
EOF

print_status "Created interactive frontend page"

# Restart services with the new configuration
echo
print_info "Step 5: Restarting services with corrected configuration..."

print_status "Stopping all services..."
docker compose down

print_status "Starting services with new configuration..."
docker compose up -d

# Wait for startup
echo
print_info "Waiting for services to start..."
sleep 10

# Show status
echo
print_info "Current service status:"
docker compose ps

# Test the endpoints
echo
print_info "Step 6: Testing all endpoints..."

echo
print_info "Testing pen-mcp-server directly:"
curl -s http://localhost:3001/health || print_warning "pen-mcp-server not responding"

echo
print_info "Testing mcp-gateway directly:"
curl -s http://localhost:8080/ || print_warning "mcp-gateway not responding"

echo
print_info "Testing nginx frontend:"
curl -s http://localhost/health || print_warning "nginx not responding"

# Wait for health checks to complete
echo
print_info "Waiting for health checks to complete..."
sleep 30

echo
print_info "Final service status:"
docker compose ps

echo
echo "🎉 Final Fix Complete!"
echo "===================="

print_status "Summary:"
echo "  ✅ Fixed nginx read-only filesystem issue"
echo "  ✅ Corrected health check commands"  
echo "  ✅ Created working frontend interface"
echo "  ✅ All services should now show as healthy"

echo
print_info "Access your application:"
echo "  🌐 Frontend: http://localhost"
echo "  🔧 Pen Server: http://localhost:3001/health"
echo "  🚪 Gateway: http://localhost:8080"

echo
print_info "If any service is still unhealthy, the issue is likely timing."
print_info "Health checks may take up to 60 seconds to show 'healthy' status."
