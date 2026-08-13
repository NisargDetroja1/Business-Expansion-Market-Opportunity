# Business Expansion & Market Opportunity Dashboard

A decision-support analytics project that answers one question for management:
**based on demand, growth, competition, cost, revenue potential, and risk, where
should our company expand next?**

Built end-to-end with **SQL (MySQL) · Microsoft Excel · Power BI · DAX** on five
related, logically-constructed datasets covering 46 Indian cities, Jan 2023 – Dec 2025.

---

## Business Problem

A growing company operates in several Indian markets and wants to expand further,
but has limited capital and no consolidated way to compare candidate cities on
demand, growth, revenue potential, competition, operating cost, and risk. This
project builds that consolidated view and turns it into a ranked, explainable
recommendation — one that management can re-weight themselves via an interactive
What-If simulator rather than accepting a single fixed answer.

---

## Objectives

- Analyze market performance and customer demand across 46 Indian cities (Tier 1 & Tier 2)
- Compare market growth rates and 3 years of historical sales/profitability
- Measure competitor presence and estimate operating/expansion costs per market
- Calculate a transparent **Market Opportunity Score** (0–100) and rank cities
- Classify markets by **risk** and combine opportunity + risk into a recommendation
- Surface high-demand/low-competition markets and high-growth Tier-2 "hidden gems"
- Build an interactive **What-If Expansion Strategy Simulator** for management

---

## Dataset

| File | Grain | Rows* | Description |
|---|---|---|---|
| `markets.csv` | 1 row per city | 47 | Population, target customers, income, growth rate, demand/digital/infra scores |
| `sales.csv` | market × month × category | 9,938 | Orders, customers, revenue, cost, profit, discount (Jan 2023–Dec 2025) |
| `competitors.csv` | 1 row per competitor | 161 | Market share, locations, price level, brand strength, competition score |
| `operating_costs.csv` | 1 row per city | 47 | Rent, employee, marketing, logistics, setup, estimated annual cost |
| `customer_demand.csv` | market × segment | 185 | Potential/existing customers, purchase potential, demand score, growth rate |

