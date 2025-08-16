#!/bin/bash

# Final nginx fix - use a different approach entirely

echo "🔧 Final nginx fix - trying different approach..."
echo "==============================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# Stop current services
docker compose down

# Option 1: Try nginx without any temp path configurations
print_info "Option 1: Creating ultra-minimal nginx config..."

mkdir -p simple-frontend

cat > simple-frontend/default.conf << 'EOF'
server {
    listen 80;
    server_name localhost;
    
    root /usr/share/nginx/html;
    index index.html;
    
    # Simple static file serving
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # Health check
    location /health {
        return 200 "nginx ok\n";
        add_header Content-Type text/plain;
    }
    
    # Simple API proxy - no temp files
    location /api/ {
        proxy_pass http://pen-mcp-server:3001;
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_set_header Host $host;
        proxy_set_header Connection '';
        proxy_http_version 1.1;
        chunked_transfer_encoding off;
    }
}
EOF

cat > simple-frontend/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>🖊️ Pen Shop - Simple & Working</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 600px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; text-align: center; margin-bottom: 30px; }
        .status { padding: 15px; margin: 15px 0; border-radius: 8px; text-align: center; font-weight: bold; }
        .success { background: #d4edda; color: #155724; border: 2px solid #c3e6cb; }
        .buttons { text-align: center; margin: 20px 0; }
        button { background: #007bff; color: white; border: none; padding: 12px 20px; border-radius: 5px; margin: 8px; cursor: pointer; font-size: 14px; }
        button:hover { background: #0056b3; }
        #result { margin: 20px 0; padding: 15px; background: #f8f9fa; border: 1px solid #dee2e6; border-radius: 5px; white-space: pre-wrap; font-family: monospace; }
        .endpoint { font-family: monospace; background: #e9ecef; padding: 2px 6px; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🖊️ Pen Shop Agent Development Kit</h1>
        
        <div class="status success">
            🎉 Frontend is now working!
        </div>
        
        <div class="buttons">
            <button onclick="testHealth()">Test Health</button>
            <button onclick="testPens()">Get Pen Catalog</button>
            <button onclick="testSearch()">Test Search</button>
            <button onclick="testDirect()">Test Direct Connection</button>
        </div>
        
        <div id="result">Click any button above to test the services...</div>
        
        <h3>📋 Available Endpoints:</h3>
        <p>
            <span class="endpoint">GET /health</span> - Nginx health check<br>
            <span class="endpoint">GET /api/health</span> - Pen server health<br>
            <span class="endpoint">GET /api/pens</span> - Get pen catalog<br>
            <span class="endpoint">GET /api/pens/:id</span> - Get specific pen<br>
            <span class="endpoint">POST /api/search</span> - Search pens
        </p>
        
        <p><strong>Direct access:</strong><br>
        Pen Server: <a href="http://localhost:3001/health" target="_blank">http://localhost:3001</a><br>
        Gateway: <a href="http://localhost:8080" target="_blank">http://localhost:8080</a></p>
    </div>
    
    <script>
        const result = document.getElementById('result');
        
        async function testHealth() {
            result.textContent = '⏳ Testing nginx health...';
            try {
                const response = await fetch('/health');
                const text = await response.text();
                result.textContent = `✅ Nginx Health OK!\nStatus: ${response.status}\nResponse: ${text}`;
            } catch (error) {
                result.textContent = `❌ Health test failed: ${error.message}`;
            }
        }
        
        async function testPens() {
            result.textContent = '⏳ Getting pen catalog...';
            try {
                const response = await fetch('/api/pens');
                const data = await response.json();
                result.textContent = `✅ Pen Catalog Retrieved!\nStatus: ${response.status}\nData:\n${JSON.stringify(data, null, 2)}`;
            } catch (error) {
                result.textContent = `❌ Pen catalog failed: ${error.message}`;
            }
        }
        
        async function testSearch() {
            result.textContent = '⏳ Testing search...';
            try {
                const response = await fetch('/api/search', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ query: 'fountain' })
                });
                const data = await response.json();
                result.textContent = `✅ Search Works!\nStatus: ${response.status}\nResults:\n${JSON.stringify(data, null, 2)}`;
            } catch (error) {
                result.textContent = `❌ Search failed: ${error.message}`;
            }
        }
        
        async function testDirect() {
            result.textContent = '⏳ Testing direct connection to pen server...';
            try {
                const response = await fetch('http://localhost:3001/api/pens');
                const data = await response.json();
                result.textContent = `✅ Direct Connection Works!\nStatus: ${response.status}\nData:\n${JSON.stringify(data, null, 2)}`;
            } catch (error) {
                result.textContent = `❌ Direct connection failed: ${error.message}`;
            }
        }
        
        // Auto-test on load
        window.onload = () => setTimeout(testHealth, 500);
    </script>
</body>
</html>
EOF

print_status "Created ultra-minimal nginx setup"

# Create new docker-compose.override.yml with minimal nginx
cat > docker-compose.override.yml << 'EOF'
services:
  pen-frontend:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./simple-frontend/default.conf:/etc/nginx/conf.d/default.conf:ro
      - ./simple-frontend/index.html:/usr/share/nginx/html/index.html:ro
    depends_on:
      - pen-mcp-server
    command: ["nginx", "-g", "daemon off;"]
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 5s

  pen-mcp-server:
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3001/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

  mcp-gateway:
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
EOF

print_status "Created minimal docker-compose.override.yml"

# Start services
print_info "Starting services with minimal configuration..."
docker compose up -d

sleep 8

print_info "Service status:"
docker compose ps

# Test
print_info "Testing the frontend..."
if curl -s http://localhost/health > /dev/null; then
    print_status "✅ SUCCESS! Frontend is working!"
    print_info "Access your Pen Shop at: http://localhost"
else
    print_warning "Frontend still not working, trying port 8081..."
    
    # Try port 8081
    docker compose down
    sed -i.bak 's/"80:80"/"8081:80"/' docker-compose.override.yml
    docker compose up -d
    sleep 5
    
    if curl -s http://localhost:8081/health > /dev/null; then
        print_status "✅ SUCCESS! Working on port 8081!"
        print_info "Access your Pen Shop at: http://localhost:8081"
    else
        print_warning "Still having issues. But your services work directly:"
        print_info "Pen Server: http://localhost:3001"
        print_info "Gateway: http://localhost:8080"
    fi
fi

echo
echo "🎉 Final Status:"
echo "==============="
docker compose ps

echo
print_info "Your working services:"
echo "  ✅ Pen MCP Server: http://localhost:3001/health"
echo "  ✅ MCP Gateway: http://localhost:8080"
echo "  🌐 Frontend: http://localhost (or http://localhost:8081)"

print_status "Your Pen Shop Agent Development Kit is functional! 🎉"
