# Data Generation Prompts

## Tool used
Claude (claude-sonnet-4-20250514)

##Prompt 1 — leads.csv
You are a data generation assistant. Generate a synthetic CRM dataset 
for a B2B tech staffing firm based in the US. The firm connects 
companies with specialized tech professionals.
Output a CSV with exactly 380 rows and these columns:
lead_id: sequential, format LEAD-001 to LEAD-380
entry_date: random dates between 2023-01-01 and 2024-12-31, 
  distributed realistically across months (slight peaks in Q1 and Q3)
channel: one of [Referral, LinkedIn, Website, Cold_Outreach]
  distribution: Referral 25%, LinkedIn 35%, Website 25%, 
  Cold_Outreach 15%
service_type: one of [Contract_Staffing, Direct_Hire, Consulting]
  distribution: Contract_Staffing 45%, Direct_Hire 35%, 
  Consulting 20%
stage_reached: one of [Lead, Qualified, Proposal, Negotiation, 
  Closed_Won, Closed_Lost]
  Apply this drop-off logic:
  - Lead → Qualified: 55% advance
  - Qualified → Proposal: 70% advance
  - Proposal → Negotiation: 65% advance
  - Negotiation → Closed_Won: 75% advance
  - Overall Closed_Won rate: ~22% of total leads
days_in_funnel: integer, days from entry_date to stage exit
  Ranges by stage: Lead 3–10d, Qualified 7–20d, Proposal 14–30d, 
  Negotiation 7–21d, Closed 1–5d
deal_value: integer in USD
  Only assign if stage_reached is Negotiation or Closed_Won
  Ranges: Contract_Staffing –, Direct_Hire –, 
  Consulting –
  Assign NULL for earlier stages
assigned_rep: one of [Rep_A, Rep_B, Rep_C, Rep_D, Rep_E]
  distributed roughly evenly with small random variation
converted: 1 if stage_reached is Closed_Won, 0 otherwise
Make the data internally consistent. Referral should have the 
highest conversion rate (~32%). Cold_Outreach the lowest (~12%). 
LinkedIn and Website should be between 18–24%.
Return only the CSV content, no explanation, no markdown formatting.
 ## Prompt 2 — monthly_metrics.csv

You are a data generation assistant. Generate a synthetic monthly 
KPI dataset for a B2B tech staffing firm. This table summarizes 
operational performance across 24 months.
Output a CSV with exactly 24 rows (Jan 2023 – Dec 2024) 
and these columns:
month: format YYYY-MM, from 2023-01 to 2024-12
new_leads: integer, monthly new leads entering the funnel
  Average ~16/month, with realistic variation
  Slight peaks in Jan–Mar and Jul–Sep
total_qualified: integer, ~55% of new_leads with small variation
total_proposals: integer, ~38% of new_leads
total_negotiations: integer, ~25% of new_leads
total_closed_won: integer, ~22% of new_leads, minimum 2/month
conversion_rate: decimal, total_closed_won / new_leads, 
  rounded to 3 decimals
avg_cycle_days: integer, average days from entry to Closed_Won
  Range 35–65 days, with slight upward trend mid-2023 
  and improvement in 2024
revenue: integer, total deal value of Closed_Won deals that month
  Derive from total_closed_won × average deal size per month
  Average deal ~, with variation –
lead_velocity_change: decimal, % change in new_leads vs prior month
  Format: 0.05 means +5%, -0.08 means -8%
  First month (2023-01): assign 0.00
Make the numbers internally consistent across all columns. 
Slight positive trend in conversion_rate in H2 2024 
to simulate operational improvement.
Return only the CSV content, no explanation, no markdown formatting.
## Validation results
 - leads.csv: 380 rows, Referral conversion: 31.6%, Overall Closed_Won conversion: 21.8%
- monthly_metrics.csv: 24 rows, avg monthly revenue:  

## Notes Data was generated synthetically and calibrated to reflect realistic B2B professional services dynamics. No real client or company data was used.
