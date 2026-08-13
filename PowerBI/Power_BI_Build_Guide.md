# Power BI Build Guide — Business Expansion & Market Opportunity Dashboard

This guide walks through building the 3-page Power BI dashboard from the five
CSVs in `/Dataset`. It covers the data model, every DAX measure, page-by-page
layout, and the What-If Expansion Strategy Simulator.

---

## 1. Data Model

Import all five CSVs (`markets.csv`, `sales.csv`, `competitors.csv`,
`operating_costs.csv`, `customer_demand.csv`) via **Get Data > Text/CSV**,
then clean each in Power Query before loading:

| Table              | Power Query cleaning steps |
|---------------------|----------------------------|
| `markets`            | Trim + Proper Case on `City`/`State`; remove duplicate rows (by `Market_ID`); replace blank `Average_Income` with the regional average (`Group By` Region → merge back) |
| `sales`               | Change `Date` to Date type; remove duplicate rows; replace null `Discount` with 0 |
| `competitors`         | Trim + Proper Case on `Competitor_Name`; standardize `Price_Level` capitalization |
| `operating_costs`     | Replace null `Marketing_Cost` using a merged query against `markets.Estimated_Target_Customers * 5` |
| `customer_demand`     | Trim `Customer_Segment`; remove duplicate rows |

Build a star schema:

```
                         Dim_Market (markets)
                                |
        --------------------------------------------------
        |              |               |                 |
   Fact_Sales     Fact_Competitors  Fact_Costs      Fact_Demand
   (sales)        (competitors)   (operating_costs) (customer_demand)

        Dim_Date  ---- (relates to Fact_Sales on Date)
```

**Relationships** (all single-direction, one-to-many from Dim_Market):
- `Dim_Market[Market_ID]` → `Fact_Sales[Market_ID]` (1:*)
- `Dim_Market[Market_ID]` → `Fact_Competitors[Market_ID]` (1:*)
- `Dim_Market[Market_ID]` → `Fact_Costs[Market_ID]` (1:1)
- `Dim_Market[Market_ID]` → `Fact_Demand[Market_ID]` (1:*)
- `Dim_Date[Date]` → `Fact_Sales[Date]` (1:*)

Create `Dim_Date` with **New Table**:
```dax
Dim_Date =
CALENDAR ( DATE ( 2023, 1, 1 ), DATE ( 2025, 12, 31 ) )
```
Add columns for `Year = YEAR([Date])`, `Month = FORMAT([Date],"MMM")`,
`MonthNumber = MONTH([Date])`.

Rename tables in the model view to `Dim_Market`, `Fact_Sales`,
`Fact_Competitors`, `Fact_Costs`, `Fact_Demand` for clarity. Avoid
many-to-many relationships — every fact table relates back to `Dim_Market`
only through `Market_ID`.

---

## 2. DAX Measures

Create a dedicated **Measures** table (a blank table with no columns, used
only to hold measures) so they're easy to find.

### Core sales measures
```dax
Total Revenue = SUM ( Fact_Sales[Revenue] )

Total Cost = SUM ( Fact_Sales[Cost] )

Total Profit = SUM ( Fact_Sales[Profit] )

Profit Margin = DIVIDE ( [Total Profit], [Total Revenue], 0 )

Total Customers = SUM ( Fact_Sales[Customers] )

Total Orders = SUM ( Fact_Sales[Orders] )
```

### Market fundamentals
```dax
Average Demand Score = AVERAGE ( Dim_Market[Demand_Score] )

Average Competition Score = AVERAGE ( Fact_Competitors[Competition_Score] )

Average Market Growth = AVERAGE ( Dim_Market[Market_Growth_Rate] )

Estimated Operating Cost = SUM ( Fact_Costs[Estimated_Annual_Cost] )

Revenue Potential = DIVIDE ( [Total Revenue], 3, 0 )   -- 3 years of history -> avg annual
```

### Efficiency measures
```dax
Revenue-to-Cost Ratio = DIVIDE ( [Revenue Potential], [Estimated Operating Cost], 0 )

YoY Revenue Growth =
VAR CurrentYearRevenue =
    CALCULATE ( [Total Revenue], DATESYTD ( Dim_Date[Date] ) )
VAR PriorYearRevenue =
    CALCULATE ( [Total Revenue], SAMEPERIODLASTYEAR ( Dim_Date[Date] ) )
RETURN
    DIVIDE ( CurrentYearRevenue - PriorYearRevenue, PriorYearRevenue, 0 )
```

