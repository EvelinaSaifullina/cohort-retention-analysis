-- Очищенная таблица событий (без дубликатов и NULL user_id)
CREATE TABLE IF NOT EXISTS events_clean AS
SELECT 
    DATE(SUBSTR(event_time, 1, 19)) AS event_date,
    SUBSTR(event_time, 1, 19) AS event_datetime,
    user_id,
    event_type,
    product_id,
    category_id
FROM events
WHERE user_id IS NOT NULL
  AND event_type IN ('view', 'cart', 'purchase')
GROUP BY 
    DATE(SUBSTR(event_time, 1, 19)),
    user_id,
    event_type,
    product_id,
    category_id;

-- Когорты: дата первого события для каждого пользователя
CREATE TABLE IF NOT EXISTS user_cohorts AS
SELECT 
    user_id,
    MIN(event_date) AS cohort_date
FROM events_clean
GROUP BY user_id;

-- Когортный анализ: удержание по дням
WITH user_events_with_day AS (
    SELECT 
        u.user_id,
        u.cohort_date,
        e.event_date,
        julianday(e.event_date) - julianday(u.cohort_date) AS day_number
    FROM user_cohorts u
    JOIN events_clean e ON u.user_id = e.user_id
),
cohort_activity AS (
    SELECT 
        cohort_date,
        day_number,
        COUNT(DISTINCT user_id) AS active_users
    FROM user_events_with_day
    GROUP BY cohort_date, day_number
),
cohort_size AS (
    SELECT 
        cohort_date,
        active_users AS cohort_size
    FROM cohort_activity
    WHERE day_number = 0
)
SELECT   
    ca.cohort_date,
    ca.day_number,
    ca.active_users,
    ROUND(100.0 * ca.active_users / cs.cohort_size, 2) AS retention_rate
FROM cohort_activity ca
JOIN cohort_size cs ON cs.cohort_date = ca.cohort_date
ORDER BY ca.cohort_date, ca.day_number;