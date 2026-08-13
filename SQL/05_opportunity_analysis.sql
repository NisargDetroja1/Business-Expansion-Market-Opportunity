-- =====================================================================
-- 05_opportunity_analysis.sql
-- Business question: combining demand, growth, revenue potential,
-- competition, and cost — which markets should we prioritize?
-- This mirrors the Market Opportunity Score used in Power BI / Excel.
-- =====================================================================
USE business_expansion_analysis;

-- Q1: Build the underlying components per market (CTE)
WITH market_costs AS (
    SELECT Market_ID, Estimated_Annual_Cost FROM operating_costs
),
market_competition AS (
    SELECT Market_ID, ROUND(AVG(Competition_Score), 1) AS avg_competition_score
    FROM competitors
    GROUP BY Market_ID
),
market_revenue AS (
    SELECT Market_ID, SUM(Revenue) / 3 AS avg_annual_revenue
    FROM sales
    GROUP BY Market_ID
),
scored AS (
    SELECT
        mk.Market_ID, mk.City, mk.Region, mk.Market_Tier,
        mk.Demand_Score,
        mk.Market_Growth_Rate,
        mr.avg_annual_revenue,
        mco.avg_competition_score,
        mc.Estimated_Annual_Cost,
        -- normalize growth to a 0-100 scale (cap at 25% growth = 100)
        ROUND(LEAST(mk.Market_Growth_Rate / 25 * 100, 100), 1) AS growth_score,
        -- normalize revenue potential to a 0-100 scale within this dataset
        ROUND(mr.avg_annual_revenue
              / (SELECT MAX(rev) FROM (SELECT SUM(Revenue)/3 AS rev FROM sales GROUP BY Market_ID) AS max_rev_lookup) * 100, 1)
              AS revenue_score,
        -- low competition = more attractive
        ROUND(100 - mco.avg_competition_score, 1) AS low_competition_score,
        -- low cost = more attractive, normalized against the most expensive market
        ROUND(100 - (mc.Estimated_Annual_Cost
              / (SELECT MAX(Estimated_Annual_Cost) FROM operating_costs) * 100), 1)
              AS low_cost_score
    FROM markets mk
    INNER JOIN market_costs mc ON mk.Market_ID = mc.Market_ID
    INNER JOIN market_competition mco ON mk.Market_ID = mco.Market_ID
    INNER JOIN market_revenue mr ON mk.Market_ID = mr.Market_ID
)
SELECT
    Market_ID, City, Region, Market_Tier,
    Demand_Score, growth_score, revenue_score, low_competition_score, low_cost_score,
    ROUND(
        Demand_Score            * 0.30 +
        growth_score            * 0.20 +
        revenue_score           * 0.25 +
        low_competition_score   * 0.15 +
        low_cost_score          * 0.10
    , 1) AS market_opportunity_score
FROM scored
ORDER BY market_opportunity_score DESC;

-- Q2: Top 10 expansion opportunities (reuses the scoring logic, ranked)
WITH market_costs AS (
    SELECT Market_ID, Estimated_Annual_Cost FROM operating_costs
),
market_competition AS (
    SELECT Market_ID, ROUND(AVG(Competition_Score), 1) AS avg_competition_score
    FROM competitors GROUP BY Market_ID
),
market_revenue AS (
    SELECT Market_ID, SUM(Revenue) / 3 AS avg_annual_revenue
    FROM sales GROUP BY Market_ID
),
scored AS (
    SELECT
        mk.City, mk.Region, mk.Market_Tier, mk.Demand_Score,
        ROUND(LEAST(mk.Market_Growth_Rate / 25 * 100, 100), 1) AS growth_score,
        ROUND(mr.avg_annual_revenue
              / (SELECT MAX(rev) FROM (SELECT SUM(Revenue)/3 AS rev FROM sales GROUP BY Market_ID) AS max_rev_lookup) * 100, 1)
              AS revenue_score,
        ROUND(100 - mco.avg_competition_score, 1) AS low_competition_score,
        ROUND(100 - (mc.Estimated_Annual_Cost
              / (SELECT MAX(Estimated_Annual_Cost) FROM operating_costs) * 100), 1)
              AS low_cost_score
    FROM markets mk
    INNER JOIN market_costs mc ON mk.Market_ID = mc.Market_ID
    INNER JOIN market_competition mco ON mk.Market_ID = mco.Market_ID
    INNER JOIN market_revenue mr ON mk.Market_ID = mr.Market_ID
)
SELECT City, Region, Market_Tier,
       ROUND(Demand_Score*0.30 + growth_score*0.20 + revenue_score*0.25
             + low_competition_score*0.15 + low_cost_score*0.10, 1) AS opportunity_score,
       RANK() OVER (ORDER BY
           (Demand_Score*0.30 + growth_score*0.20 + revenue_score*0.25
            + low_competition_score*0.15 + low_cost_score*0.10) DESC) AS opportunity_rank
FROM scored
ORDER BY opportunity_rank
LIMIT 10;

-- Q3: Which cities combine strong growth AND strong demand? (both above median)
SELECT City, Region, Market_Growth_Rate, Demand_Score
FROM markets
WHERE Market_Growth_Rate > (SELECT AVG(Market_Growth_Rate) FROM markets)
  AND Demand_Score > (SELECT AVG(Demand_Score) FROM markets)
ORDER BY Market_Growth_Rate DESC, Demand_Score DESC;

-- Q4: Which cities have high revenue potential but excessive costs?
--     (top-third revenue, bottom-third cost-attractiveness)
WITH market_revenue AS (
    SELECT Market_ID, SUM(Revenue) / 3 AS avg_annual_revenue
    FROM sales GROUP BY Market_ID
)
SELECT mk.City, mr.avg_annual_revenue, oc.Estimated_Annual_Cost
FROM market_revenue mr
INNER JOIN markets mk ON mr.Market_ID = mk.Market_ID
INNER JOIN operating_costs oc ON mk.Market_ID = oc.Market_ID
WHERE mr.avg_annual_revenue > (SELECT AVG(avg_annual_revenue) FROM market_revenue)
  AND oc.Estimated_Annual_Cost > (SELECT AVG(Estimated_Annual_Cost) FROM operating_costs)
ORDER BY mr.avg_annual_revenue DESC;

-- Q5: Which regions contain the most attractive expansion markets?
--     (count of markets with Demand_Score > 60 AND Market_Growth_Rate > 10)
SELECT Region, COUNT(*) AS attractive_market_count
FROM markets
WHERE Demand_Score > 60 AND Market_Growth_Rate > 10
GROUP BY Region
ORDER BY attractive_market_count DESC;
