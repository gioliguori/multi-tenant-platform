import React, { useState, useEffect } from 'react';

const App = () => {
  const [products, setProducts] = useState([]);
  const [serverInfo, setServerInfo] = useState(null);
  const [loading, setLoading] = useState(false);

  // Load products on component mount
  useEffect(() => {
    loadProducts();
  }, []);

  const loadProducts = async () => {
    try {
      // Port-forward: frontend su 3000, backend su 3001
      const response = await fetch('http://localhost:3001/api/products');
      const data = await response.json();
      setProducts(data.products || []);
    } catch (error) {
      console.error('Error loading products:', error);
      setProducts([]);
    }
  };

  const testLoadBalancing = async () => {
    setLoading(true);
    try {
      // Port-forward: backend su 3001
      const response = await fetch('http://localhost:3001/api/server-info');
      const data = await response.json();
      setServerInfo(data);
    } catch (error) {
      console.error('Error testing load balancing:', error);
      setServerInfo({ error: 'Failed to connect' });
    }
    setLoading(false);
  };

  return (
    <div style={styles.container}>
      
      {/* Header */}
      <header style={styles.header}>
        <h1 style={styles.title}>🛍️ TechStore Demo</h1>
        <p style={styles.subtitle}>Multi-Tenant E-commerce Platform</p>
      </header>

      {/* Products Section */}
      <section style={styles.section}>
        <h2 style={styles.sectionTitle}>🛒 Latest Products</h2>
        <div style={styles.productGrid}>
          {products.length === 0 ? (
            <p style={styles.loading}>Loading products...</p>
          ) : (
            products.map(product => (
              <div key={product.id} style={styles.productCard}>
                <h3 style={styles.productName}>{product.name}</h3>
                <p style={styles.productPrice}>${product.price}</p>
                <p style={styles.productDescription}>{product.description}</p>
              </div>
            ))
          )}
        </div>
      </section>

      {/* Load Balancing Demo Section */}
      <section style={styles.section}>
        <h2 style={styles.sectionTitle}>⚖️ Load Balancing Demo</h2>
        <p style={styles.description}>
          Click the button multiple times to see requests hitting different backend pods
        </p>
        
        <button 
          onClick={testLoadBalancing}
          disabled={loading}
          style={styles.button}
        >
          {loading ? '🔄 Loading...' : '🎯 Test Load Balancing'}
        </button>

        {serverInfo && (
          <div style={styles.serverInfo}>
            <h4 style={styles.serverTitle}>📊 Current Backend Pod:</h4>
            {serverInfo.error ? (
              <p style={styles.error}>{serverInfo.error}</p>
            ) : (
              <div style={styles.podInfo}>
                <div style={styles.podDetail}>
                  <strong>Pod Name:</strong> <span style={styles.highlight}>{serverInfo.hostname}</span>
                </div>
                <div style={styles.podDetail}>
                  <strong>Pod IP:</strong> {serverInfo.podIP}
                </div>
                <div style={styles.podDetail}>
                  <strong>Node:</strong> {serverInfo.nodeName}
                </div>
                <div style={styles.podDetail}>
                  <strong>Timestamp:</strong> {new Date(serverInfo.timestamp).toLocaleTimeString()}
                </div>
              </div>
            )}
          </div>
        )}
      </section>

      {/* Business Value Footer */}
      <footer style={styles.footer}>
        <div style={styles.metrics}>
          <div style={styles.metric}>
            <span style={styles.metricValue}>2</span>
            <span style={styles.metricLabel}>Backend Pods</span>
          </div>
          <div style={styles.metric}>
            <span style={styles.metricValue}>30s</span>
            <span style={styles.metricLabel}>Deploy Time</span>
          </div>
          <div style={styles.metric}>
            <span style={styles.metricValue}>100%</span>
            <span style={styles.metricLabel}>Availability</span>
          </div>
        </div>
        <p style={styles.footerText}>
          <strong>Architecture:</strong> React Frontend → Kubernetes Service → Multiple Backend Pods
        </p>
      </footer>

    </div>
  );
};

