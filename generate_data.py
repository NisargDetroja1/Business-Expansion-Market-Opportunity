"""
Dataset generation script — Business Expansion & Market Opportunity Dashboard
Generates 5 related CSVs with logical business relationships (not random noise).
Run: python generate_data.py
"""

import csv
import random
import os

random.seed(42)

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Dataset")
os.makedirs(OUT_DIR, exist_ok=True)

# ---------------------------------------------------------------------------
# 1. MARKET MASTER DATA (city, state, region, tier, population, income, ...)
# ---------------------------------------------------------------------------
# (City, State, Region, Tier, Population in lakhs (approx, realistic order of magnitude))
CITIES = [
    ("Mumbai", "Maharashtra", "West", "Tier 1", 128.4),
    ("Pune", "Maharashtra", "West", "Tier 1", 68.0),
    ("Nashik", "Maharashtra", "West", "Tier 2", 20.8),
    ("Nagpur", "Maharashtra", "West", "Tier 2", 25.4),
    ("Ahmedabad", "Gujarat", "West", "Tier 1", 63.6),
    ("Vadodara", "Gujarat", "West", "Tier 2", 21.4),
    ("Surat", "Gujarat", "West", "Tier 1", 61.2),
    ("Rajkot", "Gujarat", "West", "Tier 2", 14.9),
    ("Bhavnagar", "Gujarat", "West", "Tier 2", 6.0),
    ("Jaipur", "Rajasthan", "North", "Tier 1", 39.6),
    ("Udaipur", "Rajasthan", "North", "Tier 2", 6.1),
    ("Jodhpur", "Rajasthan", "North", "Tier 2", 10.3),
    ("Delhi", "Delhi", "North", "Tier 1", 190.0),
    ("Noida", "Uttar Pradesh", "North", "Tier 1", 8.7),
    ("Gurugram", "Haryana", "North", "Tier 1", 11.5),
    ("Chandigarh", "Chandigarh", "North", "Tier 1", 10.6),
    ("Lucknow", "Uttar Pradesh", "North", "Tier 1", 35.0),
    ("Kanpur", "Uttar Pradesh", "North", "Tier 2", 29.2),
    ("Agra", "Uttar Pradesh", "North", "Tier 2", 17.5),
    ("Varanasi", "Uttar Pradesh", "North", "Tier 2", 14.4),
    ("Amritsar", "Punjab", "North", "Tier 2", 12.3),
    ("Ludhiana", "Punjab", "North", "Tier 2", 17.4),
    ("Dehradun", "Uttarakhand", "North", "Tier 2", 8.0),
    ("Bengaluru", "Karnataka", "South", "Tier 1", 133.0),
    ("Mysuru", "Karnataka", "South", "Tier 2", 12.0),
    ("Hyderabad", "Telangana", "South", "Tier 1", 100.4),
    ("Chennai", "Tamil Nadu", "South", "Tier 1", 107.1),
    ("Coimbatore", "Tamil Nadu", "South", "Tier 2", 21.4),
    ("Madurai", "Tamil Nadu", "South", "Tier 2", 14.6),
    ("Kochi", "Kerala", "South", "Tier 2", 21.3),
    ("Thiruvananthapuram", "Kerala", "South", "Tier 2", 17.5),
    ("Visakhapatnam", "Andhra Pradesh", "South", "Tier 2", 20.4),
    ("Vijayawada", "Andhra Pradesh", "South", "Tier 2", 10.5),
    ("Kolkata", "West Bengal", "East", "Tier 1", 141.2),
    ("Bhubaneswar", "Odisha", "East", "Tier 2", 8.8),
    ("Patna", "Bihar", "East", "Tier 2", 20.5),
    ("Ranchi", "Jharkhand", "East", "Tier 2", 11.3),
    ("Guwahati", "Assam", "East", "Tier 2", 9.6),
    ("Siliguri", "West Bengal", "East", "Tier 2", 7.0),
    ("Bhopal", "Madhya Pradesh", "Central", "Tier 2", 20.7),
    ("Indore", "Madhya Pradesh", "Central", "Tier 1", 32.1),
    ("Raipur", "Chhattisgarh", "Central", "Tier 2", 10.7),
    ("Jabalpur", "Madhya Pradesh", "Central", "Tier 2", 12.7),
    ("Gwalior", "Madhya Pradesh", "Central", "Tier 2", 11.4),
    ("Faridabad", "Haryana", "North", "Tier 2", 14.0),
    ("Nagercoil", "Tamil Nadu", "South", "Tier 2", 2.3),
]

