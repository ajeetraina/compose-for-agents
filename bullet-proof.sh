#!/bin/bash

# Bulletproof fix - completely start fresh with nginx

echo "🛡️ Bulletproof Fix - Starting completely fresh..."
echo "==============================================="

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

# Step 1: Nuclear option - remove all nginx configs and start fresh
print_info "Step 1: Cleaning up all nginx configurations..."

docker compose down
sleep 2

# Remove all nginx config directories to start fresh
rm -rf nginx-config nginx-working 2>/dev/null || true
print_status "Removed all previous nginx configurations"

# Step 2: Create the simplest possible working nginx setup
print_info "Step 2: Creating the simplest possible nginx setup..."

mkdir -p frontend

# Create the simplest nginx config that just works
cat > frontend/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Disable all temp directories and caching to avoid permission issues
    proxy_temp_path off;
    fastcgi_temp_path off;
    uwsgi_temp_path off;
    scgi_temp_path off;
    client_body_temp_path off;
    
    sendfile on;
    keepalive_timeout 65;
    
    server {
        listen 80;
        server_name localhost;
        
        root /usr/share/nginx/html;
        index index.html;
        
        location / {
            try_files $uri $uri/ /index.html;
        }
        
        location /health {
            return 200 "OK";
            add_header Content-Type text/plain;
        }
        
        location /api/ {
            proxy_pass http://host.docker.internal:3001;
            proxy_set_header Host $host;
            proxy_buffering off;
        }
    }
}
EOF

print_status "Created minimal nginx.conf"

# Create simple HTML
cat > frontend/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>🖊️ Pen Shop - Working!</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f0f2f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; text-align: center; }
        .status { padding: 15px; margin: 20px 0; border-radius: 5px; }
        .success { background: #d4edda; border: 1px solid #c3e6cb; color: #155724; }
        button { background: #007bff; color: white; border: none; padding: 10px 20px; border-radius: 5px; margin: 10px; cursor: pointer; }
        #result { margin: 20px 0; padding: 15px; background: #f8f9fa; border: 1px solid #dee2e6; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🖊️ Pen Shop - Frontend Working!</h1>
        
        <div class="status success">
            ✅ Nginx is running successfully!
        </div>
        
        <h3>Test Services:</h3>
        <button onclick="test('/health')">Test Nginx Health</button>
        <button onclick="test('/api/health')">Test Pen Server API</button>
        <button onclick="testDirect()">Test Pen Server Direct</button>
        
        <div id="result">Click buttons above to test services...</div>
    </div>
    
    <script>
        async function test(url) {
            const result = document.getElementById('result');
            result.innerHTML = '⏳ Testing ' + url + '...';
            
            try {
                const response = await fetch(url);
                const text = await response.text();
                result.innerHTML = `✅ ${url} works!\nStatus: ${response.status}\nResponse: ${text}`;
            } catch (error) {
                result.innerHTML = `❌ ${url} failed: ${error.message}`;
            }
        }
        
        async function testDirect() {
            const result = document.getElementById('result');
            result.innerHTML = '⏳ Testing pen server directly...';
            
            try {
                const response = await fetch('http://localhost:3001/health');
                const text = await response.text();
                result.innerHTML = `✅ Direct connection works!\nStatus: ${response.status}\nResponse: ${text}`;
            } catch (error) {
                result.innerHTML = `❌ Direct connection failed: ${error.message}`;
            }
        }
        
        // Auto test on load
        setTimeout(() => test('/health'), 1000);
    </script>
</body>
</html>
EOF

print_status "Created simple HTML interface"

# Step 3: Create completely new docker-compose.override.yml
print_info "Step 3: Creating completely new docker-compose.override.yml..."

cat > docker-compose.override.yml << 'EOF'
services:
  pen-frontend:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./frontend/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./frontend/index.html:/usr/share/nginx/html/index.html:ro
    extra_hosts:
      - "host.docker.internal:host-gateway"
    depends_on:
      - pen-mcp-server
    healthcheck:
      test: ["CMD", "nc", "-z", "localhost", "80"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
    restart: unless-stopped

  pen-mcp-server:
    healthcheck:
      test: ["CMD", "nc", "-z", "localhost", "3001"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 15s

  mcp-gateway:
    healthcheck:
      test: ["CMD", "nc", "-z", "localhost", "8080"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 15s
EOF

print_status "Created new docker-compose.override.yml"

# Step 4: Start services
print_info "Step 4: Starting services with bulletproof configuration..."

docker compose up -d

print_info "Waiting 10 seconds for startup..."
sleep 10

print_info "Current status:"
docker compose ps

# Step 5: Test immediately
print_info "Step 5: Testing services..."

echo
print_info "Testing nginx health:"
curl -s http://localhost/health && print_status "✅ Nginx working!" || print_warning "Nginx not responding yet"

echo
print_info "Testing pen server direct:"
curl -s http://localhost:3001/health && print_status "✅ Pen server working!" || print_warning "Pen server not responding yet"

# Step 6: Alternative approach if still failing
echo
print_info "Step 6: If still not working, trying alternative port..."

if ! curl -s http://localhost/health > /dev/null 2>&1; then
    print_warning "Port 80 approach failed, trying port 8081..."
    
    # Update to use port 8081 instead
    sed -i.bak 's/"80:80"/"8081:80"/' docker-compose.override.yml
    
    docker compose down
    docker compose up -d
    
    sleep 10
    
    print_info "Testing on port 8081:"
    curl -s http://localhost:8081/health && print_status "✅ Working on port 8081!" || print_warning "Still not working"
    
    echo
    print_info "If working on 8081, access your app at: http://localhost:8081"
fi

# Final status
echo
print_info "Final status check:"
docker compose ps

echo
echo "🎉 Bulletproof Fix Complete!"
echo "============================"

print_status "What we did differently:"
echo "  ✅ Completely removed all temp directories from nginx config"
echo "  ✅ Used host.docker.internal for network communication"
echo "  ✅ Created minimal configuration without complex features"
echo "  ✅ Used nc (netcat) for simple health checks"
echo "  ✅ Added fallback to port 8081 if port 80 is blocked"

echo
print_info "Access your application:"
echo "  🌐 Frontend: http://localhost (or http://localhost:8081 if port 80 failed)"
echo "  🔧 Pen Server: http://localhost:3001/health"
echo "  🚪 Gateway: http://localhost:8080"

echo
print_info "If pen-frontend is STILL restarting:"
echo "  docker compose logs pen-frontend"
echo "  docker run --rm -p 8082:80 nginx:alpine  # Test if basic nginx works"

print_status "This should finally work! 🎯"
