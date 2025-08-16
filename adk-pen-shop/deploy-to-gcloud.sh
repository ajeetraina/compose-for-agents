#!/bin/bash

# Pen Shop Security Demo - Google Cloud Deployment
set -e

PROJECT_ID=${GOOGLE_CLOUD_PROJECT:-"your-project-id"}
REGION=${GOOGLE_CLOUD_REGION:-"us-central1"}

echo "🖊️  Deploying Secure Pen Shop AI Agent Demo to Google Cloud"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"

# Check authentication
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo "❌ Please authenticate: gcloud auth login"
    exit 1
fi

gcloud config set project $PROJECT_ID

# Enable APIs
echo "🔧 Enabling required APIs..."
gcloud services enable cloudbuild.googleapis.com run.googleapis.com containerregistry.googleapis.com

# Build and push images
echo "🏗️  Building images..."
docker build -t gcr.io/$PROJECT_ID/pen-mcp-server:latest ./pen-mcp-server
docker build -t gcr.io/$PROJECT_ID/mcp-gateway:latest ./mcp-gateway

docker push gcr.io/$PROJECT_ID/pen-mcp-server:latest
docker push gcr.io/$PROJECT_ID/mcp-gateway:latest

# Deploy services
echo "🛡️  Deploying MCP Gateway..."
gcloud run deploy mcp-gateway \
    --image gcr.io/$PROJECT_ID/mcp-gateway:latest \
    --platform managed \
    --region $REGION \
    --allow-unauthenticated \
    --port 8080

echo "🖊️  Deploying Pen MCP Server..."
gcloud run deploy pen-mcp-server \
    --image gcr.io/$PROJECT_ID/pen-mcp-server:latest \
    --platform managed \
    --region $REGION \
    --no-allow-unauthenticated \
    --port 3001

# Get URLs
GATEWAY_URL=$(gcloud run services describe mcp-gateway --platform managed --region $REGION --format 'value(status.url)')
MCP_SERVER_URL=$(gcloud run services describe pen-mcp-server --platform managed --region $REGION --format 'value(status.url)')

echo ""
echo "🎉 Deployment Complete!"
echo "=================================="
echo "MCP Gateway URL: $GATEWAY_URL"
echo "MCP Server URL:  $MCP_SERVER_URL"
echo ""
echo "🖊️  Remember: This is how you sell a pen securely in 2025!"
