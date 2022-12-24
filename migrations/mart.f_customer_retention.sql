-- drop table if exists mart.f_customer_retention;
create table mart.f_customer_retention (
	 new_customers_count integer 
	,returning_customers_count integer
	,refunded_customer_count integer
	,period_name varchar(20) 
	,period_id smallint not null
	,item_id integer
	,new_customers_revenue numeric(14, 2)
	,returning_customers_revenue numeric(14, 2)
	,customers_refunded integer
	,primary key (period_id, item_id)
);