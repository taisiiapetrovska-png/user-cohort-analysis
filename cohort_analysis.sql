-- Clean user data by parsing and standardising signup dates
WITH users_clean AS (
SELECT
        user_id,
        promo_signup_flag,
-- Convert various date formats to a standard date
     CASE
     WHEN LENGTH(SPLIT_PART(clean_date, '-', 3)) = 4
     THEN TO_DATE(clean_date, 'DD-MM-YYYY')
     ELSE TO_DATE(clean_date, 'DD-MM-YY')
     END AS signup_date
FROM (
SELECT
       user_id,
       promo_signup_flag,
-- Remove extraneous characters and standardise delimiters
       REPLACE(REPLACE(REPLACE(SPLIT_PART(TRIM(signup_datetime), ' ', 1), '.', '-'), '/', '-'), '--', '-') AS clean_date
FROM cohort_users_raw
    ) t
),
-- Clean event data by parsing and standardising event dates
events_clean AS (
SELECT
        user_id,
        event_type,
-- Convert various date formats to a standard date
        CASE
        WHEN LENGTH(SPLIT_PART(clean_date, '-', 3)) = 4
        THEN TO_DATE(clean_date, 'DD-MM-YYYY')
        ELSE TO_DATE(clean_date, 'DD-MM-YY')
        END AS event_date
FROM (
SELECT
       user_id,
       event_type,
-- Remove extraneous characters and standardise delimiters
       REPLACE(REPLACE(REPLACE(SPLIT_PART(TRIM(event_datetime), ' ', 1), '.', '-'), '/', '-'), '--', '-') AS clean_date
FROM cohort_events_raw
    ) t
),
-- Join cleaned user and event data, calculate cohort and activity month
joined_data AS (
SELECT
        u.user_id,
        u.promo_signup_flag,
        DATE_TRUNC('month', u.signup_date)::date AS cohort_month,
        DATE_TRUNC('month', e.event_date)::date AS activity_month,
-- Calculate the offset in months between signup and activity
        (
            (EXTRACT(YEAR FROM e.event_date) - EXTRACT(YEAR FROM u.signup_date)) * 12
            +
            (EXTRACT(MONTH FROM e.event_date) - EXTRACT(MONTH FROM u.signup_date))
        ) AS month_offset
FROM users_clean u
JOIN events_clean e
ON u.user_id = e.user_id
WHERE u.signup_date IS NOT NULL
      AND e.event_date IS NOT NULL
      AND e.event_type IS NOT NULL
      AND e.event_type != 'test_event'
)
-- Aggregate cohort analysis counting unique users per cohort and month offset
SELECT
    promo_signup_flag,
    cohort_month,
    month_offset,
    COUNT(DISTINCT user_id) AS users_total
FROM joined_data
WHERE activity_month BETWEEN DATE '2025-01-01' AND DATE '2025-06-01'
GROUP BY
    promo_signup_flag,
    cohort_month,
    month_offset
ORDER BY
    promo_signup_flag,
    cohort_month,
    month_offset;