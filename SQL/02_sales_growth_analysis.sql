-- =====================================================================
-- 02_sales_growth_analysis.sql
-- Business question: which markets are already performing well, and how
-- has their performance trended over 2023-2025?
-- =====================================================================
USE business_expansion_analysis;

-- Q1: Which cities generate the highest revenue? (Top 10, all-time)
SELECT mk.City, mk.Region,
       ROUND(SUM(s.Revenue), 0) AS total_revenue
FROM sales s
INNER JOIN markets mk ON s.Market_ID = mk.Market_ID
GROUP BY mk.City, mk.Region
ORDER BY total_revenue DESC
LIMIT 10;

-- Q2: Which cities generate the highest profit? (Top 10, all-time)
SELECT mk.City, mk.Region,
       ROUND(SUM(s.Profit), 0)  AS total_profit,
       ROUND(SUM(s.Profit) / SUM(s.Revenue) * 100, 1) AS profit_margin_pct
FROM sales s
INNER JOIN markets mk ON s.Market_ID = mk.Market_ID
GROUP BY mk.City, mk.Region
ORDER BY total_profit DESC
LIMIT 10;

-- Q3: Annual revenue by city, using YEAR() to break out 2023 / 2024 / 2025
SELECT mk.City, YEAR(s.Sale_Date) AS sale_year,
       ROUND(SUM(s.Revenue), 0) AS revenue
FROM sales s
INNER JOIN markets mk ON s.Market_ID = mk.Market_ID
GROUP BY mk.City, YEAR(s.Sale_Date)
ORDER BY mk.City, sale_year;

-- Q4: Year-over-year revenue growth per city (CTE + LAG window function)
WITH yearly_revenue AS (
    SELECT mk.City,
           YEAR(s.Sale_Date) AS sale_year,
           SUM(s.Revenue)    AS revenue
    FROM sales s
    INNER JOIN markets mk ON s.Market_ID = mk.Market_ID
    GROUP BY mk.City, YEAR(s.Sale_Date)
)
SELECT City, sale_year, revenue,
       LAG(revenue) OVER (PARTITION BY City ORDER BY sale_year) AS prior_year_revenue,
       ROUND(
         (revenue - LAG(revenue) OVER (PARTITION BY City ORDER BY sale_year))
         / LAG(revenue) OVER (PARTITION BY City ORDER BY sale_year) * 100, 1
       ) AS yoy_growth_pct
FROM yearly_revenue
ORDER BY City, sale_year;

-- Q5: Which markets show declining performance? (negative YoY growth in the latest year)
WITH yearly_revenue AS (
    SELECT mk.City,
           YEAR(s.Sale_Date) AS sale_year,
           SUM(s.Revenue)    AS revenue
    FROM sales s
    INNER JOIN markets mk ON s.Market_ID = mk.Market_ID
    GROUP BY mk.City, YEAR(s.Sale_Date)
),
yoy AS (
    SELECT City, sale_year, revenue,
           LAG(revenue) OVER (PARTITION BY City ORDER BY sale_year) AS prior_year_revenue
    FROM yearly_revenue
)
SELECT City, sale_year,
       ROUND((revenue - prior_year_revenue) / prior_year_revenue * 100, 1) AS yoy_growth_pct
FROM yoy
WHERE prior_year_revenue IS NOT NULL
  AND sale_year = 2025
  AND revenue < prior_year_revenue
ORDER BY yoy_growth_pct ASC;

-- Q6: Revenue-to-cost ratio per city (efficiency of revenue generation)
SELECT mk.City,
       ROUND(SUM(s.Revenue), 0) AS total_revenue,
       ROUND(SUM(s.Cost), 0)    AS total_cost,
       ROUND(SUM(s.Revenue) / NULLIF(SUM(s.Cost), 0), 2) AS revenue_to_cost_ratio
FROM sales s
INNER JOIN markets mk ON s.Market_ID = mk.Market_ID
GROUP BY mk.City
ORDER BY revenue_to_cost_ratio DESC
LIMIT 10;

-- Q7: Best-performing product category overall (aggregate + HAVING filter)
SELECT Product_Category,
       ROUND(SUM(Revenue), 0) AS total_revenue,
       ROUND(SUM(Profit), 0)  AS total_profit,
       COUNT(*)                AS records
FROM sales
GROUP BY Product_Category
HAVING SUM(Revenue) > 0
ORDER BY total_revenue DESC;

-- Q8: Dense-rank cities nationally by total profit (DENSE_RANK)
SELECT mk.City,
       ROUND(SUM(s.Profit), 0) AS total_profit,
       DENSE_RANK() OVER (ORDER BY SUM(s.Profit) DESC) AS profit_rank
FROM sales s
INNER JOIN markets mk ON s.Market_ID = mk.Market_ID
GROUP BY mk.City
ORDER BY profit_rank;
