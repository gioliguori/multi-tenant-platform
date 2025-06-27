-- Create products table for external catalog
CREATE TABLE IF NOT EXISTS products (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  price DECIMAL(10,2) NOT NULL,
  category VARCHAR(100),
  stock_quantity INTEGER DEFAULT 100,
  external_source BOOLEAN DEFAULT true,
  supplier_code VARCHAR(50),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- External Products Catalog
INSERT INTO products (name, description, price, category, stock_quantity, supplier_code) VALUES
('iPhone 15 Pro Max (External)', 'Latest iPhone from Apple authorized distributor', 1199.99, 'Electronics', 50, 'APPLE-DIST-001'),
('MacBook Pro M3 (External)', '16-inch laptop from Apple enterprise program', 2499.99, 'Computers', 20, 'APPLE-ENT-004'),
('AirPods Max (External)', 'Premium headphones from Apple premium reseller', 549.99, 'Audio', 40, 'APPLE-PREM-007'),
('Sony WH-1000XM5 (External)', 'Noise-canceling headphones from Sony distributor', 399.99, 'Audio', 35, 'SONY-DIST-008'),
('iPad Pro 12.9" (External)', 'Professional tablet from Apple business channel', 1099.99, 'Tablets', 22, 'APPLE-BIZ-010'),
('Microsoft Surface Pro 9 (External)', 'Windows tablet from Microsoft partner', 1299.99, 'Tablets', 15, 'MS-PARTNER-012');

-- Performance indexes
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_products_price ON products(price);
CREATE INDEX idx_products_supplier ON products(supplier_code);
CREATE INDEX idx_products_stock ON products(stock_quantity);

-- Grant permissions for API user
GRANT SELECT, INSERT, UPDATE ON products TO api;
