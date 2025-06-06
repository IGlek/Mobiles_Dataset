-- ===============================================
-- 3.1. EXPLAIN ANALYZE БЕЗ ИНДЕКСОВ
-- ===============================================

-- Инструкция: Выполните эти запросы в pgAdmin после импорта данных

-- 1️⃣ Простой SELECT по названию компании (без индекса)
EXPLAIN ANALYZE
SELECT c.company_name, COUNT(m.model_id) as models_count
FROM companies c
LEFT JOIN models m ON c.company_id = m.company_id
WHERE c.company_name LIKE 'Samsung%'
GROUP BY c.company_name;

-- 2️⃣ JOIN запрос для получения всех моделей с ценами (без индексов)
EXPLAIN ANALYZE
SELECT 
    c.company_name,
    m.model_name,
    m.ram,
    m.battery_capacity,
    r.region_name,
    p.price
FROM models m
JOIN companies c ON m.company_id = c.company_id
JOIN prices p ON m.model_id = p.model_id
JOIN regions r ON p.region_id = r.region_id
WHERE c.company_name = 'Apple'
ORDER BY m.model_name, r.region_name;

-- 3️⃣ Сложный запрос с множественными JOIN и фильтрацией
EXPLAIN ANALYZE
SELECT 
    c.company_name,
    m.model_name,
    pr.processor_name,
    m.launched_year,
    AVG(p.price) as avg_price,
    COUNT(DISTINCT r.region_id) as regions_count
FROM models m
JOIN companies c ON m.company_id = c.company_id
LEFT JOIN processors pr ON m.processor_id = pr.processor_id
JOIN prices p ON m.model_id = p.model_id
JOIN regions r ON p.region_id = r.region_id
WHERE m.launched_year >= 2023
GROUP BY c.company_name, m.model_name, pr.processor_name, m.launched_year
HAVING AVG(p.price) > 500
ORDER BY avg_price DESC;

-- 4️⃣ Запрос поиска по характеристикам устройств
EXPLAIN ANALYZE
SELECT 
    c.company_name,
    m.model_name,
    m.ram,
    m.battery_capacity
FROM models m
JOIN companies c ON m.company_id = c.company_id
WHERE m.ram LIKE '%8GB%' 
  AND m.battery_capacity LIKE '%5000%'
ORDER BY c.company_name, m.model_name;

-- ===============================================
-- СОХРАНИТЕ РЕЗУЛЬТАТЫ EXPLAIN ANALYZE!
-- ===============================================

-- ===============================================
-- 3.2. СОЗДАНИЕ ИНДЕКСОВ И ПОВТОРНЫЙ АНАЛИЗ
-- ===============================================

-- Создаем оптимальные индексы для наших запросов
CREATE INDEX idx_companies_name ON companies(company_name);
CREATE INDEX idx_models_company_id ON models(company_id);
CREATE INDEX idx_models_launched_year ON models(launched_year);
CREATE INDEX idx_prices_model_id ON prices(model_id);
CREATE INDEX idx_prices_region_id ON prices(region_id);

-- Составные индексы для сложных запросов
CREATE INDEX idx_models_ram_battery ON models(ram, battery_capacity);
CREATE INDEX idx_prices_model_region ON prices(model_id, region_id);

-- Функциональные индексы для LIKE запросов
CREATE INDEX idx_companies_name_pattern ON companies(company_name varchar_pattern_ops);

-- Статистика по индексам
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;

-- ===============================================
-- ПОВТОРЯЕМ ВСЕ ЗАПРОСЫ С ИНДЕКСАМИ
-- ===============================================

-- 1️⃣ Простой SELECT по названию компании (С ИНДЕКСОМ)
EXPLAIN ANALYZE
SELECT c.company_name, COUNT(m.model_id) as models_count
FROM companies c
LEFT JOIN models m ON c.company_id = m.company_id
WHERE c.company_name LIKE 'Samsung%'
GROUP BY c.company_name;

-- 2️⃣ JOIN запрос для получения всех моделей с ценами (С ИНДЕКСАМИ)
EXPLAIN ANALYZE
SELECT 
    c.company_name,
    m.model_name,
    m.ram,
    m.battery_capacity,
    r.region_name,
    p.price
FROM models m
JOIN companies c ON m.company_id = c.company_id
JOIN prices p ON m.model_id = p.model_id
JOIN regions r ON p.region_id = r.region_id
WHERE c.company_name = 'Apple'
ORDER BY m.model_name, r.region_name;

-- 3️⃣ Сложный запрос с множественными JOIN и фильтрацией (С ИНДЕКСАМИ)
EXPLAIN ANALYZE
SELECT 
    c.company_name,
    m.model_name,
    pr.processor_name,
    m.launched_year,
    AVG(p.price) as avg_price,
    COUNT(DISTINCT r.region_id) as regions_count
FROM models m
JOIN companies c ON m.company_id = c.company_id
LEFT JOIN processors pr ON m.processor_id = pr.processor_id
JOIN prices p ON m.model_id = p.model_id
JOIN regions r ON p.region_id = r.region_id
WHERE m.launched_year >= 2023
GROUP BY c.company_name, m.model_name, pr.processor_name, m.launched_year
HAVING AVG(p.price) > 500
ORDER BY avg_price DESC;

-- 4️⃣ Запрос поиска по характеристикам устройств (С ИНДЕКСАМИ)
EXPLAIN ANALYZE
SELECT 
    c.company_name,
    m.model_name,
    m.ram,
    m.battery_capacity
FROM models m
JOIN companies c ON m.company_id = c.company_id
WHERE m.ram LIKE '%8GB%' 
  AND m.battery_capacity LIKE '%5000%'
ORDER BY c.company_name, m.model_name;

-- ===============================================
-- АНАЛИЗ ЭФФЕКТИВНОСТИ ИНДЕКСОВ
-- ===============================================

-- Размер индексов
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;

-- Статистика использования таблиц
SELECT 
    schemaname,
    tablename,
    n_tup_ins,
    n_tup_upd,
    n_tup_del,
    seq_scan,
    seq_tup_read,
    idx_scan,
    idx_tup_fetch
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY seq_scan DESC;