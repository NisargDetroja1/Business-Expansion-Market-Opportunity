-- =====================================================================
-- 00_schema_and_import.sql
-- Business Expansion & Market Opportunity Dashboard
-- Creates the database, all tables, keys, and provides import + cleaning steps
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. DATABASE
-- ---------------------------------------------------------------------
DROP DATABASE IF EXISTS business_expansion_analysis;
CREATE DATABASE business_expansion_analysis;
USE business_expansion_analysis;

-- ---------------------------------------------------------------------
-- 2. TABLES
-- ---------------------------------------------------------------------

-- Market master table (one row per city/market)
CREATE TABLE markets (
    Market_ID                    VARCHAR(10)     PRIMARY KEY,
    City                         VARCHAR(60)     NOT NULL,
    State                        VARCHAR(60)     NOT NULL,
    Region                       VARCHAR(20)     NOT NULL,
    Market_Tier                  VARCHAR(10)     NOT NULL,
    Population                   BIGINT          NOT NULL,
    Estimated_Target_Customers   INT             NOT NULL,
    Average_Income               INT             NULL,
    Market_Growth_Rate           DECIMAL(5,2)    NOT NULL,
    Demand_Score                 DECIMAL(5,2)    NOT NULL,
    Digital_Adoption_Score       DECIMAL(5,2)    NOT NULL,
    Infrastructure_Score         DECIMAL(5,2)    NOT NULL
);

-- Historical sales performance (monthly grain, per market per product category)
CREATE TABLE sales (
    Sale_ID           VARCHAR(10)     PRIMARY KEY,
    Sale_Date         DATE            NOT NULL,
    Market_ID         VARCHAR(10)     NOT NULL,
    Product_Category  VARCHAR(40)     NOT NULL,
    Orders            INT             NOT NULL,
    Customers         INT             NOT NULL,
    Revenue            DECIMAL(14,2)  NOT NULL,
    Cost               DECIMAL(14,2)  NOT NULL,
    Profit             DECIMAL(14,2)  NOT NULL,
    Discount            DECIMAL(12,2) NULL,
    CONSTRAINT fk_sales_market FOREIGN KEY (Market_ID) REFERENCES markets(Market_ID)
);

-- Competitor presence per market
CREATE TABLE competitors (
    Competitor_ID       VARCHAR(10)    PRIMARY KEY,
    Market_ID            VARCHAR(10)   NOT NULL,
    Competitor_Name       VARCHAR(100) NOT NULL,
    Market_Share          DECIMAL(5,2) NOT NULL,
    Number_of_Locations   INT          NOT NULL,
    Price_Level            VARCHAR(10) NOT NULL,
    Brand_Strength          DECIMAL(5,2) NOT NULL,
    Competition_Score        DECIMAL(5,2) NOT NULL,
    CONSTRAINT fk_competitors_market FOREIGN KEY (Market_ID) REFERENCES markets(Market_ID)
);

-- Estimated operating / expansion costs per market
CREATE TABLE operating_costs (
    Cost_ID                  VARCHAR(10)  PRIMARY KEY,
    Market_ID                VARCHAR(10)  NOT NULL,
    Office_Rent              INT          NOT NULL,
    Employee_Cost            INT          NOT NULL,
    Marketing_Cost           INT          NULL,
    Logistics_Cost           INT          NOT NULL,
    Setup_Cost               INT          NOT NULL,
    Estimated_Annual_Cost    BIGINT       NOT NULL,
    CONSTRAINT fk_costs_market FOREIGN KEY (Market_ID) REFERENCES markets(Market_ID)
);

-- Customer demand broken down by segment, per market
CREATE TABLE customer_demand (
    Demand_ID               VARCHAR(10)  PRIMARY KEY,
    Market_ID                VARCHAR(10) NOT NULL,
    Customer_Segment          VARCHAR(30) NOT NULL,
    Potential_Customers        INT        NOT NULL,
    Existing_Customers         INT        NOT NULL,
    Purchase_Potential          INT       NOT NULL,
    Demand_Score                 DECIMAL(5,2) NOT NULL,
    Customer_Growth_Rate           DECIMAL(5,2) NOT NULL,
    CONSTRAINT fk_demand_market FOREIGN KEY (Market_ID) REFERENCES markets(Market_ID)
);

-- ---------------------------------------------------------------------
-- 3. IMPORT INSTRUCTIONS
-- ---------------------------------------------------------------------
-- Option A: MySQL Workbench "Table Data Import Wizard" — point it at each
--           CSV in /Dataset and map columns to the tables above.
--
-- Option B: LOAD DATA (run from the mysql client on the machine that
--           hosts the files; adjust the path and enable local_infile):
--
-- SET GLOBAL local_infile = 1;
--
-- LOAD DATA LOCAL INFILE 'Dataset/markets.csv'
-- INTO TABLE markets
-- FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\r\n'
-- IGNORE 1 ROWS
-- (Market_ID, City, State, Region, Market_Tier, Population,
--  Estimated_Target_Customers, @Average_Income, Market_Growth_Rate,
--  Demand_Score, Digital_Adoption_Score, Infrastructure_Score)
-- SET Average_Income = NULLIF(@Average_Income, '');
--
-- LOAD DATA LOCAL INFILE 'Dataset/sales.csv'
-- INTO TABLE sales
-- FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\r\n'
-- IGNORE 1 ROWS
-- (Sale_ID, Sale_Date, Market_ID, Product_Category, Orders, Customers,
--  Revenue, Cost, Profit, @Discount)
-- SET Discount = NULLIF(@Discount, '');
--
-- LOAD DATA LOCAL INFILE 'Dataset/competitors.csv'
-- INTO TABLE competitors
-- FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\r\n'
-- IGNORE 1 ROWS;
--
-- LOAD DATA LOCAL INFILE 'Dataset/operating_costs.csv'
-- INTO TABLE operating_costs
-- FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\r\n'
-- IGNORE 1 ROWS
-- (Cost_ID, Market_ID, Office_Rent, Employee_Cost, @Marketing_Cost,
--  Logistics_Cost, Setup_Cost, Estimated_Annual_Cost)
-- SET Marketing_Cost = NULLIF(@Marketing_Cost, '');
--
-- LOAD DATA LOCAL INFILE 'Dataset/customer_demand.csv'
-- INTO TABLE customer_demand
-- FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\r\n'
-- IGNORE 1 ROWS;