REGION_INCOME_BASE = {"North": 42000, "South": 46000, "East": 34000,
                       "West": 48000, "Central": 33000}

markets = []
for i, (city, state, region, tier, pop_lakh) in enumerate(CITIES, start=1):
    market_id = f"M{i:03d}"
    population = int(pop_lakh * 100000)

    tier_factor = 1.15 if tier == "Tier 1" else 1.0
    base_income = REGION_INCOME_BASE[region] * tier_factor
    # bigger cities skew income slightly higher too
    size_bonus = min(population / 200000, 1.0) * 6000
    average_income = int(base_income + size_bonus + random.randint(-2000, 2000))

    # Estimated target customers: a business-relevant fraction of population,
    # scaled by income (affordability) and digital readiness proxy
    digital_adoption = round(
        min(95, max(35,
            (55 if tier == "Tier 1" else 40)
            + (average_income - 35000) / 1500
            + random.uniform(-5, 5))), 1)
    infrastructure = round(
        min(95, max(30,
            (60 if tier == "Tier 1" else 42)
            + (average_income - 35000) / 2000
            + random.uniform(-6, 6))), 1)

    target_fraction = 0.015 + (digital_adoption / 100) * 0.02
    estimated_target_customers = int(population * target_fraction)

    # Growth rate: Tier-2 emerging cities can grow faster off a smaller base;
    # very large saturated metros grow slower.
    if tier == "Tier 2":
        growth = random.uniform(9.0, 22.0)
    else:
        growth = random.uniform(4.0, 13.0)
    if population > 9000000:
        growth -= random.uniform(1.5, 3.5)
    market_growth_rate = round(max(3.0, growth), 1)

    # Demand score: function of target customers density, income, digital adoption
    # (raw value is min-max rescaled across all cities below, so the full
    # 0-100 range is used rather than compressing into the 30-55 band)
    demand_raw = (
        (estimated_target_customers / max(population, 1)) * 100 * 1.8
        + digital_adoption * 0.35
        + (average_income / 1000) * 0.25
    )

    markets.append({
        "Market_ID": market_id,
        "City": city,
        "State": state,
        "Region": region,
        "Market_Tier": tier,
        "Population": population,
        "Estimated_Target_Customers": estimated_target_customers,
        "Average_Income": average_income,
        "Market_Growth_Rate": market_growth_rate,
        "_demand_raw": demand_raw,
        "Digital_Adoption_Score": digital_adoption,
        "Infrastructure_Score": infrastructure,
    })

# --- rescale Demand_Score across the full 0-100 band (min-max stretch) so
#     the strongest markets land in the 85-95 range and the weakest in the
#     25-35 range, matching the classification bands used downstream ---
raw_values = [m["_demand_raw"] for m in markets]
raw_min, raw_max = min(raw_values), max(raw_values)
for m in markets:
    stretched = 25 + (m.pop("_demand_raw") - raw_min) / (raw_max - raw_min) * 68
    m["Demand_Score"] = round(min(96, max(22, stretched + random.uniform(-3, 3))), 1)

# --- inject light, realistic data-quality issues into markets.csv ---
markets_dirty = [dict(m) for m in markets]
# inconsistent capitalization / extra spaces on a few city names
markets_dirty[2]["City"] = " " + markets_dirty[2]["City"].upper()
markets_dirty[10]["City"] = markets_dirty[10]["City"].lower() + "  "
markets_dirty[25]["State"] = markets_dirty[25]["State"] + "  "
# one duplicate record (same market re-appended with a new row, will be cleaned in SQL/Excel)
markets_dirty.append(dict(markets_dirty[5]))
# one missing value
markets_dirty[18]["Average_Income"] = ""