### Normalized 0-100 component scores (feed the Opportunity Score)
```dax
Demand Score = [Average Demand Score]

Growth Score =
MIN ( 100, DIVIDE ( [Average Market Growth], 25, 0 ) * 100 )

Competition Attractiveness Score =
100 - [Average Competition Score]

Cost Attractiveness Score =
VAR MaxCost =
    CALCULATE ( MAX ( Fact_Costs[Estimated_Annual_Cost] ), ALL ( Dim_Market ) )
RETURN
    100 - DIVIDE ( [Estimated Operating Cost], MaxCost, 0 ) * 100

Revenue Score =
VAR P90Revenue =
    CALCULATE (
        PERCENTILEX.INC ( ALL ( Dim_Market[Market_ID] ), [Revenue Potential], 0.9 )
    )
RETURN
    MIN ( 100, DIVIDE ( [Revenue Potential], P90Revenue, 0 ) * 100 )
```

### Market Opportunity Score (fixed weights — matches Excel/SQL methodology)
```dax
Market Opportunity Score =
[Demand Score] * 0.30
    + [Growth Score] * 0.20
    + [Revenue Score] * 0.25
    + [Competition Attractiveness Score] * 0.15
    + [Cost Attractiveness Score] * 0.10
```

### Dynamic Opportunity Score (uses the What-If Parameters — see Section 4)
```dax
Dynamic Opportunity Score =
[Demand Score] * 'Demand Weight'[Demand Weight Value]
    + [Growth Score] * 'Growth Weight'[Growth Weight Value]
    + [Revenue Score] * 'Revenue Weight'[Revenue Weight Value]
    + [Competition Attractiveness Score] * 'Competition Weight'[Competition Weight Value]
    + [Cost Attractiveness Score] * 'Cost Weight'[Cost Weight Value]
```

### Ranking, risk, and classification
```dax
Market Rank =
RANKX ( ALL ( Dim_Market[City] ), [Dynamic Opportunity Score],, DESC, DENSE )

Risk Score =
[Average Competition Score] * 0.35
    + ( 100 - [Cost Attractiveness Score] ) * 0.25
    + ( 100 - [Demand Score] ) * 0.25
    + ( 100 - [Growth Score] ) * 0.15

Risk Level =
SWITCH (
    TRUE (),
    [Risk Score] >= 56, "High Risk",
    [Risk Score] >= 46, "Medium Risk",
    "Low Risk"
)

Opportunity Class =
SWITCH (
    TRUE (),
    [Dynamic Opportunity Score] >= 65, "High Potential",
    [Dynamic Opportunity Score] >= 55, "Attractive",
    [Dynamic Opportunity Score] >= 45, "Consider",
    "Low Priority"
)

Recommendation =
SWITCH (
    TRUE (),
    [Dynamic Opportunity Score] >= 60 && [Risk Score] < 48, "Recommended",
    [Dynamic Opportunity Score] >= 60, "Consider",
    [Dynamic Opportunity Score] >= 48, "Review",
    "Avoid"
)

High Potential Markets =
CALCULATE (
    DISTINCTCOUNT ( Dim_Market[Market_ID] ),
    FILTER ( ALL ( Dim_Market[City] ), [Opportunity Class] = "High Potential" )
)
```
> Note: thresholds above are calibrated to this dataset's actual score
> spread (roughly 27-68 for opportunity, 38-64 for risk) — the same bands
> used in the Excel workbook and SQL scripts, so all three tools agree.

---

## 3. Page-by-Page Build

### Page 1 — Executive Market Overview
- **KPI cards**: `Markets Analyzed` (`DISTINCTCOUNT(Dim_Market[Market_ID])`),
  `[High Potential Markets]`, `[Revenue Potential]` (formatted ₹, in Cr),
  `[Average Market Growth]`, `[Market Opportunity Score]` (as an average),
  `Best Expansion Market` (a card using `TOPN(1, ..., [Market Opportunity Score])`
  or a measure wrapping `FIRSTNONBLANK`).
- **India map (Shape/Filled Map)**: latitude/longitude or `City`+`State`
  bubble map sized by `[Market Opportunity Score]`, colored by `Opportunity Class`.
- **Top 10 Expansion Markets**: horizontal bar chart, `City` on axis,
  `[Market Opportunity Score]` on value, filtered `TopN = 10`.
- **Market Growth by City**: bar chart of `Market_Growth_Rate`.
- **Revenue Potential by Region**: stacked/clustered bar, `Region` on axis,
  `[Revenue Potential]` on value.
- **Customer Demand by City**: bar chart of `Demand_Score`.
- **Competition by Market**: bar chart of `[Average Competition Score]`.
- **Slicers**: Region, State, Market_Tier, Product_Category, Year.

