--Sales performance over time Analysis

select YEAR(ORDER_DATE) as orderDate,
COUNT(distinct customer_key) as Total_customer,
SUM(quantity) as Oredred_Quantity,
sum(sales_amount) as salesAmount
FROM gold.fact_sales
where order_date is not null
group by YEAR(ORDER_DATE)
order by YEAR(ORDER_DATE);

select DATETRUNC(MONTH, order_date) as OrderMonth,
COUNT(distinct customer_key) as Total_customer,
SUM(quantity) as Oredred_Quantity,
sum(sales_amount) as salesAmount
FROM gold.fact_sales
where order_date is not null
group by DATETRUNC(MONTH, order_date)
order by DATETRUNC(MONTH, order_date);

select FORMAT(order_date, 'yyy-mmm')
as OrderMonth,
COUNT(distinct customer_key) as Total_customer,
SUM(quantity) as Oredred_Quantity,
sum(sales_amount) as salesAmount
FROM gold.fact_sales
where order_date is not null
group by FORMAT(order_date, 'yyy-mmm')
order by FORMAT(order_date, 'yyy-mmm');

--Cumulatve Analysis(Window function's)

select orderDate, totalsales,
sum(totalsales)  over
(order by orderDate) as runnngtotalsales
from
(
select DATETRUNC( MONTH,
order_date) as orderDate,
sum(sales_amount) as totalSales
from gold.fact_sales
where order_date is not null
group by DATETRUNC( MONTH,
order_date))
as t;

use DataWarehouseAnalytics;

-- Runing total over the year

	select orderDate, totalsales,
	sum(totalsales)  over
	(order by orderDate) as runnngtotalsales,
	AvgPrice,
	AvgSales
	from
	(
	select DATETRUNC( YEAR,
	order_date) as orderDate,
	sum(sales_amount) as totalSales,
	AVG(price) as AvgPrice,
	AVG(sales_amount) as avgSales
	from gold.fact_sales
	where order_date is not null
	group by DATETRUNC( YEAR,
	order_date))
	as t;


	-- Preformance Analysis(is called as comparing current value to  target Value)(Window Functon's).

-- Analyze the yearly preformance of products by comparing each products sales to both its average sales preformance and the previous year's sales.

--diamension: orderDate, measure: sales
with  YearlyProductSales as (
select YEAR(f.order_date) as OrderYear, p.product_name,
SUM(f.sales_amount) as currentSales
from gold.fact_sales f join gold.dim_products p on f.product_key = p.product_id
where order_date is not null
group by YEAR(f.order_date), p.product_name
)
select OrderYear,product_name, currentSales,
AVG(CurrentSales) over(partition by product_name) as AvgSales,
currentSales - AVG(CurrentSales) over(partition by product_name) as Diff_Average,
case 
when currentSales - AVG(CurrentSales) over(partition by product_name) > 0 then'Above Average'
when currentSales - AVG(CurrentSales) over(partition by product_name) < 0 then 'Below Average' 
else 'Average' end diff_Avg,
LAG(currentSales) over(partition by product_name order by OrderYear) as prev_YearSales
from YearlyProductSales;


use DataWarehouseAnalytics

-- part to whole analysis

--which category has contribute the most to the overall sales

with categorySales as (
select d.category, sum(f.sales_amount) as TotalSales 
from gold.dim_products d join
gold.fact_sales f on 
d.product_key = f.product_key 
group by d.category
)
select category, TotalSales,
sum(TotalSales) over() as OverallSales,
concat(round((cast(totalSales as float)/sum(TotalSales) over()) * 100,0),'%') as precofTotalSales
from categorySales
order by precofTotalSales desc

-- Data Sgmentation(group the data based on a specific range),(Help understand the correlation between two measures)

with productSegments as (
select product_Key, product_Name, cost,
case when cost <100 then '<100'
     when cost between 100 and 500 then '100-500'
	 when cost between 500 and 1000 then '500-1000'
	 else '>1000'
end costRange
from gold.dim_products
)
select CostRange,
count(product_key) as	total_Products
from productSegments
group by CostRange
order by total_Products desc

-- Group Customer based on their spending behaviour:
-- VIP: Customer atlead 12 months of history and sprinding more then 5000.
-- Regular: Customer atlead 12 months of history and spending less or equal to 5000.
-- New: Customer with a lifespan less than 12 months
-- and find the total number of customers by each group.

select * from gold.dim_customers

select * from gold.fact_sales


With CustomerSpending as (
select  d.customer_key, sum(f.sales_amount) as TotalSpending,
min(f.order_Date) as MinORderDate,
max(f.order_date) as MAx_OrderDate,
DATEDIFF(MONTH, min(f.order_Date), Max(f.order_Date) ) as lifespan
from gold.dim_customers d join gold.fact_sales f
on d.customer_key = f.customer_key
group by d.customer_key)
select
CustomerSegment, count(customer_Key) as Total_Customers 
from(
select customer_key,
case when lifespan >= 12 and totalSpending > '5000' then 'VIP'
     when lifespan >= 12 and totalSpending <= '5000' then 'Regular' 
	 else 'New'
end CustomerSegment
from CustomerSpending 
) as t
group by CustomerSegment
order by count(customer_Key) desc;

