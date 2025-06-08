-- Create database if it doesn't exist
CREATE DATABASE IF NOT EXISTS fincard_mysql;
USE fincard_mysql;

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    birth_date DATE,
    address VARCHAR(255),
    city VARCHAR(50),
    state VARCHAR(50),
    postal_code VARCHAR(20),
    country VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create cards table
CREATE TABLE IF NOT EXISTS cards (
    card_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    card_number VARCHAR(16) NOT NULL,
    card_type ENUM('classic', 'gold', 'platinum', 'femme', 'optimo') NOT NULL,
    expiry_date DATE NOT NULL,
    credit_limit DECIMAL(12, 2) NOT NULL,
    current_balance DECIMAL(12, 2) DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- Create transactions table
CREATE TABLE IF NOT EXISTS transactions (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    card_id INT NOT NULL,
    amount DECIMAL(12, 2) NOT NULL,
    transaction_type ENUM('purchase', 'payment', 'refund', 'fee', 'interest') NOT NULL,
    merchant_name VARCHAR(100),
    merchant_category VARCHAR(50),
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status ENUM('pending', 'completed', 'declined', 'disputed') DEFAULT 'completed',
    FOREIGN KEY (card_id) REFERENCES cards(card_id)
);

-- Create rewards table
CREATE TABLE IF NOT EXISTS rewards (
    reward_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    points INT DEFAULT 0,
    tier ENUM('bronze', 'silver', 'gold', 'platinum') DEFAULT 'bronze',
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- Insert dummy users (50 users)
INSERT INTO users (first_name, last_name, email, phone, birth_date, address, city, state, postal_code, country)
VALUES
    ('John', 'Smith', 'john.smith@example.com', '555-123-4567', '1985-03-15', '123 Main St', 'New York', 'NY', '10001', 'USA'),
    ('Emma', 'Johnson', 'emma.johnson@example.com', '555-234-5678', '1990-07-22', '456 Oak Ave', 'Los Angeles', 'CA', '90001', 'USA'),
    ('Michael', 'Williams', 'michael.williams@example.com', '555-345-6789', '1978-11-30', '789 Pine Dr', 'Chicago', 'IL', '60601', 'USA'),
    ('Olivia', 'Brown', 'olivia.brown@example.com', '555-456-7890', '1992-05-18', '101 Maple Rd', 'Houston', 'TX', '77001', 'USA'),
    ('William', 'Jones', 'william.jones@example.com', '555-567-8901', '1983-09-25', '202 Cedar St', 'Phoenix', 'AZ', '85001', 'USA'),
    ('Sophia', 'Garcia', 'sophia.garcia@example.com', '555-678-9012', '1995-01-10', '303 Birch Ave', 'Philadelphia', 'PA', '19101', 'USA'),
    ('James', 'Miller', 'james.miller@example.com', '555-789-0123', '1980-06-12', '404 Elm Blvd', 'San Antonio', 'TX', '78201', 'USA'),
    ('Isabella', 'Davis', 'isabella.davis@example.com', '555-890-1234', '1988-12-05', '505 Walnut St', 'San Diego', 'CA', '92101', 'USA'),
    ('Alexander', 'Rodriguez', 'alexander.rodriguez@example.com', '555-901-2345', '1975-04-20', '606 Cherry Dr', 'Dallas', 'TX', '75201', 'USA'),
    ('Mia', 'Martinez', 'mia.martinez@example.com', '555-012-3456', '1993-08-14', '707 Spruce Rd', 'San Jose', 'CA', '95101', 'USA');

-- Insert more dummy users
INSERT INTO users (first_name, last_name, email, phone, birth_date, address, city, state, postal_code, country)
VALUES
    ('Ethan', 'Clark', 'ethan.clark@example.com', '555-111-2222', '1988-04-12', '123 First St', 'Boston', 'MA', '02110', 'USA'),
    ('Ava', 'Walker', 'ava.walker@example.com', '555-222-3333', '1992-08-23', '456 Second Ave', 'Miami', 'FL', '33101', 'USA'),
    ('Benjamin', 'Hall', 'benjamin.hall@example.com', '555-333-4444', '1980-11-05', '789 Third Dr', 'Seattle', 'WA', '98101', 'USA'),
    ('Charlotte', 'Young', 'charlotte.young@example.com', '555-444-5555', '1995-03-18', '101 Fourth Rd', 'Denver', 'CO', '80201', 'USA'),
    ('Lucas', 'King', 'lucas.king@example.com', '555-555-6666', '1984-07-30', '202 Fifth St', 'Atlanta', 'GA', '30301', 'USA');

-- Insert credit cards for users
INSERT INTO cards (user_id, card_number, card_type, expiry_date, credit_limit)
VALUES
    (1, '4111111111111111', 'classic', '2025-05-01', 2000.00),
    (1, '5111111111111118', 'gold', '2026-08-01', 10000.00),
    (2, '4222222222222222', 'platinum', '2025-06-01', 15000.00),
    (3, '4333333333333333', 'classic', '2025-07-01', 1500.00),
    (4, '4444444444444444', 'femme', '2025-08-01', 5000.00),
    (5, '5555555555555555', 'optimo', '2025-09-01', 20000.00),
    (6, '4666666666666666', 'gold', '2025-10-01', 8000.00),
    (7, '4777777777777777', 'classic', '2025-11-01', 3000.00),
    (8, '4888888888888888', 'platinum', '2025-12-01', 18000.00),
    (9, '4999999999999999', 'femme', '2026-01-01', 6000.00),
    (10, '5000000000000000', 'optimo', '2026-02-01', 25000.00),
    (11, '5111111111111111', 'classic', '2026-03-01', 2500.00),
    (12, '5222222222222222', 'gold', '2026-04-01', 9000.00),
    (13, '5333333333333333', 'platinum', '2026-05-01', 20000.00),
    (14, '5444444444444444', 'femme', '2026-06-01', 7000.00),
    (15, '5555555555555555', 'optimo', '2026-07-01', 30000.00);

-- Insert transactions for each card
INSERT INTO transactions (card_id, amount, transaction_type, merchant_name, merchant_category, transaction_date, status)
VALUES
    -- Card 1 transactions
    (1, 42.99, 'purchase', 'Amazon', 'Retail', DATE_SUB(NOW(), INTERVAL 30 DAY), 'completed'),
    (1, 18.50, 'purchase', 'Starbucks', 'Dining', DATE_SUB(NOW(), INTERVAL 28 DAY), 'completed'),
    (1, 125.65, 'purchase', 'Walmart', 'Groceries', DATE_SUB(NOW(), INTERVAL 25 DAY), 'completed'),
    (1, 200.00, 'payment', 'Payment', 'Payment', DATE_SUB(NOW(), INTERVAL 20 DAY), 'completed'),
    (1, 34.99, 'purchase', 'Netflix', 'Entertainment', DATE_SUB(NOW(), INTERVAL 15 DAY), 'completed'),
    (1, 15.75, 'purchase', 'McDonald\'s', 'Dining', DATE_SUB(NOW(), INTERVAL 10 DAY), 'completed'),
    (1, 67.89, 'purchase', 'Shell', 'Gas', DATE_SUB(NOW(), INTERVAL 5 DAY), 'completed'),
    
    -- Card 2 transactions
    (2, 1299.99, 'purchase', 'Best Buy', 'Electronics', DATE_SUB(NOW(), INTERVAL 60 DAY), 'completed'),
    (2, 89.50, 'purchase', 'Nordstrom', 'Retail', DATE_SUB(NOW(), INTERVAL 55 DAY), 'completed'),
    (2, 500.00, 'payment', 'Payment', 'Payment', DATE_SUB(NOW(), INTERVAL 45 DAY), 'completed'),
    (2, 250.00, 'purchase', 'United Airlines', 'Travel', DATE_SUB(NOW(), INTERVAL 40 DAY), 'completed'),
    (2, 120.80, 'purchase', 'Hilton Hotels', 'Travel', DATE_SUB(NOW(), INTERVAL 38 DAY), 'completed'),
    (2, 1000.00, 'payment', 'Payment', 'Payment', DATE_SUB(NOW(), INTERVAL 30 DAY), 'completed'),
    (2, 45.67, 'purchase', 'Uber', 'Transportation', DATE_SUB(NOW(), INTERVAL 20 DAY), 'completed'),
    (2, 189.99, 'purchase', 'Apple', 'Electronics', DATE_SUB(NOW(), INTERVAL 10 DAY), 'completed');

-- Insert more transactions for variety
INSERT INTO transactions (card_id, amount, transaction_type, merchant_name, merchant_category, transaction_date, status)
VALUES
    -- More transactions for different cards and different types
    (3, 75.25, 'purchase', 'Target', 'Retail', DATE_SUB(NOW(), INTERVAL 45 DAY), 'completed'),
    (3, 300.00, 'payment', 'Payment', 'Payment', DATE_SUB(NOW(), INTERVAL 30 DAY), 'completed'),
    (3, 12.99, 'purchase', 'Spotify', 'Entertainment', DATE_SUB(NOW(), INTERVAL 15 DAY), 'completed'),
    (4, 67.50, 'purchase', 'Whole Foods', 'Groceries', DATE_SUB(NOW(), INTERVAL 50 DAY), 'completed'),
    (4, 35.40, 'purchase', 'Chevron', 'Gas', DATE_SUB(NOW(), INTERVAL 40 DAY), 'completed'),
    (4, 29.99, 'fee', 'FinCard', 'Fee', DATE_SUB(NOW(), INTERVAL 30 DAY), 'completed'),
    (4, 400.00, 'payment', 'Payment', 'Payment', DATE_SUB(NOW(), INTERVAL 20 DAY), 'completed'),
    (5, 239.99, 'purchase', 'Home Depot', 'Home Improvement', DATE_SUB(NOW(), INTERVAL 60 DAY), 'completed'),
    (5, 1200.00, 'purchase', 'Delta Airlines', 'Travel', DATE_SUB(NOW(), INTERVAL 45 DAY), 'completed'),
    (5, 25.75, 'refund', 'Amazon', 'Refund', DATE_SUB(NOW(), INTERVAL 30 DAY), 'completed'),
    (5, 1000.00, 'payment', 'Payment', 'Payment', DATE_SUB(NOW(), INTERVAL 15 DAY), 'completed'),
    (6, 87.30, 'purchase', 'Safeway', 'Groceries', DATE_SUB(NOW(), INTERVAL 55 DAY), 'completed'),
    (6, 15.99, 'purchase', 'Lyft', 'Transportation', DATE_SUB(NOW(), INTERVAL 40 DAY), 'completed'),
    (6, 500.00, 'payment', 'Payment', 'Payment', DATE_SUB(NOW(), INTERVAL 25 DAY), 'completed'),
    (6, 45.00, 'interest', 'FinCard', 'Interest', DATE_SUB(NOW(), INTERVAL 10 DAY), 'completed');

-- Update card balances based on their transactions
UPDATE cards c
SET c.current_balance = (
    SELECT COALESCE(SUM(amount), 0)
    FROM transactions t
    WHERE t.card_id = c.card_id
);

-- Insert rewards for users
INSERT INTO rewards (user_id, points, tier)
VALUES
    (1, 1250, 'silver'),
    (2, 3800, 'gold'),
    (3, 500, 'bronze'),
    (4, 2200, 'silver'),
    (5, 5600, 'platinum'),
    (6, 1800, 'silver'),
    (7, 750, 'bronze'),
    (8, 4200, 'gold'),
    (9, 1500, 'silver'),
    (10, 7500, 'platinum'),
    (11, 600, 'bronze'),
    (12, 2100, 'silver'),
    (13, 4800, 'gold'),
    (14, 1300, 'silver'),
    (15, 6200, 'platinum');

-- Create useful views for Metabase dashboards

-- Monthly spending by category
CREATE OR REPLACE VIEW monthly_spending_by_category AS
SELECT 
    DATE_FORMAT(t.transaction_date, '%Y-%m') AS month,
    t.merchant_category,
    SUM(t.amount) AS total_amount,
    COUNT(*) AS transaction_count
FROM transactions t
WHERE t.transaction_type = 'purchase'
GROUP BY DATE_FORMAT(t.transaction_date, '%Y-%m'), t.merchant_category
ORDER BY month, total_amount DESC;

-- User spending patterns
CREATE OR REPLACE VIEW user_spending_patterns AS
SELECT 
    u.user_id,
    CONCAT(u.first_name, ' ', u.last_name) AS user_name,
    c.card_type,
    COUNT(t.transaction_id) AS transaction_count,
    SUM(CASE WHEN t.transaction_type = 'purchase' THEN t.amount ELSE 0 END) AS total_purchases,
    SUM(CASE WHEN t.transaction_type = 'payment' THEN ABS(t.amount) ELSE 0 END) AS total_payments,
    MAX(t.transaction_date) AS last_transaction_date
FROM users u
JOIN cards c ON u.user_id = c.user_id
LEFT JOIN transactions t ON c.card_id = t.card_id
GROUP BY u.user_id, user_name, c.card_type
ORDER BY total_purchases DESC;

-- Card usage by type
CREATE OR REPLACE VIEW card_usage_by_type AS
SELECT 
    c.card_type,
    COUNT(DISTINCT c.card_id) AS card_count,
    COUNT(t.transaction_id) AS transaction_count,
    SUM(CASE WHEN t.transaction_type = 'purchase' THEN t.amount ELSE 0 END) AS total_purchases,
    AVG(c.credit_limit) AS avg_credit_limit,
    AVG(c.current_balance) AS avg_current_balance,
    AVG(c.current_balance / c.credit_limit) * 100 AS avg_utilization_percent
FROM cards c
LEFT JOIN transactions t ON c.card_id = t.card_id
GROUP BY c.card_type
ORDER BY card_count DESC;

-- Transaction statistics by day of week
CREATE OR REPLACE VIEW transactions_by_day_of_week AS
SELECT 
    DAYNAME(t.transaction_date) AS day_of_week,
    DAYOFWEEK(t.transaction_date) AS day_number, -- 1 = Sunday, 7 = Saturday
    COUNT(*) AS transaction_count,
    SUM(CASE WHEN t.transaction_type = 'purchase' THEN t.amount ELSE 0 END) AS total_purchases,
    AVG(CASE WHEN t.transaction_type = 'purchase' THEN t.amount ELSE NULL END) AS avg_purchase_amount
FROM transactions t
GROUP BY DAYNAME(t.transaction_date), DAYOFWEEK(t.transaction_date)
ORDER BY day_number;

-- Top merchants by spend
CREATE OR REPLACE VIEW top_merchants_by_spend AS
SELECT 
    t.merchant_name,
    COUNT(*) AS transaction_count,
    SUM(t.amount) AS total_amount,
    AVG(t.amount) AS avg_transaction_amount,
    MIN(t.transaction_date) AS first_transaction,
    MAX(t.transaction_date) AS last_transaction
FROM transactions t
WHERE t.transaction_type = 'purchase'
GROUP BY t.merchant_name
ORDER BY total_amount DESC
LIMIT 20;