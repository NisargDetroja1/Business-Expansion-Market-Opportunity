-- =====================================================================
-- 04_cost_analysis.sql
-- Business question: what would it cost to operate in each market, and
-- how does that cost stack up against the revenue it could generate?
-- =====================================================================
USE business_expansion_analysis;

-- Q1: Which markets have the highest operating costs? (Top 10)
SELECT mk.City, mk.Region, oc.Estimated_Annual_Cost
FROM operating_costs oc
INNER JOIN markets mk ON oc.Market_ID = mk.Market_ID
ORDER BY oc.Estimated_Annual_Cost DESC
LIMIT 10;

-- Q2: Which markets have the lowest operating costs? (Top 10, cheapest to enter)
SELECT mk.City, mk.Region, oc.Estimated_Annual_Cost
FROM operating_costs oc
INNER JOIN markets mk ON oc.Market_ID = mk.Market_ID
ORDER BY oc.Estimated_Annual_Cost ASC
LIMIT 10;

-- Q3: Cost breakdown as % of total estimated annual cost, per market
SELECT mk.City,
       ROUND(oc.Office_Rent * 12 / oc.Estimated_Annual_Cost * 100, 1)  AS rent_pct,
       ROUND(oc.Employee_Cost / oc.Estimated_Annual_Cost * 100, 1)     AS employee_pct,
       ROUND(oc.Marketing_Cost / oc.Estimated_Annual_Cost * 100, 1)    AS marketing_pct,
       ROUND(oc.Logistics_Cost / oc.Estimated_Annual_Cost * 100, 1)    AS logistics_pct,
       ROUND(oc.Setup_Cost / oc.Estimated_Annual_Cost * 100, 1)        AS setup_pct
FROM operating_costs oc
INNER JOIN markets mk ON oc.Market_ID = mk.Market_ID
ORDER BY mk.City;

-- Q4: Cost per estimated target customer (efficiency of spend)
SELECT mk.City,
       oc.Estimated_Annual_Cost,
       mk.Estimated_Target_Customers,
       ROUND(oc.Estimated_Annual_Cost / NULLIF(mk.Estimated_Target_Customers, 0), 2)
           AS cost_per_target_customer
FROM operating_costs oc
INNER JOIN markets mk ON oc.Market_ID = mk.Market_ID
ORDER BY cost_per_target_customer ASC
LIMIT 10;

-- Q5: Revenue vs. cost — actual historical revenue against estimated annual
--     operating cost, to spot markets already outperforming their cost base
WITH total_sales AS (
    SELECT Market_ID, SUM(Revenue) / 3 AS avg_annual_revenue   -- 3 years of history
    FROM sales
    GROUP BY Market_ID
)
SELECT mk.City,
       ROUND(ts.avg_annual_revenue, 0) AS avg_annual_revenue,
       oc.Estimated_Annual_Cost,
       ROUND(ts.avg_annual_revenue / oc.Estimated_Annual_Cost, 2) AS revenue_to_cost_ratio
FROM total_sales ts
INNER JOIN markets mk ON ts.Market_ID = mk.Market_ID
INNER JOIN operating_costs oc ON mk.Market_ID = oc.Market_ID
ORDER BY revenue_to_cost_ratio DESC;

-- Q6: Cost attractiveness tier using CASE (lower cost = more attractive)
SELECT mk.City, oc.Estimated_Annual_Cost,
       CASE
           WHEN oc.Estimated_Annual_Cost < 2500000 THEN 'Low Cost'
           WHEN oc.Estimated_Annual_Cost < 4500000 THEN 'Moderate Cost'
           ELSE 'High Cost'
       END AS cost_tier
FROM operating_costs oc
INNER JOIN markets mk ON oc.Market_ID = mk.Market_ID
ORDER BY oc.Estimated_Annual_Cost;

-- Q7: Average operating cost by region and tier
SELECT mk.Region, mk.Market_Tier,
       ROUND(AVG(oc.Estimated_Annual_Cost), 0) AS avg_annual_cost
FROM operating_costs oc
INNER JOIN markets mk ON oc.Market_ID = mk.Market_ID
GROUP BY mk.Region, mk.Market_Tier
ORDER BY avg_annual_cost DESC;
