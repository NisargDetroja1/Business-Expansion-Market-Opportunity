-- =====================================================================
-- 03_competitor_analysis.sql
-- Business question: how crowded is each market, and where is
-- competition strong enough to matter for an expansion decision?
-- =====================================================================
USE business_expansion_analysis;

-- Q1: Which cities have the highest competition? (avg competition score, Top 10)
SELECT mk.City, mk.Region,
       ROUND(AVG(c.Competition_Score), 1) AS avg_competition_score,
       COUNT(c.Competitor_ID)             AS number_of_competitors
FROM competitors c
INNER JOIN markets mk ON c.Market_ID = mk.Market_ID
GROUP BY mk.City, mk.Region
ORDER BY avg_competition_score DESC
LIMIT 10;

-- Q2: Which cities have low competition? (Bottom 10)
SELECT mk.City, mk.Region,
       ROUND(AVG(c.Competition_Score), 1) AS avg_competition_score,
       COUNT(c.Competitor_ID)             AS number_of_competitors
FROM competitors c
INNER JOIN markets mk ON c.Market_ID = mk.Market_ID
GROUP BY mk.City, mk.Region
ORDER BY avg_competition_score ASC
LIMIT 10;

-- Q3: Which markets have high demand but low competition? (best-of-both, LEFT JOIN
--     so a market with zero competitor rows would still appear)
SELECT mk.City, mk.Region, mk.Demand_Score,
       ROUND(AVG(c.Competition_Score), 1) AS avg_competition_score
FROM markets mk
LEFT JOIN competitors c ON mk.Market_ID = c.Market_ID
GROUP BY mk.City, mk.Region, mk.Demand_Score
HAVING mk.Demand_Score > 55
   AND (avg_competition_score < 45 OR avg_competition_score IS NULL)
ORDER BY mk.Demand_Score DESC, avg_competition_score ASC;

-- Q4: Competitor price positioning by market (how many Low / Medium / High players)
SELECT mk.City,
       SUM(CASE WHEN c.Price_Level = 'Low'    THEN 1 ELSE 0 END) AS low_price_competitors,
       SUM(CASE WHEN c.Price_Level = 'Medium' THEN 1 ELSE 0 END) AS medium_price_competitors,
       SUM(CASE WHEN c.Price_Level = 'High'   THEN 1 ELSE 0 END) AS high_price_competitors
FROM competitors c
INNER JOIN markets mk ON c.Market_ID = mk.Market_ID
GROUP BY mk.City
ORDER BY mk.City;

-- Q5: Strongest single competitor (by brand strength) in every market
SELECT mk.City, c.Competitor_Name, c.Market_Share, c.Brand_Strength
FROM competitors c
INNER JOIN markets mk ON c.Market_ID = mk.Market_ID
WHERE c.Brand_Strength = (
    SELECT MAX(c2.Brand_Strength)
    FROM competitors c2
    WHERE c2.Market_ID = c.Market_ID
)
ORDER BY c.Brand_Strength DESC;

-- Q6: Market concentration — top competitor's share of the market (fragmentation signal)
SELECT mk.City,
       ROUND(MAX(c.Market_Share), 1) AS top_competitor_share,
       COUNT(c.Competitor_ID)        AS total_competitors,
       CASE
           WHEN MAX(c.Market_Share) >= 40 THEN 'Concentrated'
           WHEN MAX(c.Market_Share) >= 25 THEN 'Moderately Concentrated'
           ELSE 'Fragmented'
       END AS market_structure
FROM competitors c
INNER JOIN markets mk ON c.Market_ID = mk.Market_ID
GROUP BY mk.City
ORDER BY top_competitor_share DESC;

-- Q7: Region-level competitive intensity
SELECT mk.Region,
       ROUND(AVG(c.Competition_Score), 1) AS avg_competition_score,
       COUNT(DISTINCT mk.Market_ID)        AS markets_in_region
FROM competitors c
INNER JOIN markets mk ON c.Market_ID = mk.Market_ID
GROUP BY mk.Region
ORDER BY avg_competition_score DESC;
