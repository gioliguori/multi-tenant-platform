import React, { useState, useEffect } from 'react';

function App() {
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [serverInfo, setServerInfo] = useState(null);
  const [dbInfo, setDbInfo] = useState(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    loadProducts();
    loadCategories();
    loadDbInfo();
  }, []);

  const loadProducts = async () => {
    try {
      const response = await fetch('http://localhost:3001/api/products');
      const data = await response.json();
      setProducts(data.products || []);
    } catch (error) {
      console.error('Error loading products:', error);
    }
  };

  const loadCategories = async () => {
    try {
      const response = await fetch('http://localhost:3001/api/categories');
      const data = await response.json();
      setCategories(data.categories || []);
    } catch (error) {
      console.error('Error loading categories:', error);
    }
  };

  const loadDbInfo = async () => {
    try {
      const response = await fetch('http://localhost:3001/api/db-test');
      const data = await response.json();
      setDbInfo(data);
    } catch (error) {
      console.error('Error loading DB info:', error);
    }
  };

  const loadProductsByCategory = async (category) => {
    try {
      setSelectedCategory(category);
      if (category === 'all') {
        loadProducts();
      } else {
        const response = await fetch(`http://localhost:3001/api/products/category/${category}`);
        const data = await response.json();
        setProducts(data.products || []);
      }
    } catch (error) {
      console.error('Error loading products by category:', error);
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

  const getCategoryIcon = (category) => {
    const icons = {
      'Electronics': '📱',
      'Computers': '💻',
      'Audio': '🎧',
      'Tablets': '📟',
      'Gaming': '🎮',
      'Wearables': '⌚'
    };
    return icons[category] || '📦';
  };

  return (
    <div style={{ maxWidth: '1200px', margin: '0 auto', padding: '20px', fontFamily: 'Arial, sans-serif' }}>
      
      {/* Header */}
      <div style={{ textAlign: 'center', marginBottom: '40px' }}>
        <h1 style={{ color: '#333', fontSize: '2.5rem', marginBottom: '10px' }}>
          🛍️ TechStore
        </h1>
        <p style={{ color: '#666', fontSize: '1.2rem', marginBottom: '10px' }}>
          Multi-Tenant Kubernetes Platform Demo
        </p>
        <p style={{ color: '#888', fontSize: '1rem' }}>
          🏗️ <strong>Architecture:</strong> React → Kubernetes Service → PostgreSQL Pod
        </p>
      </div>

      {/* Category Filter */}
      <div style={{ marginBottom: '30px', textAlign: 'center' }}>
        <h3 style={{ color: '#444', marginBottom: '15px' }}>
          🏷️ Filter by Category
        </h3>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '10px', justifyContent: 'center' }}>
          <button
            onClick={() => loadProductsByCategory('all')}
            style={{
              backgroundColor: selectedCategory === 'all' ? '#007bff' : '#f8f9fa',
              color: selectedCategory === 'all' ? 'white' : '#333',
              border: '1px solid #dee2e6',
              padding: '8px 16px',
              borderRadius: '20px',
              cursor: 'pointer',
              fontSize: '14px'
            }}
          >
            📦 All Products
          </button>
          {categories.map(cat => (
            <button
              key={cat.category}
              onClick={() => loadProductsByCategory(cat.category)}
              style={{
                backgroundColor: selectedCategory === cat.category ? '#28a745' : '#f8f9fa',
                color: selectedCategory === cat.category ? 'white' : '#333',
                border: '1px solid #dee2e6',
                padding: '8px 16px',
                borderRadius: '20px',
                cursor: 'pointer',
                fontSize: '14px'
              }}
            >
              {getCategoryIcon(cat.category)} {cat.category} ({cat.product_count})
            </button>
          ))}
        </div>
      </div>

      {/* Products Grid */}
      <div style={{ marginBottom: '40px' }}>
        <h2 style={{ color: '#444', borderBottom: '2px solid #007bff', paddingBottom: '10px', marginBottom: '20px' }}>
          🛒 Product Catalog
          {selectedCategory !== 'all' && (
            <span style={{ color: '#666', fontSize: '1rem', fontWeight: 'normal' }}>
              {' '} - {selectedCategory} Category
            </span>
          )}
        </h2>
        
        <div style={{ 
          display: 'grid', 
          gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', 
          gap: '20px' 
        }}>
          {products.map(product => (
            <div key={product.id} style={{
              border: '1px solid #ddd',
              borderRadius: '12px',
              padding: '20px',
              backgroundColor: '#fff',
              boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
              transition: 'transform 0.2s',
              cursor: 'pointer'
            }}
            onMouseEnter={(e) => e.target.style.transform = 'translateY(-2px)'}
            onMouseLeave={(e) => e.target.style.transform = 'translateY(0)'}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '10px' }}>
                <h3 style={{ margin: 0, color: '#333', fontSize: '1.1rem', flex: 1 }}>
                  {getCategoryIcon(product.category)} {product.name}
                </h3>
                <span style={{
                  backgroundColor: '#007bff',
                  color: 'white',
                  padding: '4px 8px',
                  borderRadius: '12px',
                  fontSize: '0.75rem',
                  marginLeft: '10px'
                }}>
                  {product.category}
                </span>
              </div>
              
              <p style={{ margin: '0 0 10px 0', color: '#28a745', fontWeight: 'bold', fontSize: '1.2rem' }}>
                ${product.price}
              </p>
              
              <p style={{ margin: '0 0 10px 0', color: '#666', fontSize: '0.9rem', lineHeight: '1.4' }}>
                {product.description}
              </p>
              
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: '15px' }}>
                <span style={{ 
                  color: product.stock_quantity > 20 ? '#28a745' : product.stock_quantity > 5 ? '#ffc107' : '#dc3545',
                  fontSize: '0.85rem',
                  fontWeight: 'bold'
                }}>
                  📦 Stock: {product.stock_quantity}
                </span>
                <button style={{
                  backgroundColor: '#28a745',
                  color: 'white',
                  border: 'none',
                  padding: '6px 12px',
                  borderRadius: '6px',
                  fontSize: '0.85rem',
                  cursor: 'pointer'
                }}>
                  Add to Cart
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Load Balancing Test */}
      <div style={{ 
        backgroundColor: '#f8f9fa', 
        border: '1px solid #dee2e6', 
        borderRadius: '12px', 
        padding: '30px',
        textAlign: 'center'
      }}>
        <h2 style={{ color: '#444', marginBottom: '15px' }}>
          ⚖️ Kubernetes Load Balancing Test
        </h2>
        <p style={{ color: '#666', marginBottom: '20px' }}>
          Click the button to see which backend pod handles your request
        </p>
        
        <button 
          onClick={testLoadBalancing}
          disabled={loading}
          style={{
            backgroundColor: loading ? '#6c757d' : '#007bff',
            color: 'white',
            border: 'none',
            padding: '12px 30px',
            borderRadius: '8px',
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
            borderRadius: '8px',
            padding: '20px',
            textAlign: 'left'
          }}>
            <h4 style={{ margin: '0 0 15px 0', color: '#333' }}>
              🖥️ Current Backend Server:
            </h4>
            {serverInfo.error ? (
              <p style={{ color: '#dc3545', margin: 0 }}>
                {serverInfo.error}
              </p>
            ) : (
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px', fontSize: '0.9rem' }}>
                <div><strong>Pod Name:</strong> {serverInfo.hostname}</div>
                <div><strong>Pod IP:</strong> {serverInfo.podIP}</div>
                <div><strong>Kubernetes Node:</strong> {serverInfo.nodeName}</div>
                <div><strong>Namespace:</strong> {serverInfo.namespace}</div>
                <div><strong>Uptime:</strong> {serverInfo.uptime}s</div>
                <div><strong>Architecture:</strong> {serverInfo.architecture}</div>
                <div><strong>Load Balancer:</strong> {serverInfo.load_balancer}</div>
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
        <p style={{ margin: '0 0 10px 0', fontSize: '0.9rem' }}>
          <strong>🏗️ Multi-Tenant Kubernetes Architecture</strong>
        </p>
        <p style={{ margin: 0, fontSize: '0.8rem', color: '#888' }}>
          React Frontend → Kubernetes Service → Backend Pods → PostgreSQL Pod
          <br />
          🔒 Network Policies • 📊 Resource Quotas • ⚖️ Load Balancing • 📈 Auto-scaling
        </p>
      </div>
    </div>
  );
}

export default App;