MARKET_FIELDS = ["Market_ID", "City", "State", "Region", "Market_Tier", "Population",
                  "Estimated_Target_Customers", "Average_Income", "Market_Growth_Rate",
                  "Demand_Score", "Digital_Adoption_Score", "Infrastructure_Score"]

with open(os.path.join(OUT_DIR, "markets.csv"), "w", newline="", encoding="utf-8") as f:
    fieldnames = MARKET_FIELDS
    w = csv.DictWriter(f, fieldnames=fieldnames)
    w.writeheader()
    w.writerows(markets_dirty)

market_lookup = {m["Market_ID"]: m for m in markets}

# ---------------------------------------------------------------------------
# 2. SALES (monthly grain per market per product category, Jan-2023..Dec-2025)
# ---------------------------------------------------------------------------
CATEGORIES = ["Software", "Business Services", "Consulting",
              "Digital Solutions", "SaaS", "IT Services"]
CATEGORY_BASE_TICKET = {
    "Software": 18000, "Business Services": 9000, "Consulting": 25000,
    "Digital Solutions": 14000, "SaaS": 12000, "IT Services": 16000,
}

MONTHS = []
for year in (2023, 2024, 2025):
    for month in range(1, 13):
        MONTHS.append((year, month))

sales_rows = []
sale_id = 1
for m in markets:
    # market "maturity multiplier": larger/tier1 markets have bigger base volume
    size_factor = max(0.4, min(3.0, m["Population"] / 4000000))
    demand_factor = m["Demand_Score"] / 60
    for cat in CATEGORIES:
        base_orders = max(6, int(18 * size_factor * demand_factor
                                  * random.uniform(0.7, 1.3)))
        for month_idx, (year, month) in enumerate(MONTHS):
            # gradual growth over time using the market's own growth rate
            growth_factor = (1 + m["Market_Growth_Rate"] / 100) ** (month_idx / 12)
            seasonality = 1 + 0.08 * (1 if month in (3, 10, 11, 12) else 0)
            orders = max(1, int(base_orders * growth_factor * seasonality
                                 * random.uniform(0.85, 1.15)))
            customers = max(1, int(orders * random.uniform(0.55, 0.8)))
            avg_ticket = CATEGORY_BASE_TICKET[cat] * random.uniform(0.9, 1.15)
            revenue = round(orders * avg_ticket, 2)
            # cost ratio slightly worse in high-competition / lower-infra markets
            cost_ratio = 0.62 + (100 - m["Infrastructure_Score"]) / 500 \
                + random.uniform(-0.03, 0.03)
            cost = round(revenue * min(0.85, max(0.45, cost_ratio)), 2)
            profit = round(revenue - cost, 2)
            discount = round(revenue * random.uniform(0.02, 0.09), 2)

            sales_rows.append({
                "Sale_ID": f"S{sale_id:06d}",
                "Date": f"{year}-{month:02d}-01",
                "Market_ID": m["Market_ID"],
                "Product_Category": cat,
                "Orders": orders,
                "Customers": customers,
                "Revenue": revenue,
                "Cost": cost,
                "Profit": profit,
                "Discount": discount,
            })
            sale_id += 1

# --- light data-quality issues in sales.csv ---
sales_dirty = sales_rows[:]
# a few missing Discount values
for idx in (50, 4321, 9000):
    sales_dirty[idx]["Discount"] = ""
# a couple of duplicate rows
sales_dirty.append(dict(sales_dirty[100]))
sales_dirty.append(dict(sales_dirty[7000]))
# inconsistent category capitalization
sales_dirty[250]["Product_Category"] = sales_dirty[250]["Product_Category"].lower()

