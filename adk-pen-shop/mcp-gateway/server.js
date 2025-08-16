const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const winston = require('winston');

const app = express();
const port = process.env.PORT || 8080;

// Security middleware
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '1mb' }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 60, // limit each IP to 60 requests per windowMs
  message: 'Rate limit exceeded'
});
app.use(limiter);

// Logger
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.Console()
  ]
});

// Security patterns
const SECRET_PATTERNS = [
  /(?i)(api[_-]?key|apikey|access[_-]?token|secret[_-]?key)/,
  /(?i)(password|passwd|pwd)/,
  /(?i)(bearer\s+[a-zA-Z0-9\-\._~\+\/]+=*)/,
  /(?i)(sk-[a-zA-Z0-9]{20,})/
];

const INJECTION_PATTERNS = [
  /(?i)(ignore\s+(previous|all)\s+instructions)/,
  /(?i)(system\s*:.*overr?ide)/,
  /(?i)(act\s+as\s+a\s+different)/
];

function detectSecrets(text) {
  return SECRET_PATTERNS.some(pattern => pattern.test(text));
}

function detectInjection(text) {
  return INJECTION_PATTERNS.some(pattern => pattern.test(text));
}

function sanitizeOutput(text) {
  let sanitized = text;
  SECRET_PATTERNS.forEach(pattern => {
    sanitized = sanitized.replace(pattern, '[REDACTED]');
  });
  return sanitized;
}

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Metrics endpoint
app.get('/metrics', (req, res) => {
  res.json({
    requests_total: 0,
    blocked_requests: 0,
    secrets_detected: 0,
    injections_blocked: 0
  });
});

// MCP proxy endpoint
app.post('/mcp', (req, res) => {
  const requestBody = JSON.stringify(req.body);
  
  // Check for secrets
  if (detectSecrets(requestBody)) {
    logger.warn('SECURITY: Secret detected in request', { 
      ip: req.ip,
      timestamp: new Date().toISOString()
    });
    return res.status(400).json({ 
      error: 'Request contains sensitive information' 
    });
  }
  
  // Check for prompt injection
  if (detectInjection(requestBody)) {
    logger.warn('SECURITY: Prompt injection detected', { 
      ip: req.ip,
      timestamp: new Date().toISOString()
    });
    return res.status(400).json({ 
      error: 'Request blocked due to security policy violation' 
    });
  }
  
  // Mock response for demo
  const mockResponse = {
    result: "Pen catalog request processed securely",
    data: [
      { name: "Montblanc 149", price: 745, category: "luxury" },
      { name: "Parker Jotter", price: 16, category: "ballpoint" }
    ]
  };
  
  logger.info('MCP request processed', { ip: req.ip });
  res.json(sanitizeOutput(JSON.stringify(mockResponse)));
});

app.listen(port, '0.0.0.0', () => {
  logger.info(`MCP Gateway running on port ${port}`);
});
