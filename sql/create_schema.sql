-- Создание базы данных
-- Инструкция: Выполните этот скрипт в pgAdmin или psql под пользователем postgres
CREATE DATABASE mobile_devices_db
    WITH 
    OWNER = postgres
    ENCODING = 'UTF8'
    CONNECTION LIMIT = -1;

-- Подключитесь к созданной БД
\c mobile_devices_db;

-- 1. Таблица компаний-производителей
CREATE TABLE companies (
    company_id SERIAL PRIMARY KEY,
    company_name VARCHAR(100) NOT NULL UNIQUE
);

-- 2. Таблица процессоров (справочник)
CREATE TABLE processors (
    processor_id SERIAL PRIMARY KEY,
    processor_name VARCHAR(200) NOT NULL UNIQUE
);

-- 3. Таблица моделей устройств
CREATE TABLE models (
    model_id SERIAL PRIMARY KEY,
    model_name VARCHAR(200) NOT NULL,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    processor_id INTEGER REFERENCES processors(processor_id) ON DELETE SET NULL,
    mobile_weight VARCHAR(50),
    ram VARCHAR(50),
    front_camera VARCHAR(100),
    back_camera VARCHAR(100),
    battery_capacity VARCHAR(50),
    screen_size VARCHAR(50),
    launched_year INTEGER CHECK (launched_year >= 2000 AND launched_year <= 2030),
    UNIQUE(company_id, model_name)
);

-- 4. Таблица регионов/стран
CREATE TABLE regions (
    region_id SERIAL PRIMARY KEY,
    region_name VARCHAR(50) NOT NULL UNIQUE,
    region_code VARCHAR(10) UNIQUE
);

-- 5. Таблица цен в различных регионах
CREATE TABLE prices (
    price_id SERIAL PRIMARY KEY,
    model_id INTEGER NOT NULL REFERENCES models(model_id) ON DELETE CASCADE,
    region_id INTEGER NOT NULL REFERENCES regions(region_id) ON DELETE CASCADE,
    price DECIMAL(10,2) CHECK (price >= 0),
    currency VARCHAR(10) DEFAULT 'USD',
    UNIQUE(model_id, region_id)
);

-- 6. Создание индексов для оптимизации производительности
-- Эти индексы пока не создаем (для выполнения задания с EXPLAIN ANALYZE)
-- CREATE INDEX idx_models_company_id ON models(company_id);
-- CREATE INDEX idx_models_launched_year ON models(launched_year);
-- CREATE INDEX idx_prices_model_id ON prices(model_id);
-- CREATE INDEX idx_prices_region_id ON prices(region_id);
-- CREATE INDEX idx_companies_name ON companies(company_name);
-- CREATE INDEX idx_models_name ON models(model_name);

-- 7. Вставка начальных данных для регионов
INSERT INTO regions (region_name, region_code) VALUES 
    ('Pakistan', 'PK'),
    ('India', 'IN'),
    ('China', 'CN'),
    ('USA', 'US'),
    ('Dubai', 'AE');

-- 8. Создание представлений для удобства работы
CREATE VIEW mobile_full_info AS
SELECT 
    m.model_id,
    c.company_name,
    m.model_name,
    m.mobile_weight,
    m.ram,
    m.front_camera,
    m.back_camera,
    pr.processor_name,
    m.battery_capacity,
    m.screen_size,
    m.launched_year
FROM models m
JOIN companies c ON m.company_id = c.company_id
LEFT JOIN processors pr ON m.processor_id = pr.processor_id;

-- 9. Представление для анализа цен по регионам
CREATE VIEW regional_prices AS
SELECT 
    c.company_name,
    m.model_name,
    r.region_name,
    p.price,
    p.currency,
    m.launched_year
FROM prices p
JOIN models m ON p.model_id = m.model_id
JOIN companies c ON m.company_id = c.company_id
JOIN regions r ON p.region_id = r.region_id
ORDER BY c.company_name, m.model_name, r.region_name;