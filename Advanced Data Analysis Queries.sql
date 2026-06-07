/*
=============================================================
Create Database and Schemas
=============================================================
Script Purpose:
    This script creates a new database named 'DataWarehouseAnalytics' after checking if it already exists. 
    If the database exists, it is dropped and recreated. Additionally, this script creates a schema called gold
	
WARNING:
    Running this script will drop the entire 'DataWarehouseAnalytics' database if it exists. 
    All data in the database will be permanently deleted. Proceed with caution 
    and ensure you have proper backups before running this script.
*/

USE master;
GO

-- Drop and recreate the 'DataWarehouseAnalytics' database
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DataWarehouseAnalytics')
BEGIN
    ALTER DATABASE DataWarehouseAnalytics SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DataWarehouseAnalytics;
END;
GO

-- Create the 'DataWarehouseAnalytics' database
CREATE DATABASE DataWarehouseAnalytics;
GO

USE DataWarehouseAnalytics;
GO

-- Create Schemas

CREATE SCHEMA gold;
GO

CREATE TABLE gold.dim_customers(
	customer_key int,
	customer_id int,
	customer_number nvarchar(50),
	first_name nvarchar(50),
	last_name nvarchar(50),
	country nvarchar(50),
	marital_status nvarchar(50),
	gender nvarchar(50),
	birthdate date,
	create_date date
);
GO

CREATE TABLE gold.dim_products(
	product_key int ,
	product_id int ,
	product_number nvarchar(50) ,
	product_name nvarchar(50) ,
	category_id nvarchar(50) ,
	category nvarchar(50) ,
	subcategory nvarchar(50) ,
	maintenance nvarchar(50) ,
	cost int,
	product_line nvarchar(50),
	start_date date 
);
GO

CREATE TABLE gold.fact_sales(
	order_number nvarchar(50),
	product_key int,
	customer_key int,
	order_date date,
	shipping_date date,
	due_date date,
	sales_amount int,
	quantity tinyint,
	price int 
);
GO

TRUNCATE TABLE gold.dim_customers;
GO

BULK INSERT gold.dim_customers
FROm 'C:\Users\hkore\Documents\SQL data Analyst project with baraa\sql-data-analytics-project (1)\sql-data-analytics-project\datasets\flat-files\dim_customers.csv'

WITH (
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	TABLOCK
);
GO

TRUNCATE TABLE gold.dim_products;
GO

BULK INSERT gold.dim_products
FROM'C:\Users\hkore\Documents\SQL data Analyst project with baraa\sql-data-analytics-project (1)\sql-data-analytics-project\datasets\flat-files\dim_products.csv'
WITH (
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	TABLOCK
);
GO

TRUNCATE TABLE gold.fact_sales;
GO

BULK INSERT gold.fact_sales
FROM'C:\Users\hkore\Documents\SQL data Analyst project with baraa\sql-data-analytics-project (1)\sql-data-analytics-project\datasets\flat-files\fact_sales.csv'
WITH (
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	TABLOCK
);
GO


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


------------------------------------------------------------------------

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




use datawarehouseanalytics

/*
Product Report

Purpose:
       - This Report Consolidates key product metrics and behaviors.

Highlights:
      1. Gather essential fileds such as product name, category, subcategory and cost.
	  2. segment PRoduct by Revenue	To identify high performers,mid Range or low Range.
	  3. Aggregate product Level Matrics:
	     - total Orders
		 - Total Sales
		 - Total Quantity Sales
		 - Total Customers(Unique)
		 - Lifespan(in months)
	  4. Calculate Valuable KPI's
	     - Recency (Month since last sales)
		 - Average order Revenue
		 - Average monthly revenue

*/

