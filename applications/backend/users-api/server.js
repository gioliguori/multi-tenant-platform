const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 3000;

// =============================================================================
// PROMETHEUS METRICS SETUP
// =============================================================================

let metrics = {
  http_requests_total: 0,
  external_db_queries_total: 0,
  db_connections_total: 0,
  api_errors_total: 0,
  startup_time: Date.now()
};

// PostgreSQL connection pool
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

// Middleware per tracciare requests
app.use((req, res, next) => {
  metrics.http_requests_total++;
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Helper function
const getPodInfo = () => {
  return {
    hostname: process.env.HOSTNAME || os.hostname(),
    podIP: process.env.POD_IP || 'localhost',
    nodeName: process.env.NODE_NAME || os.hostname(),
    namespace: process.env.NAMESPACE || 'team-backend',
    timestamp: new Date().toISOString()
  };
};

// =============================================================================
// ENDPOINTS
// =============================================================================

// ROOT
app.get('/', (req, res) => {
  res.json({
    service: 'TechStore API with Metrics',
    team: 'backend',
    database: '172.20.20.15:5432',
    metrics_endpoint: '/metrics',
    ...getPodInfo()
  });
});

// METRICS ENDPOINT
app.get('/metrics', (req, res) => {
  const podInfo = getPodInfo();
  const uptime = Math.floor((Date.now() - metrics.startup_time) / 1000);

  const prometheusMetrics = `
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{namespace="team-backend",pod="${podInfo.hostname}"} ${metrics.http_requests_total}

# HELP external_db_queries_total External database queries
# TYPE external_db_queries_total counter
external_db_queries_total{namespace="team-backend",pod="${podInfo.hostname}"} ${metrics.external_db_queries_total}

# HELP db_connections_total Database connections
# TYPE db_connections_total counter
db_connections_total{namespace="team-backend",pod="${podInfo.hostname}"} ${metrics.db_connections_total}

# HELP api_errors_total API errors
# TYPE api_errors_total counter
api_errors_total{namespace="team-backend",pod="${podInfo.hostname}"} ${metrics.api_errors_total}

# HELP app_uptime_seconds Application uptime
# TYPE app_uptime_seconds gauge
app_uptime_seconds{namespace="team-backend",pod="${podInfo.hostname}"} ${uptime}
`;

  res.set('Content-Type', 'text/plain');
  res.send(prometheusMetrics.trim());
});

// PRODUCTS API
app.get('/api/products', (req, res) => {
  const products = [
    { id: 1, name: 'iPhone 15 Pro', price: 999 },
    { id: 2, name: 'MacBook Air M3', price: 1499 },
    { id: 3, name: 'AirPods Pro', price: 249 }
  ];

  res.json({
    products,
    metadata: { source: 'internal-catalog', ...getPodInfo() }
  });
});

// EXTERNAL PRODUCTS API
app.get('/api/products/external', async (req, res) => {
  try {
    metrics.external_db_queries_total++;
    const startTime = Date.now();
    
    const result = await workingPool.query(`
      SELECT id, name, description, price, category
      FROM products 
      WHERE external_source = true 
      ORDER BY category, name
      LIMIT 10
    `);
    
    const duration = Date.now() - startTime;

    res.json({
      products: result.rows,
      metadata: {
        source: 'external-database',
        query_duration_ms: duration,
        ...getPodInfo()
      }
    });

  } catch (error) {
    metrics.api_errors_total++;
    res.status(503).json({
      error: 'Database connection failed',
      message: error.message,
      ...getPodInfo()
    });
  }
});

// DB TEST
app.get('/api/db-test', async (req, res) => {
  try {
    metrics.db_connections_total++;
    const client = await workingPool.connect();
    const result = await client.query('SELECT version()');
    client.release();
    
    res.json({
      status: 'success',
      database_info: result.rows[0],
      ...getPodInfo()
    });
    
  } catch (error) {
    metrics.api_errors_total++;
    res.status(503).json({
      status: 'failed',
      error: error.message,
      ...getPodInfo()
    });
  }
});

// HEALTH CHECK
app.get('/api/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'techstore-api-with-metrics',
    ...getPodInfo()
  });
});

// SERVER INFO
app.get('/api/server-info', (req, res) => {
  const podInfo = getPodInfo();
  res.json({
    ...podInfo,
    message: `Request handled by ${podInfo.hostname}`,
    uptime: Math.floor(process.uptime())
  });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 TechStore API with Metrics running on port ${PORT}`);
  console.log(`🎯 Metrics endpoint: http://localhost:${PORT}/metrics`);
  console.log(`🏷️  Pod: ${getPodInfo().hostname}`);
});
