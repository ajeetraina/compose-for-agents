#!/usr/bin/env node

const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const { CallToolRequestSchema, ListToolsRequestSchema } = require('@modelcontextprotocol/sdk/types.js');
const axios = require('axios');

class PenShopMCPServer {
  constructor() {
    this.server = new Server({
      name: 'pen-shop-mcp-server',
      version: '1.0.0',
    }, {
      capabilities: {
        tools: {},
      },
    });

    this.penCatalogueUrl = process.env.PEN_CATALOGUE_URL || 'http://localhost:8081';
    this.penUserUrl = process.env.PEN_USER_URL || 'http://localhost:8082';
    this.penOrdersUrl = process.env.PEN_ORDERS_URL || 'http://localhost:8083';
    
    this.setupToolHandlers();
  }

  setupToolHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'get_pen_catalog',
          description: 'Get all available pens from our premium collection',
          inputSchema: {
            type: 'object',
            properties: {
              category: {
                type: 'string',
                description: 'Filter by pen category (ballpoint, fountain, rollerball, luxury)',
                enum: ['ballpoint', 'fountain', 'rollerball', 'luxury', 'all']
              },
              price_range: {
                type: 'string',
                description: 'Filter by price range',
                enum: ['budget', 'mid-range', 'premium', 'luxury']
              }
            }
          }
        },
        {
          name: 'get_pen_details',
          description: 'Get detailed information about a specific pen',
          inputSchema: {
            type: 'object',
            properties: {
              pen_id: {
                type: 'string',
                description: 'The unique identifier of the pen'
              }
            },
            required: ['pen_id']
          }
        },
        {
          name: 'search_pens',
          description: 'Search for pens by name, brand, or description',
          inputSchema: {
            type: 'object',
            properties: {
              query: {
                type: 'string',
                description: 'Search query (pen name, brand, or keywords)'
              }
            },
            required: ['query']
          }
        },
        {
          name: 'recommend_pens',
          description: 'Get personalized pen recommendations based on user preferences',
          inputSchema: {
            type: 'object',
            properties: {
              use_case: {
                type: 'string',
                description: 'Intended use for the pen',
                enum: ['office', 'signature', 'calligraphy', 'everyday', 'gift']
              },
              budget: {
                type: 'number',
                description: 'Maximum budget in USD'
              }
            },
            required: ['use_case']
          }
        }
      ]
    }));

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'get_pen_catalog':
            return await this.getPenCatalog(args);
          case 'get_pen_details':
            return await this.getPenDetails(args);
          case 'search_pens':
            return await this.searchPens(args);
          case 'recommend_pens':
            return await this.recommendPens(args);
          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        return {
          content: [
            {
              type: 'text',
              text: `Error: ${error.message}`
            }
          ]
        };
      }
    });
  }

  async getPenCatalog(args = {}) {
    const mockPens = this.getMockPenData();
    let pens = mockPens;

    if (args.category && args.category !== 'all') {
      pens = pens.filter(pen => pen.category === args.category);
    }

    if (args.price_range) {
      pens = this.filterByPriceRange(pens, args.price_range);
    }

    return {
      content: [
        {
          type: 'text',
          text: `Found ${pens.length} pens in our collection:\n\n${this.formatPenList(pens)}`
        }
      ]
    };
  }

  async getPenDetails(args) {
    const mockPenDetails = {
      'mont-blanc-149': {
        id: 'mont-blanc-149',
        name: 'Montblanc Meisterstück 149 Fountain Pen',
        brand: 'Montblanc',
        category: 'luxury',
        price: 745.00,
        description: 'The flagship fountain pen from Montblanc, featuring precious black resin and gold-plated appointments.',
        in_stock: true,
        rating: 4.8
      },
      'parker-jotter': {
        id: 'parker-jotter',
        name: 'Parker Jotter Ballpoint Pen',
        brand: 'Parker',
        category: 'ballpoint',
        price: 15.99,
        description: 'Iconic design meets reliable performance in this classic ballpoint pen.',
        in_stock: true,
        rating: 4.5
      }
    };

    const pen = mockPenDetails[args.pen_id];
    if (!pen) {
      throw new Error(`Pen with ID '${args.pen_id}' not found`);
    }

    return {
      content: [
        {
          type: 'text',
          text: this.formatPenDetails(pen)
        }
      ]
    };
  }

  async searchPens(args) {
    const mockResults = this.getMockPenData().filter(pen => 
      pen.name.toLowerCase().includes(args.query.toLowerCase()) ||
      pen.brand.toLowerCase().includes(args.query.toLowerCase()) ||
      pen.description.toLowerCase().includes(args.query.toLowerCase())
    );

    return {
      content: [
        {
          type: 'text',
          text: `Search results for "${args.query}":\n\n${this.formatPenList(mockResults)}`
        }
      ]
    };
  }

  async recommendPens(args) {
    const recommendations = this.getMockPenData().slice(0, 3);
    
    return {
      content: [
        {
          type: 'text',
          text: `Based on your preferences (${args.use_case}), here are our top recommendations:\n\n${this.formatPenList(recommendations)}`
        }
      ]
    };
  }

  getMockPenData() {
    return [
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
      },
      {
        id: 'cross-century',
        name: 'Cross Century II',
        brand: 'Cross',
        category: 'rollerball',
        price: 85.00,
        description: 'Elegant rollerball with lustrous finishes',
        in_stock: false
      }
    ];
  }

  filterByPriceRange(pens, range) {
    const ranges = {
      'budget': [0, 25],
      'mid-range': [25, 100],
      'premium': [100, 500],
      'luxury': [500, Infinity]
    };

    const [min, max] = ranges[range] || [0, Infinity];
    return pens.filter(pen => pen.price >= min && pen.price <= max);
  }

  formatPenList(pens) {
    return pens.map(pen => 
      `• ${pen.name} by ${pen.brand} - $${pen.price} ${pen.in_stock ? '✅' : '❌'}\n  ${pen.description}`
    ).join('\n\n');
  }

  formatPenDetails(pen) {
    return `${pen.name}\n` +
           `Brand: ${pen.brand}\n` +
           `Category: ${pen.category}\n` +
           `Price: $${pen.price}\n` +
           `Description: ${pen.description}\n` +
           `Rating: ${pen.rating}/5\n` +
           `In Stock: ${pen.in_stock ? 'Yes' : 'No'}`;
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('Pen Shop MCP Server running on stdio');
  }
}

// Start the server
if (require.main === module) {
  const server = new PenShopMCPServer();
  server.run().catch(console.error);
}

module.exports = PenShopMCPServer;
