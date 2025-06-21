const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 3000;

// PostgreSQL connection pool with detailed logging
const pool = new Pool({
  host: '172.20.20.15',
  port: 5432,
  database: 'techstore',
  user: 'api',
  password: 'secret123',
  max: 3,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000,
  // Add SSL configuration
  ssl: false,
  // Connection retry
  allowExitOnIdle: true
});

// Test database connection at startup (but don't crash if it fails)
pool.connect()
  .then(client => {
    console.log('✅ Database connected successfully');
    return client.query('SELECT COUNT(*) FROM products');
  })
  .then(result => {
    console.log(`✅ Found ${result.rows[0].count} products in external database`);
    pool.end();
  })
  .catch(err => {
    console.error('❌ Database connection failed:', err.message);
    console.error('❌ Full error:', err);
  });

// Recreate pool for actual use
const workingPool = new Pool({
  host: '172.20.20.15',
  port: 5432,
  database: 'techstore',
  user: 'api',
  password: 'secret123',
  max: 3,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000,
  ssl: false
});

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
    message: 'E-commerce Backend with PostgreSQL External Database',
    team: 'backend',
    database: '172.20.20.15:5432',
    ...getPodInfo()
  });
});

// INTERNAL PRODUCTS API
app.get('/api/products', (req, res) => {
  const products = [
    { id: 1, name: 'iPhone 15 Pro', description: 'Latest smartphone', price: 999 },
    { id: 2, name: 'MacBook Air M3', description: '13-inch laptop', price: 1499 },
    { id: 3, name: 'AirPods Pro', description: 'Wireless earbuds', price: 249 },
    { id: 4, name: 'Nike Air Max 270', description: 'Running shoes', price: 150 }
  ];

  res.json({
    products,
    metadata: {
      total: products.length,
      source: 'internal-catalog',
      ...getPodInfo()
    }
  });
});

// EXTERNAL PRODUCTS API - PostgreSQL
app.get('/api/products/external', async (req, res) => {
  console.log('🔍 Attempting external database connection...');
  
  try {
    const startTime = Date.now();
    
    const result = await workingPool.query(`
      SELECT id, name, description, price, category, stock_quantity, supplier_code
      FROM products 
      WHERE external_source = true 
      ORDER BY category, name
      LIMIT 10
    `);
    
    const duration = Date.now() - startTime;
    console.log(`✅ Database query successful in ${duration}ms`);

    res.json({
      products: result.rows,
      metadata: {
        total: result.rows.length,
        source: 'external-database',
        database_host: '172.20.20.15:5432',
        connection_status: 'connected',
        query_duration_ms: duration,
        ...getPodInfo()
      }
    });

  } catch (error) {
    console.error('❌ External database error:', error.message);
    console.error('❌ Error code:', error.code);
    console.error('❌ Error details:', error);
    
    res.status(503).json({
      error: 'External database connection failed',
      message: error.message,
      error_code: error.code,
      database_host: '172.20.20.15:5432',
      connection_status: 'failed',
      troubleshooting: {
        step_1: 'Check if PostgreSQL container is running',
        step_2: 'Verify network connectivity from Kind to ContainerLab',
        step_3: 'Check PostgreSQL pg_hba.conf configuration'
      },
      ...getPodInfo()
    });
  }
});

// DATABASE CONNECTION TEST
app.get('/api/db-test', async (req, res) => {
  console.log('🧪 Testing database connection...');
  
  try {
    const client = await workingPool.connect();
    const result = await client.query('SELECT version(), current_timestamp, current_database()');
    client.release();
    
    console.log('✅ Database test successful');
    
    res.json({
      status: 'success',
      database_info: result.rows[0],
      connection_pool: {
        total_count: workingPool.totalCount,
        idle_count: workingPool.idleCount,
        waiting_count: workingPool.waitingCount
      },
      ...getPodInfo()
    });
    
  } catch (error) {
    console.error('❌ Database test failed:', error.message);
    
    res.status(503).json({
      status: 'failed',
      error: error.message,
      error_code: error.code,
      ...getPodInfo()
    });
  }
});

// SERVER INFO API - Load balancing demo
app.get('/api/server-info', (req, res) => {
  const podInfo = getPodInfo();
  
  res.json({
    ...podInfo,
    message: `Request handled by ${podInfo.hostname}`,
    requestId: Math.random().toString(36).substr(2, 9),
    uptime: Math.floor(process.uptime())
  });
});

// HEALTH CHECK API
app.get('/api/health', async (req, res) => {
  const health = {
    status: 'healthy',
    service: 'techstore-api',
    team: 'backend',
    checks: {
      api_server: 'healthy',
      external_database: 'checking...'
    },
    ...getPodInfo()
  };

  try {
    await workingPool.query('SELECT 1');
    health.checks.external_database = 'healthy';
  } catch (error) {
    health.checks.external_database = 'unhealthy';
    health.database_error = error.message;
  }

  res.json(health);
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Endpoint not found',
    availableEndpoints: [
      'GET / - Service info',
      'GET /api/products - Internal catalog',
      'GET /api/products/external - External PostgreSQL catalog',
      'GET /api/db-test - Database connection test',
      'GET /api/server-info - Load balancing demo',
      'GET /api/health - Health check'
    ],
    ...getPodInfo()
  });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 TechStore API running on port ${PORT}`);
  console.log(`🏷️  Pod: ${getPodInfo().hostname}`);
  console.log(`🗄️  Database: 172.20.20.15:5432`);
  console.log(`🎯 Ready for PostgreSQL demo!`);
});