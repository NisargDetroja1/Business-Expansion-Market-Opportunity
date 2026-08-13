-- =====================================================================
-- 06_business_insights.sql
-- Business question: pull together demand, competition, cost, and risk
-- into a single decision-support view with a recommendation per market.
-- =====================================================================
USE business_expansion_analysis;

-- Q1: Full decision-support table — Opportunity Score + Risk Score + Recommendation
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
        mk.Market_ID, mk.City, mk.Region, mk.Market_Tier,
        mk.Demand_Score, mk.Market_Growth_Rate,
        mco.avg_competition_score,
        mc.Estimated_Annual_Cost,
        mr.avg_annual_revenue,
        ROUND(LEAST(mk.Market_Growth_Rate / 25 * 100, 100), 1) AS growth_score,
        ROUND(mr.avg_annual_revenue
              / (SELECT MAX(rev) FROM (SELECT SUM(Revenue)/3 AS rev FROM sales GROUP BY Market_ID) t)
              * 100, 1) AS revenue_score,
        ROUND(100 - mco.avg_competition_score, 1) AS low_competition_score,
        ROUND(100 - (mc.Estimated_Annual_Cost
              / (SELECT MAX(Estimated_Annual_Cost) FROM operating_costs) * 100), 1)
              AS low_cost_score
    FROM markets mk
    INNER JOIN market_costs mc ON mk.Market_ID = mc.Market_ID
    INNER JOIN market_competition mco ON mk.Market_ID = mco.Market_ID
    INNER JOIN market_revenue mr ON mk.Market_ID = mr.Market_ID
),
final AS (
    SELECT *,
        ROUND(Demand_Score*0.30 + growth_score*0.20 + revenue_score*0.25
              + low_competition_score*0.15 + low_cost_score*0.10, 1) AS opportunity_score,
        -- Risk score: higher competition, higher cost, lower demand/growth = higher risk
        ROUND(
            avg_competition_score * 0.35 +
            (100 - low_cost_score) * 0.25 +
            (100 - Demand_Score) * 0.25 +
            (100 - growth_score) * 0.15
        , 1) AS risk_score
    FROM scored
)
-- NOTE: thresholds below are calibrated to this dataset's actual score
-- distribution (opportunity scores roughly 27-68, risk scores roughly 38-64)
-- so that the classification bands are meaningful rather than empty.
SELECT
    City, Region, Market_Tier, opportunity_score, risk_score,
    CASE
        WHEN opportunity_score >= 65 THEN 'High Potential'
        WHEN opportunity_score >= 55 THEN 'Attractive'
        WHEN opportunity_score >= 45 THEN 'Consider'
        ELSE 'Low Priority'
    END AS opportunity_class,
    CASE
        WHEN risk_score >= 56 THEN 'High Risk'
        WHEN risk_score >= 46 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS risk_class,
    CASE
        WHEN opportunity_score >= 60 AND risk_score < 48 THEN 'Recommended'
        WHEN opportunity_score >= 60 THEN 'Consider'
        WHEN opportunity_score >= 48 THEN 'Review'
        ELSE 'Avoid'
    END AS recommendation
FROM final
ORDER BY opportunity_score DESC;

-- Q2: Top 10 expansion opportunities with full narrative fields (final answer to the brief)
WITH market_costs AS (SELECT Market_ID, Estimated_Annual_Cost FROM operating_costs),
market_competition AS (
    SELECT Market_ID, ROUND(AVG(Competition_Score),1) AS avg_competition_score
    FROM competitors GROUP BY Market_ID
),
market_revenue AS (SELECT Market_ID, SUM(Revenue)/3 AS avg_annual_revenue FROM sales GROUP BY Market_ID),
scored AS (
    SELECT mk.City, mk.Region, mk.Market_Tier, mk.Demand_Score,
        ROUND(LEAST(mk.Market_Growth_Rate/25*100,100),1) AS growth_score,
        ROUND(mr.avg_annual_revenue
              / (SELECT MAX(rev) FROM (SELECT SUM(Revenue)/3 AS rev FROM sales GROUP BY Market_ID) t)
              * 100, 1) AS revenue_score,
        ROUND(100 - mco.avg_competition_score, 1) AS low_competition_score,
        ROUND(100 - (mc.Estimated_Annual_Cost
              / (SELECT MAX(Estimated_Annual_Cost) FROM operating_costs) * 100), 1) AS low_cost_score
    FROM markets mk
    INNER JOIN market_costs mc ON mk.Market_ID = mc.Market_ID
    INNER JOIN market_competition mco ON mk.Market_ID = mco.Market_ID
    INNER JOIN market_revenue mr ON mk.Market_ID = mr.Market_ID
)
SELECT City, Region, Market_Tier,
       ROUND(Demand_Score*0.30 + growth_score*0.20 + revenue_score*0.25
             + low_competition_score*0.15 + low_cost_score*0.10, 1) AS opportunity_score
FROM scored
ORDER BY opportunity_score DESC
LIMIT 10;

-- Q3: Which customer segments have the highest purchase potential nationally?
SELECT Customer_Segment,
       ROUND(AVG(Purchase_Potential), 0) AS avg_purchase_potential,
       ROUND(AVG(Demand_Score), 1)       AS avg_demand_score,
       SUM(Potential_Customers)          AS total_potential_customers
FROM customer_demand
GROUP BY Customer_Segment
ORDER BY avg_purchase_potential DESC;

-- Q4: Tier-2 cities with high demand and comparatively low competition
--     (the classic "hidden gem" expansion insight)
SELECT mk.City, mk.Region, mk.Demand_Score,
       ROUND(AVG(c.Competition_Score), 1) AS avg_competition_score
FROM markets mk
INNER JOIN competitors c ON mk.Market_ID = c.Market_ID
WHERE mk.Market_Tier = 'Tier 2'
GROUP BY mk.City, mk.Region, mk.Demand_Score
HAVING mk.Demand_Score > 50 AND avg_competition_score < 50
ORDER BY mk.Demand_Score DESC;

-- Q5: Markets where competition most significantly reduces attractiveness
--     (high demand, but competition score pulls the opportunity score down)
WITH market_competition AS (
    SELECT Market_ID, ROUND(AVG(Competition_Score), 1) AS avg_competition_score
    FROM competitors GROUP BY Market_ID
)
SELECT mk.City, mk.Demand_Score, mco.avg_competition_score,
       ROUND(mk.Demand_Score - mco.avg_competition_score, 1) AS demand_minus_competition_gap
FROM markets mk
INNER JOIN market_competition mco ON mk.Market_ID = mco.Market_ID
WHERE mk.Demand_Score > 55 AND mco.avg_competition_score > 60
ORDER BY mco.avg_competition_score DESC;