-- ---------------------------------------------------------------------
-- 4. DATA QUALITY CHECKS
-- ---------------------------------------------------------------------

-- 4.1 Duplicate market rows (same Market_ID appears more than once)
SELECT Market_ID, COUNT(*) AS row_count
FROM markets
GROUP BY Market_ID
HAVING COUNT(*) > 1;

-- 4.2 Duplicate sales rows (identical business record repeated)
SELECT Market_ID, Sale_Date, Product_Category, Orders, Revenue, COUNT(*) AS row_count
FROM sales
GROUP BY Market_ID, Sale_Date, Product_Category, Orders, Revenue
HAVING COUNT(*) > 1;

-- 4.3 Missing values
SELECT COUNT(*) AS missing_income FROM markets WHERE Average_Income IS NULL;
SELECT COUNT(*) AS missing_discount FROM sales WHERE Discount IS NULL;
SELECT COUNT(*) AS missing_marketing_cost FROM operating_costs WHERE Marketing_Cost IS NULL;

-- 4.4 Inconsistent text formatting (extra spaces / mixed case)
SELECT DISTINCT City
FROM markets
WHERE City <> TRIM(City)
   OR City <> CONCAT(UPPER(LEFT(TRIM(City),1)), LOWER(SUBSTRING(TRIM(City),2)));

-- ---------------------------------------------------------------------
-- 5. BASIC CLEANING QUERIES
-- ---------------------------------------------------------------------

-- 5.1 Remove exact duplicate market rows, keeping one row per Market_ID.
--     Run this BEFORE loading sales/competitors/costs/demand, since those
--     tables have foreign keys pointing at markets.Market_ID.
--     Uses ROW_NUMBER() to flag the 2nd+ occurrence of each Market_ID, then
--     deletes only the flagged rows.
DELETE FROM markets
WHERE (Market_ID, City) IN (
    SELECT Market_ID, City FROM (
        SELECT Market_ID, City,
               ROW_NUMBER() OVER (PARTITION BY Market_ID ORDER BY City) AS rn
        FROM markets
    ) ranked
    WHERE rn > 1
);
-- NOTE: this DELETE ... IN (SELECT ... same table) pattern works in MySQL 8+
-- because the inner derived table is materialized before the DELETE runs.

-- 5.2 Trim whitespace and standardise capitalization on City/State
UPDATE markets
SET City  = TRIM(City),
    State = TRIM(State);

UPDATE markets
SET City = CONCAT(UPPER(LEFT(City,1)), LOWER(SUBSTRING(City,2)))
WHERE City <> CONCAT(UPPER(LEFT(City,1)), LOWER(SUBSTRING(City,2)));

-- 5.3 Standardise Price_Level and Product_Category casing
UPDATE competitors
SET Price_Level = CONCAT(UPPER(LEFT(Price_Level,1)), LOWER(SUBSTRING(Price_Level,2)));

UPDATE sales
SET Product_Category = CONCAT(UPPER(LEFT(Product_Category,1)), LOWER(SUBSTRING(Product_Category,2)));

-- 5.4 Trim Customer_Segment values
UPDATE customer_demand
SET Customer_Segment = TRIM(Customer_Segment);

-- 5.5 Handle missing Average_Income by imputing the regional average
UPDATE markets m
JOIN (
    SELECT Region, AVG(Average_Income) AS region_avg_income
    FROM markets
    WHERE Average_Income IS NOT NULL
    GROUP BY Region
) r ON m.Region = r.Region
SET m.Average_Income = ROUND(r.region_avg_income)
WHERE m.Average_Income IS NULL;

-- 5.6 Handle missing Discount by defaulting to 0 (no discount applied)
UPDATE sales
SET Discount = 0
WHERE Discount IS NULL;

-- 5.7 Handle missing Marketing_Cost by imputing from Estimated_Target_Customers ratio
UPDATE operating_costs oc
JOIN markets m ON oc.Market_ID = m.Market_ID
SET oc.Marketing_Cost = ROUND(m.Estimated_Target_Customers * 5)
WHERE oc.Marketing_Cost IS NULL;

-- Re-check row counts after cleaning
SELECT
    (SELECT COUNT(*) FROM markets)          AS market_rows,
    (SELECT COUNT(*) FROM sales)            AS sales_rows,
    (SELECT COUNT(*) FROM competitors)      AS competitor_rows,
    (SELECT COUNT(*) FROM operating_costs)  AS cost_rows,
    (SELECT COUNT(*) FROM customer_demand)  AS demand_rows;
