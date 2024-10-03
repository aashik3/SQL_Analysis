--total quantity;

select sum(qty) as total_quantity

/*What is the total generated revenue for all products
before discounts?*/

select sum(s.qty*s.price) tot_revenue 
from sales s 
join Product_details p on s.prod_id=p.product_id;

/*What was the total discount amount for all products?*/

select round(sum(qtysys_configsys_config*price*discount/100),1) as overall_discount 
from sales ;

/*How many unique transactions were there?*/

select count(distinct txn_id) from sales ;

/*What is the average unique products
purchased in each transaction?*/

select avg(product_count) as avg_unique_product 
from
	(select txn_id,count(distinct prod_id) as product_count
    from sales
	group by txn_id) x ;
    
/*What are the 25th, 50th and 75th percentile
values for the revenue per transaction?*/    
    
with total_revenue as (
	 select sum(price*qty - (price*qty*discount/100)) as tot_rev
     from sales
     group by txn_id),
     percentile as (
     select tot_rev , cume_dist() over(order by tot_rev) as per
     from total_revenue
     )
select sum(case when per<=0.25 then tot_rev end)as 25th,
				sum(case when per<=0.50 then tot_rev end ) as 50th,
                sum(case when per <=0.75 then tot_rev end) as 75th
from percentile;

/*What is the average discount value
per transaction?*/

select avg(per_day_discount) as disc_value_per_transaction
from 
	(select sum(price*qty*discount/100) as per_day_discount from sales
	group by txn_id)x;

/*What is the percentage split of all transactions
for members vs non-members?*/

with total_members as  ( select count(txn_id)as total_count from sales),
	for_members as ( select count(txn_id)as total_count from sales
					where member = 't'),
     non_members as (select count(txn_id)as total_count from sales
					where member = 'f')
select (f.total_count*100/t.total_count) as member_percentage ,
	(n.total_count*100/t.total_count) as non_member_percentage
from for_members f ,non_members n ,total_members t;

                       /*method2*/
SELECT 
    member,
    COUNT(txn_id) * 100 / sum(count(*))  over () AS percentage_split
FROM sales
GROUP BY member;

/*What is the average revenue for member transactions
and non-member transactions?*/

with total_revenue as (
	 select txn_id,member,sum(price*qty - (price*qty*discount/100)) as tot_rev,
     count(*) as tot_mem
     from sales
     group by txn_id ,member)

select member, avg(tot_rev) as avg_revenue from total_revenue
group by member;

/*What are the top 3 products by total revenue
before discount?*/

select s.prod_id,
	p.product_name , 
	sum(s.price*s.qty) as revenue 
    from sales s 
    join product_details p
on p.product_id=s.prod_id
group by p.product_name,s.prod_id
order by revenue desc
limit 3;

/*What is the total quantity, revenue and discount
for each segment?*/

select 
	p.segment_name,sum(s.qty) as tot_qty,
    sum(s.price*s.qty - (s.price*s.qty*s.discount/100)) as tot_rev,
	sum(s.price*s.qty*s.discount/100) as dis
from sales s 
join product_details p
on p.product_id=s.prod_id
group by p.segment_name;

/*What is the top selling product for each segment?*/
with cte as (
	select p.segment_name , p.product_name , sum(s.qty) as quantity ,
		row_number() over(partition by p.segment_name order by sum(s.qty) desc ) as rn
	from sales s 
	join product_details p
	on p.product_id=s.prod_id
	group by p.segment_name , p.product_name
	order by p.segment_name)
select segment_name , product_name , quantity from cte where cte.rn=1;

/*What is the total quantity, revenue and discount
for each category?*/

select 
	p.category_name,
    sum(s.qty) as tot_qty,
    sum(s.price*s.qty - (s.price*s.qty*s.discount/100)) as tot_rev,
	sum(s.price*s.qty*s.discount/100) as dis
from sales s 
join product_details p
on p.product_id=s.prod_id
group by p.category_name;

/*What is the top selling product for each category?*/

with cte2 as (
	select p.category_name, p.product_name,
		sum(s.qty) , 
        row_number() over (partition by p.category_name order by sum(s.qty) desc) as rn
	from product_details p 
	join sales s on p.product_id=s.prod_id
	group by p.category_name , p.product_name
)
select * from cte2 where rn=1;

/*What is the percentage split of revenue by product
for each segment?*/

select 
	p.segment_name,p.product_name, 
    sum(s.price*s.qty - (s.price*s.qty*s.discount/100)) as tot_rev,
    round(sum(s.price*s.qty - (s.price*s.qty*s.discount/100)) *100 /
     sum(sum(s.price*s.qty - (s.price*s.qty*s.discount/100)))
     over(partition by p.segment_name),1) as percentage_split
from sales s 
join product_details p
on p.product_id=s.prod_id
group by p.segment_name ,p.product_name
order by p.segment_name;

/*What is the percentage split of revenue by segment
for each category?*/

select 
	p.segment_name ,
	p.category_name ,
	sum(s.qty*s.price) as revenue ,
	sum(s.qty*s.price)*100 /
		sum(sum(s.qty*s.price)) over (partition by p.category_name) as 
			percent_by_segment_for_category
from  sales s 
join 
product_details p on p.product_id = s.prod_id
group by  p.category_name,p.segment_name  ;

/*What is the percentage split of total revenue
by category?*/

select 
	p.category_name,
	sum(s.qty*s.price) as revenue ,
	round(sum(s.qty*s.price)*100 /
		sum(sum(s.qty*s.price)) over (),1) as percent_by_category
from  sales s 
join 
product_details p on p.product_id = s.prod_id
group by  p.category_name;

/*What is the total transaction “penetration” for each
product? */

SELECT 
    p.product_id,
    p.product_name,
    COUNT(DISTINCT s.txn_id) * 100 / 
		(SELECT COUNT(DISTINCT txn_id) FROM sales
        where qty >= 1 ) AS transaction_penetration
FROM sales s
JOIN product_details p ON s.prod_id = p.product_id
GROUP BY p.product_id, p.product_name;

/*What is the most common combination of at least 1 quantity
of any 3 products in a 1 single transaction?*/

with TransactionProducts as(select s.txn_id , group_concat(distinct p.product_name order by p.product_name) as products
from
sales s join product_details p
on s.prod_id=p.product_id
group by s.txn_id),

ProductCombinations AS (
    SELECT
        txn_id,
        SUBSTRING_INDEX(SUBSTRING_INDEX(products, ',', 1), ',', -1) AS product1,
        SUBSTRING_INDEX(SUBSTRING_INDEX(products, ',', 2), ',', -1) AS product2,
        SUBSTRING_INDEX(SUBSTRING_INDEX(products, ',', 3), ',', -1) AS product3
    FROM TransactionProducts
    WHERE LENGTH(products) - LENGTH(REPLACE(products, ',', '')) + 1 >= 3
)
select count(*) from TransactionProducts;

















































    
    


