with open(os.path.join(OUT_DIR, "sales.csv"), "w", newline="", encoding="utf-8") as f:
    fieldnames = list(sales_rows[0].keys())
    w = csv.DictWriter(f, fieldnames=fieldnames)
    w.writeheader()
    w.writerows(sales_dirty)

# ---------------------------------------------------------------------------
# 3. COMPETITORS (2-5 competitors per market)
# ---------------------------------------------------------------------------
COMPETITOR_NAME_POOL = [
    "Apex Business Solutions", "NextGen Consulting", "BlueWave Technologies",
    "Vertex Digital", "Pinnacle Services", "Orbit Software", "Skyline Consulting",
    "CoreStack IT", "Zenith Solutions", "Nova Business Group", "TrueNorth Advisory",
    "Bright Path Consulting", "InfoEdge Systems", "Momentum Digital",
    "Silverline Technologies", "Quantum Business Services",
]

comp_rows = []
comp_id = 1
for m in markets:
    # bigger / higher-income markets attract more competitors
    n_competitors = 2
    if m["Population"] > 3000000:
        n_competitors += 2
    if m["Average_Income"] > 45000:
        n_competitors += 1
    n_competitors = min(6, max(2, n_competitors + random.randint(-1, 1)))

    names = random.sample(COMPETITOR_NAME_POOL, n_competitors)
    remaining_share = 100.0
    for j, name in enumerate(names):
        is_last = (j == len(names) - 1)
        if is_last:
            market_share = round(max(2.0, remaining_share), 1)
        else:
            share = round(random.uniform(4, min(30, remaining_share - 2)), 1)
            market_share = share
            remaining_share -= share
        locations = max(1, int(1 + market_share / 12 + random.uniform(-0.5, 1)))
        price_level = random.choice(["Low", "Medium", "Medium", "High"])
        brand_strength = round(min(95, max(20, market_share * 2.3
                                            + random.uniform(-8, 8))), 1)
        competition_score = round(min(97, max(15,
            market_share * 1.6 + brand_strength * 0.3 + locations * 1.5
            + random.uniform(-5, 5))), 1)

        comp_rows.append({
            "Competitor_ID": f"C{comp_id:04d}",
            "Market_ID": m["Market_ID"],
            "Competitor_Name": name,
            "Market_Share": market_share,
            "Number_of_Locations": locations,
            "Price_Level": price_level,
            "Brand_Strength": brand_strength,
            "Competition_Score": competition_score,
        })
        comp_id += 1

comp_dirty = comp_rows[:]
comp_dirty[15]["Competitor_Name"] = "  " + comp_dirty[15]["Competitor_Name"].upper()
comp_dirty.append(dict(comp_dirty[3]))
comp_dirty[40]["Price_Level"] = "medium"

with open(os.path.join(OUT_DIR, "competitors.csv"), "w", newline="", encoding="utf-8") as f:
    fieldnames = list(comp_rows[0].keys())
    w = csv.DictWriter(f, fieldnames=fieldnames)
    w.writeheader()
    w.writerows(comp_dirty)

# ---------------------------------------------------------------------------
# 4. OPERATING COSTS (one row per market)
# ---------------------------------------------------------------------------
cost_rows = []
cost_id = 1
for m in markets:
    tier1 = m["Market_Tier"] == "Tier 1"
    rent_base = 85000 if tier1 else 42000
    office_rent = int(rent_base * (m["Average_Income"] / 40000)
                       * random.uniform(0.85, 1.2))
    employee_cost = int((650000 if tier1 else 420000)
                         * (m["Average_Income"] / 40000)
                         * random.uniform(0.9, 1.15))
    marketing_cost = int((m["Estimated_Target_Customers"]) * random.uniform(3.5, 6.5))
    logistics_cost = int((180000 if tier1 else 120000) * random.uniform(0.8, 1.3))
    setup_cost = int((900000 if tier1 else 550000) * random.uniform(0.85, 1.2))

    estimated_annual_cost = (office_rent * 12) + employee_cost + marketing_cost \
        + logistics_cost + setup_cost

    cost_rows.append({
        "Cost_ID": f"OC{cost_id:03d}",
        "Market_ID": m["Market_ID"],
        "Office_Rent": office_rent,
        "Employee_Cost": employee_cost,
        "Marketing_Cost": marketing_cost,
        "Logistics_Cost": logistics_cost,
        "Setup_Cost": setup_cost,
        "Estimated_Annual_Cost": estimated_annual_cost,
    })
    cost_id += 1

