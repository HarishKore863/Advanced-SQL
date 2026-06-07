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
