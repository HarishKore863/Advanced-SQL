-- Customer Report	

-- Purpose: This report consolidate key customer metrics and behaviours.

-- Highlights:
--1. GAther essential fields such as names, age and transaction details.
--2. segments customers into categories (VIP, Regular, New) and age groups.
--3. Aggregate customer level matrics: Total Orders, Total Sales, total Quantity purchased, total products, lifespan.
--4. CAlculate Valueable KPI's: recency(month since last order), average order values, average monthly spend
	 
EXEC sp_rename 'gold.cusotmer_report', 'Customer_Report';

select * from gold.Customer_Report;

create view gold.Cusotmer_Report as 
with base_query as (
select f.order_number,f.product_key,f.order_date,
f.sales_amount,f.quantity,f.price,
d.customer_id,d.customer_key,d.customer_number,
d.first_name, d.last_name, 
CONCAT(d.first_name, ' ', d.last_name) as Customer_Name,
d.birthdate, DATEDIFF(year, d.birthdate, GETDATE()) as age
 from gold.fact_sales F left join 
gold.dim_customers D on
f.customer_key = d.customer_key
where f.order_date is not null)
, CustomerAggregation as(
select customer_key, customer_number, customer_name, age,
count(distinct order_number) as Total_Orders,
sum(sales_amount) as Total_Sales,
count(distinct product_key) as Total_Products,
max(order_date) as Last_Order_Date,
datediff(month, min(order_Date), Max(Order_date)) as lifeSpan
from base_query
group by customer_key, customer_number, customer_name, age)
select 
customer_key, customer_number, customer_name, 
age,
case 
    when age < 20 then '<20'
    when age between 20 and 29 then '20-29'
	when age between 30 and 39 then '30-39'
	when age between 40 and 49 then '40-49'
else '>=50'
end AgeBin,
lifeSpan,
case 
    when lifeSpan >= 12 and Total_Sales > 5000 then 'VIP'
    when lifeSpan <= 12 and Total_Sales <= 5000 then 'Regular'
else 'New'
end LifeSpanSegment,
Total_Orders, Total_Sales, Total_Products,
last_order_date,
datediff(month, Last_Order_Date, GETDATE()) as recency,
--	Compuate average order value
case 
    when Total_Orders = 0 then 0
    else Total_Sales / Total_Orders end Avg_order_value,
-- Compuate Average Monthly Sales
case
    when lifeSpan = 0 then Total_Sales
    else total_Sales / lifeSpan 
end Avg_Monthly_Sales
from CustomerAggregation;