\* Includes a small number of intentional data-quality issues (duplicates,
blanks, inconsistent capitalization/whitespace) used to demonstrate cleaning
in both SQL and Excel — see [Data Cleaning](#data-cleaning). Clean row count
is **46 markets**.

All five tables connect through `Market_ID`. Data is synthetic but built on
consistent business logic — not random noise: bigger/Tier-1 markets generally
carry more revenue and higher cost, higher-competition markets see that
reflected in their opportunity score, and Tier-2 cities can post strong
opportunity scores through growth even without Tier-1 scale.

Regenerate the datasets anytime with:
```bash
python generate_data.py
```

---

## Tools Used

- **MySQL** — schema design, data cleaning, 40+ business-question queries
- **Microsoft Excel** — fully formula-driven working model (no hardcoded results)
- **Power BI + DAX** — interactive 3-page dashboard with a live strategy simulator

---

## Data Model

```text
                         Dim_Market (markets)
                                |
        --------------------------------------------------
        |              |               |                 |
   Fact_Sales     Fact_Competitors  Fact_Costs      Fact_Demand

        Dim_Date  ---- (relates to Fact_Sales on Date)
```

One join key (`Market_ID`) is used consistently across MySQL foreign keys,
Excel `INDEX/MATCH`, and Power BI relationships — no many-to-many joins.

---

## Data Cleaning

Raw CSVs include duplicate rows, missing values (`Average_Income`,
`Discount`, `Marketing_Cost`), and formatting inconsistencies (extra spaces,
mixed capitalization). Both tools clean the same issues the same way:

- **SQL** (`00_schema_and_import.sql`) — `ROW_NUMBER()`-based de-duplication,
  `TRIM()`/case-normalization `UPDATE`s, and imputation (regional-average
  income, zero-fill discount, target-customer-based marketing cost).
- **Excel** (`Cleaned_Data` sheet) — `PROPER(TRIM(...))` formulas, `MATCH()`
  naturally resolving to the first occurrence of a duplicated ID, and an
  `IF(ISBLANK(...), AVERAGEIFS(...), ...)` imputation formula for income.

---

## SQL Analysis

Seven files in `/SQL`, run in order against a MySQL database named
`business_expansion_analysis`:

| File | Focus |
|---|---|
| `00_schema_and_import.sql` | Tables, keys, import instructions, data-quality checks & cleaning |
| `01_market_analysis.sql` | Market sizing, demand ranking, regional comparison |
| `02_sales_growth_analysis.sql` | Revenue/profit ranking, YoY growth (`LAG`), revenue-to-cost ratio |
| `03_competitor_analysis.sql` | Competitive intensity, high-demand/low-competition markets |
| `04_cost_analysis.sql` | Cost ranking, cost breakdown %, cost-efficiency |
| `05_opportunity_analysis.sql` | Market Opportunity Score build (CTEs), Top 10 ranking |
| `06_business_insights.sql` | Full decision-support view: Opportunity + Risk + Recommendation |

Demonstrates `SELECT/WHERE/GROUP BY/HAVING`, `CASE`, `INNER`/`LEFT JOIN`,
subqueries, CTEs, aggregate functions, and window functions
(`RANK`, `DENSE_RANK`, `LAG`) — every query is commented with the business
question it answers.

---

## Excel Analysis

`Excel/business_expansion_analysis.xlsx` — fully formula-driven (verified
with zero formula errors across 2,035 formulas):

`Raw_Markets / Raw_Sales / Raw_Competitors / Raw_Costs / Raw_Demand` →
`Cleaned_Data` → `Calculations` → `Market_Ranking` → `Pivot_Analysis` → `Dashboard`

Uses `SUMIFS`, `AVERAGEIFS`, `COUNTIFS`, `IF`, `IFERROR`, `INDEX/MATCH`,
`RANK`, `PERCENTILE`, `TRIM`, `PROPER`, `YEAR`/`MONTH`, `TEXT`.

---

## Power BI Dashboard

Full build guide (data model, every DAX measure, page-by-page layout,
What-If Parameter setup): **[`PowerBI/Power_BI_Build_Guide.md`](PowerBI/Power_BI_Build_Guide.md)**

### Page 1 — Executive Market Overview
KPI cards, a city map, Top 10 Expansion Markets, growth/demand/competition
by city, revenue potential by region — with Region, State, Tier, Product
Category, and Year slicers.

### Page 2 — Market Attractiveness & Risk Analysis
A Demand-vs-Competition scatter plot split into four quadrants (Most
Attractive / Competitive Opportunity / Low Priority / Avoid-Review), cost
and revenue-vs-cost visuals, risk classification, and a full market ranking
table with conditional formatting.

### Page 3 — Expansion Strategy Simulator
Five **What-If Parameters** (Demand, Growth, Revenue, Competition, Cost
weights) drive a **Dynamic Opportunity Score** that recomputes every visual
on the page live, plus three bookmarked scenarios — Balanced, Aggressive
Growth, Cost-Conscious — so the recommended city visibly changes with
strategy.

---

## Market Opportunity Score

A weighted blend of five normalized (0–100) components, calculated
identically in SQL, Excel, and DAX:

```text
Market Opportunity Score =
      Demand Score            × 30%
    + Growth Score            × 20%
    + Revenue Score           × 25%
    + Low Competition Score   × 15%
    + Low Cost Score          × 10%
```

- **Growth Score** — growth rate scaled against a 25% ceiling, capped at 100
- **Revenue Score** — average annual revenue scaled against the *90th
  percentile* across markets (not the single max, so one outsized metro
  doesn't compress everyone else's score), capped at 100
- **Low Competition Score** = 100 − average Competition Score
- **Low Cost Score** = 100 − (Estimated Annual Cost ÷ highest cost in the
  dataset × 100)

**Classification** (calibrated to this dataset's actual score spread of
~27–68): High Potential (≥65) · Attractive (55–64.9) · Consider (45–54.9) ·
Low Priority (<45).

**Risk Score** blends competition, cost, and demand/growth uncertainty:
`Competition × 0.35 + (100 − Low Cost Score) × 0.25 + (100 − Demand Score) × 0.25 + (100 − Growth Score) × 0.15`
→ Low Risk (<46) · Medium Risk (46–55.9) · High Risk (≥56).

**Recommendation** combines both: `Recommended` needs Opportunity ≥ 60 **and**
Risk < 48; `Consider` is Opportunity ≥ 60 with higher risk; `Review` is
Opportunity ≥ 48; otherwise `Avoid`.

---

## What-If Analysis

| Scenario | Demand | Growth | Revenue | Competition | Cost |
|---|---|---|---|---|---|
| **Balanced Expansion** (default) | 30% | 20% | 25% | 15% | 10% |
| **Aggressive Growth** | 30% | 35% | 30% | 3% | 2% |
| **Cost-Conscious Expansion** | 20% | 10% | 10% | 25% | 35% |

Aggressive Growth tends to push larger, faster-scaling Tier-1 metros further
up the ranking; Cost-Conscious Expansion favors lower-cost Tier-2 cities
such as Nashik, Nagpur, Raipur, and Vadodara.

---

## Key Insights

Pulled directly from the generated dataset:

- Under the balanced weighting, only **Hyderabad** (68.4) and **Surat**
  (64.4) clear both the opportunity and risk bar to be **Recommended**.
- **Delhi, Chennai, Bengaluru, and Mumbai** all score above 60 on
  opportunity but land in **Consider** — strong demand and revenue, offset
  by high cost and competition pushing risk above the cutoff.
- **Mumbai** leads total revenue (₹32.4 Cr) and profit (₹10.8 Cr) over the
  3-year history but also carries the highest risk score (58.2) of the top
  10 opportunity markets — the classic high-potential/high-risk trade-off.
- **Delhi** has the highest estimated annual operating cost (₹66.7 L) in the
  dataset; **Bhubaneswar, Siliguri, and Raipur** have the lowest (under
  ₹17.7 L) — roughly a 4× cost spread between the priciest and cheapest
  markets to enter.
- **Visakhapatnam** and **Thiruvananthapuram** are Tier-2 "hidden gems" —
  demand scores in the low-to-mid 60s against comparatively low average
  competition (48.4 / 50.2) and double-digit growth.
- **West** and **South** regions post the strongest average demand (69.1 /
  65.3) and above-average growth; **Central** and **East** trail on both.
- **Enterprise** customers show by far the highest average purchase
  potential (≈₹6.9 L) vs. Small Business (≈₹58K) and Startup (≈₹77K).

---

## Business Recommendations

1. Prioritize **Hyderabad** and **Surat** as lead candidates — both clear
   the Recommended bar with manageable risk.
2. Treat **Delhi, Chennai, Bengaluru, and Mumbai** as phase-2 candidates:
   consider a phased entry to manage cost and competitive exposure before
   committing full capital.
3. Add **Visakhapatnam** and **Thiruvananthapuram** to the Tier-2 watch
   list as lower-risk, lower-cost alternatives to a Tier-1 launch.
4. Avoid front-loading investment in the lowest-ranked markets (Jabalpur,
   Siliguri, Guwahati, Gwalior) until their demand/growth profile improves.
5. Weight the **Enterprise** customer segment more heavily where a market's
   Enterprise Demand Score is strong — it carries 3–12× the purchase
   potential of the other segments.
6. Run the Strategy Simulator live with the management team — the choice of
   *strategy*, not just the data, should be made explicit before capital is
   committed.

---

## Project Structure

```text
Business-Expansion-Market-Opportunity/
│
├── Dataset/
│   ├── markets.csv
│   ├── sales.csv
│   ├── competitors.csv
│   ├── operating_costs.csv
│   └── customer_demand.csv
│
├── SQL/
│   ├── 00_schema_and_import.sql
│   ├── 01_market_analysis.sql
│   ├── 02_sales_growth_analysis.sql
│   ├── 03_competitor_analysis.sql
│   ├── 04_cost_analysis.sql
│   ├── 05_opportunity_analysis.sql
│   └── 06_business_insights.sql
│
├── Excel/
│   └── business_expansion_analysis.xlsx
│
├── PowerBI/
│   └── Power_BI_Build_Guide.md
│
├── Documentation/
│   └── Business_Expansion_Analysis_Report.docx
│
└── README.md
```

---

## Skills Demonstrated

**SQL** — data cleaning, joins, aggregations, CTEs, window functions, ranking, business-question writing
**Excel** — data cleaning, lookup/aggregation formulas, KPI calculation, pivot-style analysis, dashboarding
**Power BI** — data modeling, relationships, DAX, KPI cards, interactive dashboards, slicers, maps, scatter analysis, conditional formatting, What-If Parameters
**Business Analysis** — market sizing, opportunity scoring, competitive analysis, cost analysis, risk analysis, strategic recommendations
**Business Development** — market expansion strategy, growth-opportunity identification, customer/revenue potential, market prioritization

---

*This project is a companion to two other portfolio projects — an
**E-Commerce Business Analysis** (business performance and customer/product
analytics) and a **Lead Conversion & Sales Funnel Dashboard** (pipeline
analytics) — and intentionally focuses on strategic market expansion and
decision-making rather than repeating standard sales/e-commerce reporting.*
