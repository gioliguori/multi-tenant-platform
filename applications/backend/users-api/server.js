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
  db_queries_total: 0,
  db_connections_total: 0,
  api_errors_total: 0,
  startup_time: Date.now(),
  db_connection_status: 1  // 1 = connected, 0 = disconnected
};

// PostgreSQL connection pool - Kubernetes service DNS
const pool = new Pool({
  host: 'postgresql.team-backend.svc.cluster.local',
  port: 5432,
  database: 'techstore',
  user: 'postgres',
  password: 'secret123',
  max: 5,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000,
  ssl: false
});

// Test connection on startup
pool.connect()
  .then(client => {
    console.log('✅ Connected to PostgreSQL in Kubernetes');
    client.release();
    metrics.db_connection_status = 1;
  })
  .catch(err => {
    console.error('❌ Failed to connect to PostgreSQL:', err.message);
    metrics.db_connection_status = 0;
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
    database: 'postgresql.team-backend.svc.cluster.local:5432',
    timestamp: new Date().toISOString()
  };
};

// =============================================================================
// ENDPOINTS
// =============================================================================

// ROOT
app.get('/', (req, res) => {
  res.json({
    service: 'TechStore API - Kubernetes Native',
    team: 'backend',
    database: 'postgresql.team-backend.svc.cluster.local:5432',
    architecture: 'multi-tenant-kubernetes',
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
http_requests_total{namespace="team-backend",pod="${podInfo.hostname}",service="techstore-api"} ${metrics.http_requests_total}

# HELP db_queries_total Database queries
# TYPE db_queries_total counter
db_queries_total{namespace="team-backend",pod="${podInfo.hostname}",database="postgresql"} ${metrics.db_queries_total}

# HELP db_connections_total Database connections
# TYPE db_connections_total counter
db_connections_total{namespace="team-backend",pod="${podInfo.hostname}",database="postgresql"} ${metrics.db_connections_total}

# HELP api_errors_total API errors
# TYPE api_errors_total counter
api_errors_total{namespace="team-backend",pod="${podInfo.hostname}",service="techstore-api"} ${metrics.api_errors_total}

# HELP db_connection_status Database connection status (1=connected, 0=disconnected)
# TYPE db_connection_status gauge
db_connection_status{namespace="team-backend",pod="${podInfo.hostname}",database="postgresql",host="postgresql.team-backend.svc.cluster.local"} ${metrics.db_connection_status}

# HELP app_uptime_seconds Application uptime
# TYPE app_uptime_seconds gauge
app_uptime_seconds{namespace="team-backend",pod="${podInfo.hostname}",service="techstore-api"} ${uptime}
`;

  res.set('Content-Type', 'text/plain');
  res.send(prometheusMetrics.trim());
});

// PRODUCTS API
app.get('/api/products', async (req, res) => {
  try {
    metrics.db_queries_total++;
    const startTime = Date.now();
    
    const result = await pool.query(`
      SELECT id, name, description, price, category, stock_quantity
      FROM products 
      ORDER BY category, name
      LIMIT 20
    `);
    
    const duration = Date.now() - startTime;
    metrics.db_connection_status = 1;

    res.json({
      products: result.rows,
      metadata: {
        source: 'postgresql-kubernetes',
        total_products: result.rows.length,
        query_duration_ms: duration,
        connection_status: 'connected',
        ...getPodInfo()
      }
    });

  } catch (error) {
    metrics.api_errors_total++;
    metrics.db_connection_status = 0;
    
    console.error('Database error:', error);
    res.status(503).json({
      error: 'Database connection failed',
      message: error.message,
      connection_status: 'disconnected',
      ...getPodInfo()
    });
  }
});

// PRODUCTS BY CATEGORY
app.get('/api/products/category/:category', async (req, res) => {
  try {
    metrics.db_queries_total++;
    const { category } = req.params;
    const startTime = Date.now();
    
    const result = await pool.query(`
      SELECT id, name, description, price, category, stock_quantity
      FROM products 
      WHERE LOWER(category) = LOWER($1)
      ORDER BY name
    `, [category]);
    
    const duration = Date.now() - startTime;
    metrics.db_connection_status = 1;

    res.json({
      products: result.rows,
      metadata: {
        source: 'postgresql-kubernetes',
        category: category,
        total_products: result.rows.length,
        query_duration_ms: duration,
        connection_status: 'connected',
        ...getPodInfo()
      }
    });

  } catch (error) {
    metrics.api_errors_total++;
    metrics.db_connection_status = 0;
    
    res.status(503).json({
      error: 'Database query failed',
      message: error.message,
      connection_status: 'disconnected',
      ...getPodInfo()
    });
  }
});

// CATEGORIES
app.get('/api/categories', async (req, res) => {
  try {
    metrics.db_queries_total++;
    const startTime = Date.now();
    
    const result = await pool.query(`
      SELECT category, COUNT(*) as product_count
      FROM products 
      GROUP BY category
      ORDER BY category
    `);
    
    const duration = Date.now() - startTime;
    metrics.db_connection_status = 1;

    res.json({
      categories: result.rows,
      metadata: {
        source: 'postgresql-kubernetes',
        total_categories: result.rows.length,
        query_duration_ms: duration,
        connection_status: 'connected',
        ...getPodInfo()
      }
    });

  } catch (error) {
    metrics.api_errors_total++;
    metrics.db_connection_status = 0;
    
    res.status(503).json({
      error: 'Database query failed',
      message: error.message,
      connection_status: 'disconnected',
      ...getPodInfo()
    });
  }
});

// DB TEST
app.get('/api/db-test', async (req, res) => {
  try {
    metrics.db_connections_total++;
    const client = await pool.connect();
    const result = await client.query('SELECT version(), current_database(), current_user');
    const countResult = await client.query('SELECT COUNT(*) as total_products FROM products');
    client.release();
    
    metrics.db_connection_status = 1;
    
    res.json({
      status: 'success',
      connection_status: 'connected',
      database_info: {
        version: result.rows[0].version,
        database: result.rows[0].current_database,
        user: result.rows[0].current_user,
        total_products: parseInt(countResult.rows[0].total_products)
      },
      ...getPodInfo()
    });
    
  } catch (error) {
    metrics.api_errors_total++;
    metrics.db_connection_status = 0;
    
    res.status(503).json({
      status: 'failed',
      connection_status: 'disconnected',
      error: error.message,
      ...getPodInfo()
    });
  }
});

// HEALTH CHECK
app.get('/api/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'techstore-api-kubernetes',
    database: 'postgresql.team-backend.svc.cluster.local',
    ...getPodInfo()
  });
});

// SERVER INFO
app.get('/api/server-info', (req, res) => {
  const podInfo = getPodInfo();
  res.json({
    ...podInfo,
    message: `Request handled by ${podInfo.hostname}`,
    uptime: Math.floor(process.uptime()),
    architecture: 'kubernetes-native',
    load_balancer: 'kubernetes-service'
  });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 TechStore API (Kubernetes Native) running on port ${PORT}`);
  console.log(`🎯 Metrics endpoint: http://localhost:${PORT}/metrics`);
  console.log(`🏷️  Pod: ${getPodInfo().hostname}`);
  console.log(`🗄️  Database: postgresql.team-backend.svc.cluster.local:5432`);
  console.log(`🏗️  Architecture: Multi-tenant Kubernetes`);
});