-- Data verification based on order dates (checking products with multiple order dates)
	select * from (select p.product_name, p.Category, 
	p.subcategory, 
	p.cost as Total_Cost, 
	min(f.order_date) as Min_Order_Date,
	max(f.order_date) as Last_Order_Date,
	Count(distinct f.customer_key) as Total_Customers,
	count(distinct f.order_number) as Total_Orders,
	Sum(f.quantity) as Total_Quantity, 
	sum(f.sales_amount) as TotalSales
	from gold.dim_products p left join 
	gold.fact_sales f on p.product_key = f.product_key
	where f.order_date is Not NULL

	Group by p.product_name, p.Category, 
	p.subcategory, p.cost) t

	where min_Order_Date <> Last_Order_Date

-- Product Report

With Product_Query as (
select p.product_name, p.Category, 
	p.subcategory, 
	sum(p.cost) as Total_Cost, 
	min(f.order_date) as Min_Order_Date,
	max(f.order_date) as Last_Order_Date,
	Count(distinct f.customer_key) as Total_Customers,
	count(distinct f.order_number) as Total_Orders,
	Sum(f.quantity) as Total_Quantity, 
	sum(f.sales_amount) as Total_Sales
from gold.dim_products p left join 
	gold.fact_sales f on p.product_key = f.product_key
where f.order_date is Not NULL
Group by p.product_name, p.Category, 
	p.subcategory)
,Product_Summary as(
select Product_Name, Category, Total_Customers
    Subcategory, Total_Cost, Total_Customers,
	Min_Order_Date, Last_Order_Date,
	Datediff(month, Min_Order_Date, Last_Order_Date) as LifeSpan,
	datediff(month, Last_Order_Date, getdate()) as Recency,
	Total_Orders,
	Total_Quantity,
	Total_Sales
from Product_Query)
select Product_Name, Category, 
    Total_Customers, Subcategory, 
	Total_Cost, Total_Customers,
	Min_Order_Date, Last_Order_Date, 
	LifeSpan, Recency,
Case
    When Total_sales > 50000 then 'High PerFormance'
	when Total_sales >= 10000 then 'Mid PerFormance'
	else 'Low Performance'
End Product_Segment,
Case 
    When Total_Orders = 0 then 0
	else Total_Sales / Total_Orders
End Avg_Order_Revenue,
Case 
    When LifeSpan = 0 then Total_Sales
	else Total_Sales / LifeSpan
End Avg_Monthly_Revenue,
Total_Orders,
	Total_Quantity,
	Total_Sales
from Product_Summary;

With Product_Query as (
select p.product_name, p.Category, 
	p.subcategory, 
	p.cost, 
	min(f.order_date) as Min_Order_Date,
	max(f.order_date) as Last_Order_Date,
	Count(distinct f.customer_key) as Total_Customers,
	count(distinct f.order_number) as Total_Orders,
	Sum(f.quantity) as Total_Quantity, 
	sum(f.sales_amount) as Total_Sales
from gold.dim_products p left join 
	gold.fact_sales f on p.product_key = f.product_key
where f.order_date is Not NULL
Group by p.product_name, p.Category, 
	p.subcategory, p.cost)
,Product_Summary as(
select Product_Name, Category, Total_Customers
    Subcategory, cost, Total_Customers,
	Min_Order_Date, Last_Order_Date,
	Datediff(month, Min_Order_Date, Last_Order_Date) as LifeSpan,
	datediff(month, Last_Order_Date, getdate()) as Recency,
	Total_Orders,
	Total_Quantity,
	Total_Sales
from Product_Query)
select Product_Name, Category, 
    Total_Customers, Subcategory, 
	Cost, Total_Customers,
	Min_Order_Date, Last_Order_Date, 
	LifeSpan, Recency,
Case
    When Total_sales > 50000 then 'High PerFormance'
	when Total_sales >= 10000 then 'Mid PerFormance'
	else 'Low Performance'
End Product_Segment,
Case 
    When Total_Orders = 0 then 0
	else Total_Sales / Total_Orders
End Avg_Order_Revenue,
Case 
    When LifeSpan = 0 then Total_Sales
	else Total_Sales / LifeSpan
End Avg_Monthly_Revenue,
Total_Orders,
	Total_Quantity,
	Total_Sales
from Product_Summary;

































