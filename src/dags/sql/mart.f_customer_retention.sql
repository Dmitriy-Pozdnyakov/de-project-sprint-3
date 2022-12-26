with week_period_id as (
	select *, row_number() over(order by year_actual, week_of_year) as period_id
	from (select distinct year_actual, week_of_year from mart.d_calendar)t
	order by period_id
),
get_period_id as (
	select year_actual, week_of_year 
	from mart.d_calendar 
	where date_actual = (date '{{ds}}' - integer %(ds_date_dif)s)
)
delete from mart.f_customer_retention
where period_id in (
					select period_id 
					from week_period_id t1
					inner join get_period_id t2
						on t1.year_actual = t2.year_actual
						and t1.week_of_year = t2.week_of_year);

with week_period_id as (
	select *, row_number() over(order by year_actual, week_of_year) as period_id
	from (select distinct year_actual, week_of_year from mart.d_calendar)t
	order by period_id
),
get_period_id as (
	select year_actual, week_of_year 
	from mart.d_calendar 
	where date_actual = (date '{{ds}}' - integer %(ds_date_dif)s)
),
days_weekly_period_id as (
	select 
		dc.date_id
		,wpi.period_id
		,'weekly' as period_name
	from mart.d_calendar dc 
	left join week_period_id wpi
		on dc.year_actual = wpi.year_actual
		and dc.week_of_year = wpi.week_of_year 
	where wpi.period_id in (
					select period_id 
					from week_period_id t1
					inner join get_period_id t2
						on t1.year_actual = t2.year_actual
						and t1.week_of_year = t2.week_of_year)
),
days_weekly_period_id_f as (
	select fs2.* , dwpi.period_id, dwpi.period_name
	from mart.f_sales fs2 
	inner join days_weekly_period_id dwpi
		on fs2.date_id = dwpi.date_id
), 
refunded as 	
	(select 
		count(distinct case when payment_amount <0 then customer_id end) as refunded_customer_count
		,period_name
		,period_id
		,item_id
		,sum(case when payment_amount <0 then payment_amount else 0 end) as customers_refunded
	from days_weekly_period_id_f
	group by period_id, period_name, item_id
	),
customers_item_count_w as (
	select 
		max(rn) as customers_item_count_w
		,customer_id
		,period_id 
		,item_id
		from (
			select 
				row_number() over(partition by customer_id, period_id,item_id ORDER BY customer_id)  as rn
				,period_name
				,period_id
				,item_id
				,customer_id
				,city_id
				,date_id
			from days_weekly_period_id_f)t
	group by customer_id, period_id, item_id
),
customers_type_count_w as (
    select period_id,item_id 
        ,sum(case when customers_item_count_w =1 then 1 else 0 end) as new_customers_count 
        ,sum(case when customers_item_count_w >1 then 1 else 0 end) as returning_customers_count 
        ,sum(case when customers_item_count_w =1 then payment_amount else 0 end) as new_customers_revenue  
        ,sum(case when customers_item_count_w >1 then payment_amount else 0 end) as returning_customers_revenue  
    from (
    	select 
    		t1.* 
    		,t2.payment_amount
    	from customers_item_count_w t1
    	left join days_weekly_period_id_f t2
    		on t1.customer_id = t2.customer_id
			and t1.period_id = t2.period_id
			and t1.item_id = t2.item_id 
    	)t
    group by period_id,item_id
)
insert into mart.f_customer_retention
select 
	ctc.new_customers_count
	,returning_customers_count 
	,r.refunded_customer_count 
	,r.period_name 
	,r.period_id 
	,r.item_id 
	,ctc.new_customers_revenue 
	,ctc.returning_customers_revenue 
	,r.customers_refunded 
from refunded r
left join customers_type_count_w ctc
	on r.period_id = ctc.period_id
	and r.item_id = ctc.item_id;