cost_dirty = cost_rows[:]
cost_dirty[7]["Marketing_Cost"] = ""
cost_dirty.append(dict(cost_dirty[20]))

with open(os.path.join(OUT_DIR, "operating_costs.csv"), "w", newline="", encoding="utf-8") as f:
    fieldnames = list(cost_rows[0].keys())
    w = csv.DictWriter(f, fieldnames=fieldnames)
    w.writeheader()
    w.writerows(cost_dirty)

# ---------------------------------------------------------------------------
# 5. CUSTOMER DEMAND (per market per segment)
# ---------------------------------------------------------------------------
SEGMENTS = ["Small Business", "Mid-Market", "Enterprise", "Startup"]
SEGMENT_WEIGHT = {"Small Business": 0.42, "Mid-Market": 0.28,
                  "Enterprise": 0.12, "Startup": 0.18}
SEGMENT_PURCHASE_BASE = {"Small Business": 45000, "Mid-Market": 160000,
                          "Enterprise": 520000, "Startup": 60000}

demand_rows = []
demand_id = 1
for m in markets:
    for seg in SEGMENTS:
        potential = int(m["Estimated_Target_Customers"] * SEGMENT_WEIGHT[seg]
                         * random.uniform(0.9, 1.1))
        # Enterprise segment scales with infrastructure & income; startups with digital adoption
        if seg == "Enterprise":
            penetration = 0.05 + m["Infrastructure_Score"] / 1000
        elif seg == "Startup":
            penetration = 0.08 + m["Digital_Adoption_Score"] / 800
        else:
            penetration = 0.12 + m["Demand_Score"] / 900
        existing = int(potential * min(0.6, max(0.03, penetration)) * random.uniform(0.85, 1.1))
        purchase_potential = int(SEGMENT_PURCHASE_BASE[seg]
                                  * (m["Average_Income"] / 40000)
                                  * random.uniform(0.85, 1.2))
        demand_score = round(min(97, max(20,
            (potential - existing) / max(potential, 1) * 40
            + m["Demand_Score"] * 0.55 + random.uniform(-4, 4))), 1)
        customer_growth_rate = round(max(2.0,
            m["Market_Growth_Rate"] * random.uniform(0.7, 1.3)), 1)

        demand_rows.append({
            "Demand_ID": f"D{demand_id:04d}",
            "Market_ID": m["Market_ID"],
            "Customer_Segment": seg,
            "Potential_Customers": potential,
            "Existing_Customers": existing,
            "Purchase_Potential": purchase_potential,
            "Demand_Score": demand_score,
            "Customer_Growth_Rate": customer_growth_rate,
        })
        demand_id += 1

demand_dirty = demand_rows[:]
demand_dirty[9]["Customer_Segment"] = " " + demand_dirty[9]["Customer_Segment"] + " "
demand_dirty.append(dict(demand_dirty[60]))

with open(os.path.join(OUT_DIR, "customer_demand.csv"), "w", newline="", encoding="utf-8") as f:
    fieldnames = list(demand_rows[0].keys())
    w = csv.DictWriter(f, fieldnames=fieldnames)
    w.writeheader()
    w.writerows(demand_dirty)

print(f"Markets: {len(markets_dirty)} rows")
print(f"Sales: {len(sales_dirty)} rows")
print(f"Competitors: {len(comp_dirty)} rows")
print(f"Operating Costs: {len(cost_dirty)} rows")
print(f"Customer Demand: {len(demand_dirty)} rows")
print("Done.")