### Page 2 — Expansion Decision Analysis (Market Attractiveness & Risk)
- **Scatter plot**: X = `[Average Competition Score]`, Y = `[Demand Score]`,
  size = `[Revenue Potential]`, legend = `Opportunity Class`. Add two
  constant reference lines (median X, median Y) to visually split the
  four quadrants:
  - High Demand + Low Competition → **Most Attractive**
  - High Demand + High Competition → **Competitive Opportunity**
  - Low Demand + Low Competition → **Low Priority**
  - Low Demand + High Competition → **Avoid / Review**
- **Operating Cost by City**: bar chart, `[Estimated Operating Cost]`.
- **Revenue Potential vs Cost**: combo chart (bar = revenue, line = cost).
- **Growth vs Competition**: scatter, X = growth, Y = competition.
- **Market Risk Classification**: donut/bar of `[Risk Level]` counts.
- **Top Opportunity Markets**: table sorted by `[Market Opportunity Score]`.
- **Market Ranking Table** (all fields required by the brief):
  `City, Region, Demand_Score, Market_Growth_Rate, [Average Competition Score],
  [Estimated Operating Cost], [Revenue Potential], [Market Opportunity Score],
  [Risk Level], [Recommendation]`. Apply conditional formatting (color
  scales) to the score columns and data bars to the cost column.

### Page 3 — Expansion Strategy Simulator
See Section 4 below for the What-If Parameters, then:
- 5 slicers, one per weight parameter.
- **Dynamic Opportunity Score** KPI card + **Best Expansion Market** card
  (both recompute live as sliders move).
- **Top 10 Market Ranking**: bar chart on `[Dynamic Opportunity Score]`.
- **Recommended Markets** table filtered to `[Recommendation] = "Recommended"`.
- **City Comparison**: a small multiples or clustered bar comparing 3-5
  user-selected cities across all five component scores (use a
  disconnected "Selected Cities" slicer on `Dim_Market[City]`).
- Add 3 bookmarks (Section 5) so a reviewer can click between the
  Balanced / Aggressive Growth / Cost-Conscious scenarios instantly.

---

## 4. What-If Parameters (Strategy Simulator)

Use **Modeling > New Parameter > Numeric Range** for each weight
(Min 0, Max 1, Increment 0.05, Default per below). This creates a
disconnected single-column table plus a `<Name> Value` measure automatically.

| Parameter | Table name | Default |
|---|---|---|
| Demand importance | `Demand Weight` | 0.30 |
| Growth importance | `Growth Weight` | 0.20 |
| Revenue importance | `Revenue Weight` | 0.25 |
| Competition importance | `Competition Weight` | 0.15 |
| Cost importance | `Cost Weight` | 0.10 |

Add each parameter's slicer to Page 3. The `Dynamic Opportunity Score`
measure (Section 2) already references these `<Name> Value` measures, so
every visual bound to it updates live as the person drags a slider.

**Tip for the interview:** because the five weights are independent
sliders rather than one that auto-balances the rest, mention in the demo
that weights don't have to sum to 100% — the score is a weighted sum,
not a normalized average — and that's a deliberate simplification so
management can explore "what if we only cared about growth" without the
UI fighting them.

---

## 5. Strategic Scenarios (bookmark each one)

| Scenario | Demand | Growth | Revenue | Competition | Cost |
|---|---|---|---|---|---|
| **Balanced Expansion** (default) | 0.30 | 0.20 | 0.25 | 0.15 | 0.10 |
| **Aggressive Growth** | 0.30 | 0.35 | 0.30 | 0.03 | 0.02 |
| **Cost-Conscious Expansion** | 0.20 | 0.10 | 0.10 | 0.25 | 0.35 |

To capture each: set the sliders, then **View > Bookmarks > Add**, name
it, and enable "Data" capture only (not "All visuals") so the bookmark
just replays the slicer state. In the demo, switching from Balanced to
Aggressive Growth typically pushes larger, faster-growing Tier-1 metros
to the top of the ranking, while Cost-Conscious Expansion favors
lower-cost Tier-2 cities such as Nashik, Nagpur, or Vadodara — a good
talking point on how the "right" answer depends on strategy, not just data.

---

## 6. Formatting Notes
- Corporate palette: navy (`#1F4E78`) for headers/KPI accents, a single
  accent color per opportunity class (green = Recommended, amber =
  Review, grey = Avoid) reused consistently across every page.
- Use tooltips (Page 2 scatter) showing `City, Demand_Score,
  Competition_Score, Estimated_Annual_Cost, Recommendation` on hover.
- Keep every page to 6-8 visuals max — this is a strategy dashboard for
  management, not a data dump.
