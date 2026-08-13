-- =====================================================================
-- 01_market_analysis.sql
-- Business question: how big and how attractive is each market on its
-- own fundamentals (population, income, demand, growth) before we layer
-- in sales, competition, or cost?
-- =====================================================================
USE business_expansion_analysis;

-- Q1: Full market master list ordered by population (market sizing)
SELECT Market_ID, City, State, Region, Market_Tier, Population,
       Estimated_Target_Customers, Average_Income
FROM markets
ORDER BY Population DESC;

-- Q2: Which cities have the highest customer demand? (Top 10)
SELECT City, Region, Market_Tier, Demand_Score
FROM markets
ORDER BY Demand_Score DESC
LIMIT 10;

-- Q3: Average demand score and growth rate by region
SELECT Region,
       ROUND(AVG(Demand_Score), 1)        AS avg_demand_score,
       ROUND(AVG(Market_Growth_Rate), 1)  AS avg_growth_rate,
       COUNT(*)                            AS markets_in_region
FROM markets
GROUP BY Region
ORDER BY avg_demand_score DESC;

-- Q4: Tier-1 vs Tier-2 comparison — do smaller markets grow faster?
SELECT Market_Tier,
       COUNT(*)                            AS market_count,
       ROUND(AVG(Market_Growth_Rate), 1)   AS avg_growth_rate,
       ROUND(AVG(Demand_Score), 1)         AS avg_demand_score,
       ROUND(AVG(Average_Income), 0)       AS avg_income
FROM markets
GROUP BY Market_Tier;

-- Q5: Which Tier-2 markets show strong growth (above the Tier-2 average)?
SELECT City, Region, Market_Growth_Rate, Demand_Score
FROM markets
WHERE Market_Tier = 'Tier 2'
  AND Market_Growth_Rate > (
        SELECT AVG(Market_Growth_Rate) FROM markets WHERE Market_Tier = 'Tier 2'
      )
ORDER BY Market_Growth_Rate DESC;

-- Q6: Rank every market by demand score within its own region (window function)
SELECT City, Region, Demand_Score,
       RANK() OVER (PARTITION BY Region ORDER BY Demand_Score DESC) AS demand_rank_in_region
FROM markets
ORDER BY Region, demand_rank_in_region;

-- Q7: Digital adoption vs infrastructure — markets that are digitally ready
--     but infrastructure-constrained (a quick expansion-risk flag)
SELECT City, Region, Digital_Adoption_Score, Infrastructure_Score,
       ROUND(Digital_Adoption_Score - Infrastructure_Score, 1) AS digital_infra_gap
FROM markets
HAVING digital_infra_gap > 10
ORDER BY digital_infra_gap DESC;

-- Q8: Classify markets by income band using CASE
SELECT City, Region, Average_Income,
       CASE
           WHEN Average_Income >= 55000 THEN 'High Income'
           WHEN Average_Income >= 42000 THEN 'Mid Income'
           ELSE 'Emerging Income'
       END AS income_band
FROM markets
ORDER BY Average_Income DESC;
