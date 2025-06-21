import React, { useState, useEffect } from 'react';

function App() {
  const [internalProducts, setInternalProducts] = useState([]);
  const [externalProducts, setExternalProducts] = useState([]);
  const [serverInfo, setServerInfo] = useState(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    loadInternalProducts();
    loadExternalProducts();
  }, []);

  const loadInternalProducts = async () => {
    try {
      const response = await fetch('http://localhost:3001/api/products');
      const data = await response.json();
      setInternalProducts(data.products || []);
    } catch (error) {
      console.error('Error loading internal products:', error);
    }
  };

  const loadExternalProducts = async () => {
    try {
      const response = await fetch('http://localhost:3001/api/products/external');
      const data = await response.json();
      setExternalProducts(data.products || []);
    } catch (error) {
      console.error('Error loading external products:', error);
    }
  };

  const testLoadBalancing = async () => {
    setLoading(true);
    try {
      const response = await fetch('http://localhost:3001/api/server-info');
      const data = await response.json();
      setServerInfo(data);
    } catch (error) {
      console.error('Error:', error);
      setServerInfo({ error: 'Failed to connect' });
    }
    setLoading(false);
  };

  return (
    <div style={{ maxWidth: '1000px', margin: '0 auto', padding: '20px', fontFamily: 'Arial, sans-serif' }}>
      
      {/* Header */}
      <div style={{ textAlign: 'center', marginBottom: '40px' }}>
        <h1 style={{ color: '#333', fontSize: '2.2rem', marginBottom: '10px' }}>
          🛍️ TechStore
        </h1>
        <p style={{ color: '#666', fontSize: '1.1rem' }}>
          Multi-Tenant E-commerce Platform Demo
        </p>
      </div>

      {/* Store Sections */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '30px', marginBottom: '40px' }}>
        
        {/* Internal Products */}
        <div>
          <h2 style={{ color: '#444', borderBottom: '2px solid #007bff', paddingBottom: '10px' }}>
            📦 Store Catalog
          </h2>
          <p style={{ color: '#666', marginBottom: '20px' }}>
            Products from our main inventory
          </p>
          
          <div style={{ display: 'grid', gap: '15px' }}>
            {internalProducts.map(product => (
              <div key={product.id} style={{
                border: '1px solid #ddd',
                borderRadius: '8px',
                padding: '15px',
                backgroundColor: '#f8f9fa'
              }}>
                <h3 style={{ margin: '0 0 8px 0', color: '#333', fontSize: '1.1rem' }}>
                  {product.name}
                </h3>
                <p style={{ margin: '0 0 8px 0', color: '#28a745', fontWeight: 'bold' }}>
                  ${product.price}
                </p>
                <p style={{ margin: 0, color: '#666', fontSize: '0.9rem' }}>
                  {product.description}
                </p>
              </div>
            ))}
          </div>
        </div>

        {/* External Products */}
        <div>
          <h2 style={{ color: '#444', borderBottom: '2px solid #28a745', paddingBottom: '10px' }}>
            🌐 Partner Catalog
          </h2>
          <p style={{ color: '#666', marginBottom: '20px' }}>
            Products from external suppliers
          </p>
          
          <div style={{ display: 'grid', gap: '15px' }}>
            {externalProducts.map(product => (
              <div key={product.id} style={{
                border: '1px solid #ddd',
                borderRadius: '8px',
                padding: '15px',
                backgroundColor: '#f0f8f0'
              }}>
                <h3 style={{ margin: '0 0 8px 0', color: '#333', fontSize: '1.1rem' }}>
                  {product.name}
                </h3>
                <p style={{ margin: '0 0 8px 0', color: '#28a745', fontWeight: 'bold' }}>
                  ${product.price}
                </p>
                <p style={{ margin: '0 0 8px 0', color: '#666', fontSize: '0.9rem' }}>
                  {product.description}
                </p>
                {product.category && (
                  <span style={{
                    backgroundColor: '#28a745',
                    color: 'white',
                    padding: '2px 6px',
                    borderRadius: '4px',
                    fontSize: '0.8rem'
                  }}>
                    {product.category}
                  </span>
                )}
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Load Balancing Test */}
      <div style={{ 
        backgroundColor: '#f8f9fa', 
        border: '1px solid #dee2e6', 
        borderRadius: '8px', 
        padding: '30px',
        textAlign: 'center'
      }}>
        <h2 style={{ color: '#444', marginBottom: '15px' }}>
          ⚖️ Load Balancing Test
        </h2>
        <p style={{ color: '#666', marginBottom: '20px' }}>
          Click the button to see which backend server handles your request
        </p>
        
        <button 
          onClick={testLoadBalancing}
          disabled={loading}
          style={{
            backgroundColor: loading ? '#6c757d' : '#007bff',
            color: 'white',
            border: 'none',
            padding: '12px 30px',
            borderRadius: '6px',
            fontSize: '16px',
            cursor: loading ? 'not-allowed' : 'pointer',
            marginBottom: '20px'
          }}
        >
          {loading ? 'Testing...' : 'Test Load Balancing'}
        </button>

        {serverInfo && (
          <div style={{
            backgroundColor: 'white',
            border: '1px solid #dee2e6',
            borderRadius: '6px',
            padding: '20px',
            textAlign: 'left'
          }}>
            <h4 style={{ margin: '0 0 15px 0', color: '#333' }}>
              Current Server:
            </h4>
            {serverInfo.error ? (
              <p style={{ color: '#dc3545', margin: 0 }}>
                {serverInfo.error}
              </p>
            ) : (
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                <div>
                  <strong>Pod Name:</strong> {serverInfo.hostname}
                </div>
                <div>
                  <strong>Pod IP:</strong> {serverInfo.podIP}
                </div>
                <div>
                  <strong>Node:</strong> {serverInfo.nodeName}
                </div>
                <div>
                  <strong>Uptime:</strong> {serverInfo.uptime}s
                </div>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Footer */}
      <div style={{ 
        marginTop: '40px', 
        textAlign: 'center', 
        color: '#666',
        borderTop: '1px solid #dee2e6',
        paddingTop: '20px'
      }}>
        <p style={{ margin: 0, fontSize: '0.9rem' }}>
          <strong>Architecture:</strong> React Frontend → Kubernetes Service → Multiple Backend Pods → External Database
        </p>
      </div>
    </div>
  );
}

export default App;