const express = require('express');
const cors = require('cors');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Simple logging
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Helper function to get pod info
const getPodInfo = () => {
  return {
    hostname: process.env.HOSTNAME || os.hostname(),
    podIP: process.env.POD_IP || 'localhost',
    nodeName: process.env.NODE_NAME || os.hostname(),
    namespace: process.env.NAMESPACE || 'team-backend',
    timestamp: new Date().toISOString()
  };
};

// ROOT - Basic info
app.get('/', (req, res) => {
  res.json({
    service: 'TechStore API',
    message: 'E-commerce Backend Service',
    team: 'backend',
    ...getPodInfo()
  });
});

// PRODUCTS API - Shop products
app.get('/api/products', (req, res) => {
  const products = [
    {
      id: 1,
      name: 'iPhone 15 Pro',
      description: 'Latest smartphone with titanium design and A17 Pro chip',
      price: 999
    },
    {
      id: 2,
      name: 'MacBook Air M3',
      description: '13-inch laptop with M3 chip, 16GB RAM, 512GB SSD',
      price: 1499
    },
    {
      id: 3,
      name: 'AirPods Pro',
      description: 'Wireless earbuds with active noise cancellation',
      price: 249
    },
    {
      id: 4,
      name: 'Nike Air Max 270',
      description: 'Comfortable running shoes with Air Max technology',
      price: 150
    },
    {
      id: 5,
      name: 'Samsung 55" QLED TV',
      description: '4K Smart TV with Quantum Dot technology',
      price: 899
    },
    {
      id: 6,
      name: 'PlayStation 5',
      description: 'Latest gaming console with 825GB SSD',
      price: 499
    },
    {
      id: 7,
      name: 'Coffee Machine Deluxe',
      description: 'Professional espresso machine with milk frother',
      price: 299
    },
    {
      id: 8,
      name: 'Wireless Gaming Mouse',
      description: 'High-precision mouse with RGB lighting',
      price: 79
    }
  ];

  const response = {
    products,
    metadata: {
      total: products.length,
      currency: 'USD',
      ...getPodInfo(),
      message: `Products served by pod: ${getPodInfo().hostname}`
    }
  };

  res.json(response);
});

// SERVER INFO API - Load balancing demo
app.get('/api/server-info', (req, res) => {
  const podInfo = getPodInfo();
  
  res.json({
    ...podInfo,
    message: `🎯 Load balancing demo - Request handled by ${podInfo.hostname}`,
    requestId: Math.random().toString(36).substr(2, 9),
    uptime: Math.floor(process.uptime()),
    loadBalancingDemo: {
      instruction: 'Click multiple times to see different pod hostnames',
      currentPod: podInfo.hostname,
      technology: 'Kubernetes Service + Calico CNI'
    }
  });
});

// HEALTH CHECK API
app.get('/api/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'techstore-api',
    team: 'backend',
    ...getPodInfo()
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Endpoint not found',
    availableEndpoints: [
      'GET / - Service info',
      'GET /api/products - Shop products',
      'GET /api/server-info - Load balancing demo',
      'GET /api/health - Health check'
    ],
    ...getPodInfo()
  });
});

// Error handler
app.use((error, req, res, next) => {
  console.error('API Error:', error);
  res.status(500).json({
    error: 'Internal server error',
    message: 'Something went wrong',
    ...getPodInfo()
  });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('Received SIGTERM, shutting down gracefully');
  process.exit(0);
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 TechStore API running on port ${PORT}`);
  console.log(`🏷️  Pod: ${getPodInfo().hostname}`);
  console.log(`📡 IP: ${getPodInfo().podIP}`);
  console.log(`🎯 Ready for demo!`);
});