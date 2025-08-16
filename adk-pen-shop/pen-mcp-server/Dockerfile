# Use official Node.js hardened image
FROM node:18-alpine AS builder

# Install only production dependencies
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Production stage - minimal distroless image
FROM gcr.io/distroless/nodejs18-debian12:nonroot

# Copy application code
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --chown=nonroot:nonroot package*.json ./
COPY --chown=nonroot:nonroot index.js ./

# Security: Run as non-root user
USER nonroot

# Expose MCP server port
EXPOSE 3001

# Start the MCP server
CMD ["index.js"]

# Labels for security scanning and provenance
LABEL org.opencontainers.image.title="Pen Shop MCP Server"
LABEL org.opencontainers.image.description="Secure MCP server for pen shop AI agent demo"
LABEL org.opencontainers.image.vendor="Docker"
LABEL org.opencontainers.image.version="1.0.0"
LABEL security.scan.enabled="true"
