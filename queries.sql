-- Deliverable 1 - KPI Summary
WITH kpi2025 AS (
  SELECT 
    COUNT(DISTINCT(order_id)) AS total_orders,
    COUNT(DiSTINCT(user_id)) AS unique_cust,
    SUM(sale_price) AS total_revenue, 
    SUM(sale_price) / COUNT(DISTINCT(order_id)) AS aov,
    (SELECT
      COUNT(DISTINCT(CASE WHEN status = 'Returned' THEN order_id END)) * 100
      /
      COUNT(DISTINCT(order_id))
    FROM bigquery-public-data.thelook_ecommerce.order_items
    WHERE created_at BETWEEN '2025-01-01' AND '2026-01-01') AS return_rate
  FROM bigquery-public-data.thelook_ecommerce.order_items
  WHERE status = 'Complete' AND created_at BETWEEN '2025-01-01' AND '2026-01-01'
), kpi2024 AS (
  SELECT 
    COUNT(DISTINCT(order_id)) AS total_orders,
    COUNT(DiSTINCT(user_id)) AS unique_cust,
    SUM(sale_price) AS total_revenue, 
    SUM(sale_price) / COUNT(DISTINCT(order_id)) AS aov,
    (SELECT
      COUNT(DISTINCT(CASE WHEN status = 'Returned' THEN order_id END)) * 100
      /
      COUNT(DISTINCT(order_id))
    FROM bigquery-public-data.thelook_ecommerce.order_items
    WHERE created_at BETWEEN '2024-01-01' AND '2025-01-01') AS return_rate
  FROM bigquery-public-data.thelook_ecommerce.order_items
  WHERE status = 'Complete' AND created_at BETWEEN '2024-01-01' AND '2025-01-01'
)

SELECT 2025 AS year, * FROM kpi2025
UNION ALL
SELECT 2024 AS year, * FROM kpi2024;

-- Deliverable 2 - Monthly Revenue Trend with MoM Growth (2025)
WITH cte AS (
  SELECT
    FORMAT_TIMESTAMP('%Y-%m', created_at) yr_mnth,
    SUM(sale_price) total_revenue
  FROM bigquery-public-data.thelook_ecommerce.order_items
  WHERE status = 'Complete' AND created_at BETWEEN '2025-01-01' AND '2025-12-31'
  GROUP BY 1
)

SELECT
  *,
  (total_revenue - LAG(total_revenue) OVER(ORDER BY yr_mnth)) *100
  /
  LAG(total_revenue) OVER(ORDER BY yr_mnth) AS growth
FROM cte;

-- Deliverable 3 - Top 5 Products by Revenue per Category
WITH revenue_per_product AS (
  SELECT
    FORMAT_TIMESTAMP('%Y-%m', created_at) yr_mnth,
    category,
    name,
    SUM(sale_price) total_revenue
  FROM bigquery-public-data.thelook_ecommerce.order_items oi
  JOIN bigquery-public-data.thelook_ecommerce.products p
  ON oi.product_id = p.id
  WHERE status = 'Complete' AND created_at BETWEEN '2025-01-01' AND '2026-01-01'
  GROUP BY 1,2,3
), ranks AS (
  SELECT 
    *,
    DENSE_RANK() OVER(PARTITION BY yr_mnth, category ORDER BY total_revenue DESC) rnk
  FROM revenue_per_product
)

SELECT
  category,
  name,
  SUM(total_revenue) cummulative_revenue,
  COUNT(*) top5freq
FROM ranks
WHERE rnk <= 5
GROUP BY 1,2
ORDER BY top5freq DESC;

-- Deliverable 4 - RFM Segmentation
WITH user_summary AS (
  SELECT
    user_id,
    MAX(created_at) recent_purchase,
    COUNT(DISTINCT(order_id)) order_cnt,
    SUM(sale_price) total_spending
  FROM bigquery-public-data.thelook_ecommerce.order_items
  GROUP BY 1
), binning AS (
  SELECT
    *,
    NTILE(5) OVER (ORDER BY recent_purchase ASC) recency,
    NTILE(5) OVER (ORDER BY order_cnt ASC) frequency,
    NTILE(5) OVER (ORDER BY total_spending ASC) monetary
  FROM user_summary
), segmentation AS (
  SELECT 
    user_id,
    recent_purchase,
    order_cnt,
    total_spending,
    CASE
      WHEN recency >= 4 AND frequency >= 4 AND monetary >= 4 THEN '1. Champions'
      WHEN frequency + monetary >= 8 THEN '2. Loyal'
      WHEN recency = 1 AND frequency = 1 THEN '5. Lost'
      WHEN recency <= 2 THEN '4. At Risk'
      ELSE '3. SOSO'
    END AS segment
  FROM binning
), segment_summary AS (
  SELECT
    segment,
    SUM(total_spending) sum_revenue,
    COUNT(user_id) user_cnt
  FROM segmentation
  GROUP BY 1
)
SELECT
  *,
  sum_revenue * 100 / SUM(sum_revenue) OVER () AS pct_revenue,
  user_cnt * 100 / SUM(user_cnt) OVER () AS pct_users
FROM segment_summary
ORDER BY segment;