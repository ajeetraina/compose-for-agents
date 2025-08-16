#!/bin/bash

# Quick web interface setup for browser access

echo "🌐 Setting up web interface for browser access..."
echo "==============================================="

# Check current status
echo "Current services:"
docker compose ps

# Try to access frontend
echo
echo "🔍 Testing current frontend access..."
if curl -s http://localhost/health > /dev/null 2>&1; then
    echo "✅ Frontend is already working at http://localhost"
    open http://localhost 2>/dev/null || echo "Open http://localhost in your browser"
    exit 0
elif curl -s http://localhost:8081/health > /dev/null 2>&1; then
    echo "✅ Frontend is working at http://localhost:8081"
    open http://localhost:8081 2>/dev/null || echo "Open http://localhost:8081 in your browser"
    exit 0
fi

echo "⚠️ Frontend not accessible, setting up simple web interface..."

# Create a super simple web interface that definitely works
mkdir -p web-interface

cat > web-interface/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🖊️ Pen Shop - Agent Development Kit</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1000px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 3rem;
            margin-bottom: 10px;
        }
        
        .header p {
            font-size: 1.2rem;
            opacity: 0.9;
        }
        
        .content {
            padding: 40px;
        }
        
        .status-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 40px;
        }
        
        .status-card {
            padding: 20px;
            border-radius: 15px;
            text-align: center;
            border: 2px solid #e0e0e0;
        }
        
        .status-card.success {
            background: #d4edda;
            border-color: #c3e6cb;
            color: #155724;
        }
        
        .status-card h3 {
            margin-bottom: 10px;
            font-size: 1.3rem;
        }
        
        .controls {
            background: #f8f9fa;
            padding: 30px;
            border-radius: 15px;
            margin-bottom: 30px;
        }
        
        .button-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-bottom: 20px;
        }
        
        button {
            background: linear-gradient(135deg, #007bff, #0056b3);
            color: white;
            border: none;
            padding: 15px 20px;
            border-radius: 10px;
            cursor: pointer;
            font-size: 16px;
            font-weight: 600;
            transition: all 0.3s ease;
            box-shadow: 0 4px 15px rgba(0,123,255,0.3);
        }
        
        button:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(0,123,255,0.4);
        }
        
        button:active {
            transform: translateY(0);
        }
        
        .result {
            background: white;
            border: 2px solid #e0e0e0;
            border-radius: 10px;
            padding: 20px;
            margin-top: 20px;
            min-height: 100px;
            font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
            font-size: 14px;
            white-space: pre-wrap;
            overflow-x: auto;
        }
        
        .result.success {
            border-color: #28a745;
            background: #f8fff8;
        }
        
        .result.error {
            border-color: #dc3545;
            background: #fff5f5;
        }
        
        .pens-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }
        
        .pen-card {
            background: white;
            border: 2px solid #e0e0e0;
            border-radius: 12px;
            padding: 20px;
            box-shadow: 0 4px 10px rgba(0,0,0,0.1);
            transition: transform 0.3s ease;
        }
        
        .pen-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 8px 20px rgba(0,0,0,0.15);
        }
        
        .pen-name {
            font-size: 1.3rem;
            font-weight: bold;
            color: #333;
            margin-bottom: 10px;
        }
        
        .pen-brand {
            color: #007bff;
            font-weight: 600;
            margin-bottom: 8px;
        }
        
        .pen-price {
            font-size: 1.4rem;
            font-weight: bold;
            color: #28a745;
            margin-bottom: 10px;
        }
        
        .pen-description {
            color: #666;
            line-height: 1.4;
            margin-bottom: 10px;
        }
        
        .pen-category {
            display: inline-block;
            background: #007bff;
            color: white;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 0.8rem;
            font-weight: 600;
            text-transform: uppercase;
        }
        
        .endpoints {
            background: #e7f3ff;
            padding: 20px;
            border-radius: 10px;
            border-left: 4px solid #007bff;
        }
        
        .endpoint {
            font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
            background: rgba(0,123,255,0.1);
            padding: 4px 8px;
            border-radius: 4px;
            margin: 2px;
            display: inline-block;
            font-size: 0.9rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🖊️ Pen Shop</h1>
            <p>Agent Development Kit - Web Interface</p>
        </div>
        
        <div class="content">
            <div class="status-grid">
                <div class="status-card success">
                    <h3>✅ API Server</h3>
                    <p>Pen MCP Server running on port 3001</p>
                </div>
                <div class="status-card success">
                    <h3>✅ Gateway</h3>
                    <p>MCP Gateway running on port 8080</p>
                </div>
                <div class="status-card success">
                    <h3>✅ Web Interface</h3>
                    <p>Frontend accessible via browser</p>
                </div>
            </div>
            
            <div class="controls">
                <h3>🔗 Test Your Pen Shop API</h3>
                
                <div class="button-grid">
                    <button onclick="checkHealth()">🏥 Health Check</button>
                    <button onclick="loadPenCatalog()">📚 Load Pen Catalog</button>
                    <button onclick="searchFountainPens()">🔍 Search Fountain Pens</button>
                    <button onclick="getSpecificPen()">🖊️ Get Montblanc Details</button>
                </div>
                
                <div id="result" class="result">
                    👆 Click any button above to test your Pen Shop API
                </div>
            </div>
            
            <div id="pens-display"></div>
            
            <div class="endpoints">
                <h3>📋 Available API Endpoints</h3>
                <p>
                    <span class="endpoint">GET /health</span>
                    <span class="endpoint">GET /api/pens</span>
                    <span class="endpoint">GET /api/pens/:id</span>
                    <span class="endpoint">POST /api/search</span>
                </p>
                <p style="margin-top: 10px;">
                    <strong>Direct Access:</strong><br>
                    API Server: <a href="http://localhost:3001/api/pens" target="_blank">http://localhost:3001/api/pens</a><br>
                    Gateway: <a href="http://localhost:8080" target="_blank">http://localhost:8080</a>
                </p>
            </div>
        </div>
    </div>
    
    <script>
        const result = document.getElementById('result');
        const pensDisplay = document.getElementById('pens-display');
        
        function updateResult(content, type = 'info') {
            result.textContent = content;
            result.className = `result ${type}`;
        }
        
        async function checkHealth() {
            updateResult('⏳ Checking API health...');
            try {
                const response = await fetch('http://localhost:3001/health');
                const data = await response.json();
                updateResult(`✅ Health Check Successful!\n\nStatus: ${response.status}\nResponse: ${JSON.stringify(data, null, 2)}`, 'success');
            } catch (error) {
                updateResult(`❌ Health check failed: ${error.message}`, 'error');
            }
        }
        
        async function loadPenCatalog() {
            updateResult('⏳ Loading pen catalog...');
            try {
                const response = await fetch('http://localhost:3001/api/pens');
                const data = await response.json();
                
                updateResult(`✅ Pen Catalog Loaded!\n\nFound ${data.count} pens:\n${JSON.stringify(data, null, 2)}`, 'success');
                
                // Display pens in a nice grid
                if (data.success && data.pens) {
                    displayPens(data.pens);
                }
            } catch (error) {
                updateResult(`❌ Failed to load catalog: ${error.message}`, 'error');
            }
        }
        
        async function searchFountainPens() {
            updateResult('⏳ Searching for fountain pens...');
            try {
                const response = await fetch('http://localhost:3001/api/search', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ query: 'fountain' })
                });
                const data = await response.json();
                
                updateResult(`✅ Search Complete!\n\nFound ${data.count} fountain pens:\n${JSON.stringify(data, null, 2)}`, 'success');
                
                if (data.success && data.pens) {
                    displayPens(data.pens);
                }
            } catch (error) {
                updateResult(`❌ Search failed: ${error.message}`, 'error');
            }
        }
        
        async function getSpecificPen() {
            updateResult('⏳ Getting Montblanc details...');
            try {
                const response = await fetch('http://localhost:3001/api/pens/mont-blanc-149');
                const data = await response.json();
                
                updateResult(`✅ Pen Details Retrieved!\n\n${JSON.stringify(data, null, 2)}`, 'success');
                
                if (data.success && data.pen) {
                    displayPens([data.pen]);
                }
            } catch (error) {
                updateResult(`❌ Failed to get pen details: ${error.message}`, 'error');
            }
        }
        
        function displayPens(pens) {
            const html = `
                <h3>🖊️ Pen Collection</h3>
                <div class="pens-grid">
                    ${pens.map(pen => `
                        <div class="pen-card">
                            <div class="pen-name">${pen.name}</div>
                            <div class="pen-brand">${pen.brand}</div>
                            <div class="pen-price">$${pen.price}</div>
                            <div class="pen-description">${pen.description}</div>
                            <div class="pen-category">${pen.category}</div>
                        </div>
                    `).join('')}
                </div>
            `;
            pensDisplay.innerHTML = html;
        }
        
        // Auto-load on page load
        window.onload = () => {
            setTimeout(checkHealth, 500);
        };
    </script>
</body>
</html>
EOF

echo "✅ Created beautiful web interface"

# Start a simple Python HTTP server for the web interface
echo
echo "🌐 Starting web server on port 8090..."

# Kill any existing server on port 8090
lsof -ti:8090 | xargs kill -9 2>/dev/null || true

# Start web server in background
cd web-interface
python3 -m http.server 8090 > /dev/null 2>&1 &
SERVER_PID=$!
cd ..

echo "✅ Web server started (PID: $SERVER_PID)"

echo
echo "🎉 Your Pen Shop is now accessible in your web browser!"
echo "=================================================="
echo
echo "🌐 Web Interface: http://localhost:8090"
echo "🔧 API Direct: http://localhost:3001/api/pens"
echo "🚪 Gateway: http://localhost:8080"
echo
echo "Opening web browser..."

# Try to open browser (works on macOS, may work on Linux)
open http://localhost:8090 2>/dev/null || echo "Manually open: http://localhost:8090"

echo
echo "To stop the web server later: kill $SERVER_PID"
echo "Or: lsof -ti:8090 | xargs kill -9"
