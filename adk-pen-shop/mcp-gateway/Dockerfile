FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM gcr.io/distroless/nodejs18-debian12:nonroot

WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --chown=nonroot:nonroot . .

USER nonroot
EXPOSE 8080

CMD ["server.js"]

LABEL org.opencontainers.image.title="MCP Gateway"
LABEL org.opencontainers.image.description="Security gateway for MCP servers"
LABEL security.scan.enabled="true"
