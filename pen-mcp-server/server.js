const express = require('express');
const cors = require('cors');

const app = express();
const port = 3001;

app.use(cors());
app.use(express.json());

// Mock pen data for demo
const pens = [
  {
    id: 'mont-blanc-149',
    name: 'Montblanc Meisterstück 149',
    brand: 'Montblanc',
    category: 'luxury',
    price: 745.00,
    description: 'Premium fountain pen with 14k gold nib',
    in_stock: true
  },
  {
    id: 'parker-jotter',
    name: 'Parker Jotter',
    brand: 'Parker',
    category: 'ballpoint',
    price: 15.99,
    description: 'Classic stainless steel ballpoint pen',
    in_stock: true
  },
  {
    id: 'pilot-metropolitan',
    name: 'Pilot Metropolitan',
    brand: 'Pilot',
    category: 'fountain',
    price: 19.95,
    description: 'Contemporary fountain pen with medium nib',
    in_stock: true
  }
];

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'pen-mcp-server' });
});

// MCP Tools endpoints
app.get('/api/pens', (req, res) => {
  const { category, price_range } = req.query;
  let filteredPens = [...pens];
  
  if (category && category !== 'all') {
    filteredPens = filteredPens.filter(pen => pen.category === category);
  }
  
  if (price_range) {
    const ranges = {
      'budget': [0, 25],
      'mid-range': [25, 100],
      'premium': [100, 500],
      'luxury': [500, Infinity]
    };
    const [min, max] = ranges[price_range] || [0, Infinity];
    filteredPens = filteredPens.filter(pen => pen.price >= min && pen.price <= max);
  }
  
  res.json({
    success: true,
    count: filteredPens.length,
    pens: filteredPens
  });
});

app.get('/api/pens/:id', (req, res) => {
  const pen = pens.find(p => p.id === req.params.id);
  if (!pen) {
    return res.status(404).json({ error: 'Pen not found' });
  }
  res.json({ success: true, pen });
});

app.post('/api/search', (req, res) => {
  const { query } = req.body;
  const results = pens.filter(pen => 
    pen.name.toLowerCase().includes(query.toLowerCase()) ||
    pen.brand.toLowerCase().includes(query.toLowerCase()) ||
    pen.description.toLowerCase().includes(query.toLowerCase())
  );
  
  res.json({
    success: true,
    query,
    count: results.length,
    pens: results
  });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`🖊️ Pen MCP Server running on port ${port}`);
  console.log(`Available endpoints:`);
  console.log(`  GET  /health - Health check`);
  console.log(`  GET  /api/pens - Get pen catalog`);
  console.log(`  GET  /api/pens/:id - Get pen details`);
  console.log(`  POST /api/search - Search pens`);
});