// Inline styles for simplicity
const styles = {
  container: {
    maxWidth: '1000px',
    margin: '0 auto',
    padding: '20px',
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
    backgroundColor: '#f5f7fa',
    minHeight: '100vh'
  },
  header: {
    textAlign: 'center',
    marginBottom: '40px',
    padding: '30px',
    backgroundColor: '#ffffff',
    borderRadius: '12px',
    boxShadow: '0 4px 6px rgba(0,0,0,0.1)'
  },
  title: {
    color: '#2d3748',
    margin: '0 0 10px 0',
    fontSize: '2.5rem'
  },
  subtitle: {
    color: '#718096',
    margin: 0,
    fontSize: '1.1rem'
  },
  section: {
    marginBottom: '40px',
    padding: '30px',
    backgroundColor: '#ffffff',
    borderRadius: '12px',
    boxShadow: '0 4px 6px rgba(0,0,0,0.1)'
  },
  sectionTitle: {
    color: '#2d3748',
    marginTop: 0,
    marginBottom: '20px',
    fontSize: '1.5rem'
  },
  description: {
    color: '#4a5568',
    marginBottom: '20px',
    lineHeight: '1.6'
  },
  productGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))',
    gap: '20px'
  },
  productCard: {
    padding: '20px',
    backgroundColor: '#f7fafc',
    borderRadius: '8px',
    border: '1px solid #e2e8f0'
  },
  productName: {
    color: '#2d3748',
    marginTop: 0,
    marginBottom: '10px',
    fontSize: '1.2rem'
  },
  productPrice: {
    color: '#38a169',
    fontWeight: 'bold',
    fontSize: '1.1rem',
    marginBottom: '10px'
  },
  productDescription: {
    color: '#718096',
    margin: 0,
    fontSize: '0.9rem'
  },
  loading: {
    color: '#718096',
    textAlign: 'center',
    fontSize: '1.1rem'
  },
  button: {
    backgroundColor: '#4299e1',
    color: 'white',
    border: 'none',
    padding: '15px 30px',
    borderRadius: '8px',
    cursor: 'pointer',
    fontSize: '16px',
    fontWeight: 'bold',
    transition: 'background-color 0.3s',
    marginBottom: '20px'
  },
  serverInfo: {
    backgroundColor: '#f7fafc',
    padding: '20px',
    borderRadius: '8px',
    border: '1px solid #e2e8f0'
  },
  serverTitle: {
    color: '#2d3748',
    marginTop: 0,
    marginBottom: '15px'
  },
  podInfo: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
    gap: '10px'
  },
  podDetail: {
    color: '#4a5568',
    fontSize: '0.95rem'
  },
  highlight: {
    color: '#e53e3e',
    fontWeight: 'bold',
    backgroundColor: '#fed7d7',
    padding: '2px 6px',
    borderRadius: '4px'
  },
  error: {
    color: '#e53e3e',
    fontWeight: 'bold'
  },
  footer: {
    textAlign: 'center',
    padding: '30px',
    backgroundColor: '#2d3748',
    color: '#e2e8f0',
    borderRadius: '12px'
  },
  metrics: {
    display: 'grid',
    gridTemplateColumns: 'repeat(3, 1fr)',
    gap: '20px',
    marginBottom: '20px'
  },
  metric: {
    textAlign: 'center'
  },
  metricValue: {
    display: 'block',
    fontSize: '2rem',
    fontWeight: 'bold',
    color: '#81e6d9'
  },
  metricLabel: {
    display: 'block',
    fontSize: '0.9rem',
    color: '#a0aec0',
    marginTop: '5px'
  },
  footerText: {
    margin: 0,
    fontSize: '0.95rem',
    color: '#cbd5e0'
  }
};

export default App;