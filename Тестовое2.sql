-- Таблица Orders – данные о заказах:
-- 1.	OrderID – идентификатор заказа, целое типа int.
-- 2.	CustomerID – идентификатор клиента, целое типа int.
-- 3.	OrderDate – дата оформления заказа, тип nchar(8), формат записи - "YYYYMMDD".
-- 4.	OrderState – состояние заказа, строка типа nvarchar(9).
--  Возможные значения: "Fulfilled" (исполнен) и "Cancelled" (отменен).
-- 5.	DeliveryDays – количество дней от оформления заказа до получения его клиентом, целое типа tinyint.
--  Значение 0 означает получение в день оформления, 1 – на следующий день и т.д. Для отмененных заказов – NULL.
--  Датой покупки считается дата получения заказа клиентом.
-- Первичный ключ таблицы – поле OrderID.
 
-- Таблица Order_List – состав заказов:
-- 1.	OrderID – идентификатор заказа, целое типа int.
-- 2.	SKU – идентификатор товара, целое типа int.
-- 3.	Quantity – количество заказанного товара, целое типа tinyint.
-- 4.	Price – стоимость одной единицы товара, целое типа int.
 
-- Первичный ключ таблицы – комбинация полей OrderID и SKU.
 
 
-- Таблица Customers – справочник клиентов.
-- 1.	CustomerID – идентификатор клиента, целое типа int.
-- 2.	CityID – идентификатор города проживания клиента, целое типа int.
--  Данные о городе клиента могут отсутствовать; в этом случае считать городом проживания клиента CityID = 1.
-- Первичный ключ таблицы – поле CustomerID.
 
-- Таблица City_Region – справочник регионов:
-- 1.	CityID – идентификатор города, целое типа int.
-- 2.	Region – название региона, строка типа nvarchar(7).
--  Возможные значения: "Central", "North", "South", "East", "West".
-- Первичный ключ таблицы – поле CityID.



-- 1. Написать запрос, который показывает количество выполненных заказов с X SKU в заказе (шт.)
select UnqSKUs, count(OrderID) as OrdersCnt
from (
  select distinct l.OrderID, count(l.SKU) UnqSKUs
  from test_sql.Order_list l
  inner join test_sql.Orders o
    on l.OrderID = o.OrderID
      and OrderState='Fulfilled'
  group by 1
)
group by 1
order by 1


-- 2. Написать SQL-запрос, выводящий среднюю стоимость покупки (завершенный заказ) за все время клиентов из центрального региона ("Central"), совершивших и получивших первую покупку в январе 2018 года. Результаты предоставить в разбивке по городам.
with cities as ( -- клиенты из центрального региона
  select CustomerID, CityID
  from (
    select CustomerID, coalesce(CityID, '1') as CityID_notnull
    from test_sql.Customers
  ) c
  left join test_sql.City_Region r
  on c.CityID_notnull = r.CityID
  where Region = 'Central'
),
customers18 as ( -- совершившие и получившие первую покупку в январе 2018 года
  select
    CustomerID,
    min(parse_date('%Y%m%d', OrderDate)) as FirstOrderDate, -- дата первого заказа
    min(DATE_ADD(parse_date('%Y%m%d', OrderDate), INTERVAL CAST(DeliveryDays as INT64) DAY)) as FirstDeliveryDate -- дата доставки первого заказа
  from test_sql.Orders o
  where OrderState = 'Fulfilled'
  group by 1
  having min(parse_date('%Y%m%d', OrderDate))
    between parse_date('%Y%m%d', '20180101') and parse_date('%Y%m%d', '20180131')
  and min(DATE_ADD(parse_date('%Y%m%d', OrderDate), INTERVAL CAST(DeliveryDays as INT64) DAY))
    between parse_date('%Y%m%d', '20180101') and parse_date('%Y%m%d', '20180131')
),
AllOrdersCentralCustomers18 as ( -- заказы за все время клиентов из центрального региона, совершивших и получивших первую покупку в январе 2018 года
  select distinct OrderID, o.CustomerID, ci.CityID
  from test_sql.Orders o
  inner join cities ci
    on o.CustomerID=ci.CustomerID
  inner join customers18 cu
    on o.CustomerID=cu.CustomerID
  where OrderState='Fulfilled'
)
select a.CityID, round(avg(price)) as AvgPurchase -- средний чек по городам
from test_sql.Order_list l
inner join AllOrdersCentralCustomers18 a
  on l.OrderID = a.OrderID
group by 1
order by 1


-- 3. По месяцам вывести топ-3 самых покупаемых (по количеству единиц товаров в выкупленных заказах) SKU. Если у нескольких товаров одинаковое количество проданных единиц, то выводить все такие товары.
with CTE as (
  select distinct SKU,
    extract(month from parse_date('%Y%m%d', OrderDate)) as Month,
    sum(Quantity) over (partition by SKU, extract(month from parse_date('%Y%m%d', OrderDate))) as Total
  from test_sql.Order_list l
  inner join test_sql.Orders o
    on l.OrderID = o.OrderID
      and o.OrderState="Fulfilled"
)
select Month, SKU
from
(
  select Month, SKU, Total, dense_rank() over (partition by Month order by Total desc) as ranked
  from CTE
)
where ranked <=3
order by Month, ranked, SKU
