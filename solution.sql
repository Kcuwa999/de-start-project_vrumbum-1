-- Этап 1. Создание и заполнение БД
CREATE SCHEMA IF NOT EXISTS raw_data;

CREATE TABLE raw_data.sales (
    id SMALLINT PRIMARY KEY,
    auto TEXT,
    gasoline_consumption FLOAT null,
    price NUMERIC(9, 2) NOT NULL, 
    date DATE NOT NULL,
    person_name VARCHAR(255) NOT NULL,
    phone VARCHAR(25) NOT NULL, 
    discount FLOAT, 
    brand_origin VARCHAR(255) 
);

COPY raw_data.sales(id, auto, gasoline_consumption, price, date, person_name, phone, discount, brand_origin) 
FROM 'C:/Car/cars.csv' 
CSV HEADER NULL AS 'null';


CREATE SCHEMA IF NOT EXISTS car_shop;

-- Таблица для брендов
CREATE TABLE car_shop.brands (
    brand_id SERIAL PRIMARY KEY,
    brand_name VARCHAR(255) NOT null,
    brand_origin VARCHAR(255) null
);
-- Таблица для клиентов
CREATE TABLE car_shop.clients (
    client_id SERIAL PRIMARY KEY,
    person_name VARCHAR(255) NOT NULL,
    phone VARCHAR(25) UNIQUE NOT NULL
);
-- Таблица для цветов
CREATE TABLE car_shop.colors (
    color_id SERIAL PRIMARY KEY,
    color_name VARCHAR(50) NOT NULL
);
CREATE TABLE car_shop.models (
    model_id SERIAL PRIMARY KEY,
    model_name VARCHAR(50) NOT NULL
);
-- Промежуточная таблица для связи между автомобилями и цветами (многие ко многим)
CREATE TABLE car_shop.color_brand_model (
	id SERIAL PRIMARY key,
    model_id INT REFERENCES car_shop.models(model_id),
    brand_id INT REFERENCES car_shop.brands(brand_id),
    color_id INT REFERENCES car_shop.colors(color_id)
);


CREATE TABLE car_shop.cars (
    car_id SERIAL PRIMARY KEY,
    model_id INT REFERENCES car_shop.models(model_id), 
    color_id INT REFERENCES car_shop.color_brand_model(id), 
    brand_id INT REFERENCES car_shop.brands(brand_id),
    client_id INT REFERENCES car_shop.clients(client_id),
    date DATE,
    discount FLOAT,
    gasoline_consumption FLOAT,
    price NUMERIC(9, 2) NOT NULL
);


--brands
INSERT INTO car_shop.brands (brand_name,brand_origin )
SELECT DISTINCT 
SUBSTRING(auto FROM 1 FOR POSITION(' ' IN auto) - 1) AS brand_name,
brand_origin
FROM raw_data.sales

--clients
INSERT INTO car_shop.clients (person_name, phone)
SELECT DISTINCT person_name, phone
FROM raw_data.sales;
--colors
INSERT INTO car_shop.colors (color_name)
SELECT DISTINCT SUBSTRING(auto FROM POSITION(', ' IN auto)+2 for LENGTH(auto)  - 1) AS color_name
FROM raw_data.sales
WHERE SUBSTRING(auto FROM POSITION(', ' IN auto)+2 for LENGTH(auto)  - 1) IS NOT NULL;
--models
INSERT INTO car_shop.models (model_name)
SELECT DISTINCT SPLIT_PART(SUBSTRING(auto FROM POSITION(' ' IN auto) + 1), ',', 1) AS model_name
FROM raw_data.sales
WHERE (SUBSTRING(auto FROM POSITION(' ' IN auto) + 1), ',', 1) IS NOT NULL;


INSERT INTO car_shop.color_brand_model (model_id, brand_id, color_id)
select distinct 
model_id,
brand_id,
color_id
from 
raw_data.sales s 
left join car_shop.models m on m.model_name = SPLIT_PART(SUBSTRING(auto FROM POSITION(' ' IN auto) + 1), ',', 1)
left join car_shop.brands b on b.brand_name = SUBSTRING(auto FROM 1 FOR POSITION(' ' IN auto) - 1)
left join car_shop.colors c on c.color_name = SUBSTRING(auto FROM POSITION(', ' IN auto)+2 for LENGTH(auto)  - 1) 



INSERT INTO car_shop.cars (model_id,color_id,  brand_id ,client_id ,date ,discount, gasoline_consumption ,price )
select 
m.model_id,
cbm.id,  
b.brand_id ,
c.client_id ,
date,
discount, 
gasoline_consumption ,
price 
from
raw_data.sales s
left join car_shop.models m on m.model_name = SPLIT_PART(SUBSTRING(auto FROM POSITION(' ' IN auto) + 1), ',', 1)
left join car_shop.brands b on b.brand_name = SUBSTRING(auto FROM 1 FOR POSITION(' ' IN auto) - 1) 
left join car_shop.clients c on c.person_name = s.person_name and c.phone  = s.phone 
left join 
(
	select 
	id,
	m.model_name,
	b.brand_name,
	c.color_name
	from 
		car_shop.color_brand_model cbm left join 
		car_shop.models m on cbm.model_id = m.model_id left join 
		car_shop.brands b on cbm.brand_id = b.brand_id left join 
		car_shop.colors c on cbm.color_id = c.color_id	
		
) cbm on cbm.model_name = SPLIT_PART(SUBSTRING(auto FROM POSITION(' ' IN auto) + 1), ',', 1) and 
cbm.brand_name = SUBSTRING(auto FROM 1 FOR POSITION(' ' IN auto) - 1)  and 
cbm.color_name = SUBSTRING(auto FROM POSITION(', ' IN auto)+2 for LENGTH(auto)  - 1) 


-- Этап 2. Создание выборок

---- Задание 1. Напишите запрос, который выведет процент моделей машин, у которых нет параметра `gasoline_consumption`.

select 	
	(sum(not_gasoline_consumption)/count(not_gasoline_consumption))*100 as nulls_percentage_gasoline_consumption
from (
SELECT distinct
	model_name,
	case when gasoline_consumption is null THEN 1.0 else 0 end  as not_gasoline_consumption
FROM 
    car_shop.cars c join 
    car_shop.models m on c.model_id = m.model_id
)

---- Задание 2. Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.

SELECT 
    b.brand_name,
    EXTRACT(YEAR FROM c.date) AS year,
    ROUND(AVG(c.price * (1 - COALESCE(NULL, 0))), 2) AS price_avg
FROM 
    car_shop.cars c
JOIN 
    car_shop.brands b ON c.brand_id = b.brand_id
GROUP BY 
    b.brand_name, 
    EXTRACT(YEAR FROM c.date)
ORDER BY 
    b.brand_name, 
    year;


---- Задание 3. Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.

SELECT 
    EXTRACT(MONTH FROM date) AS month,
    EXTRACT(YEAR FROM date) AS year,
    ROUND(CAST(AVG(price * discount) AS numeric), 2) AS price_avg
FROM 
    car_shop.cars
WHERE 
    EXTRACT(YEAR FROM date) = 2022
GROUP BY 
    EXTRACT(MONTH FROM date), EXTRACT(YEAR FROM date)
ORDER BY 
    month;


---- Задание 4. Напишите запрос, который выведет список купленных машин у каждого пользователя.

SELECT 
    person_name AS person,
    STRING_AGG(b.brand_name || ' ' || m.model_name, ', ') AS cars
FROM 
    car_shop.clients cl
JOIN
    car_shop.cars c ON cl.client_id  = c.client_id
JOIN 
    car_shop.brands b ON c.brand_id = b.brand_id
JOIN 
    car_shop.models m ON c.model_id= m.model_id
  
GROUP BY 
    person_name
ORDER BY 
    person_name;

---- Задание 5. Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки.

SELECT 
    b.brand_origin,
    MAX(c.price) AS price_max,
    MIN(c.price) AS price_min
FROM 
    car_shop.cars c
JOIN 
    car_shop.brands b ON c.brand_id = b.brand_id
JOIN 
    car_shop.models m ON c.model_id= m.model_id
GROUP BY 
    brand_origin
ORDER BY 
    brand_origin;


---- Задание 6. Напишите запрос, который покажет количество всех пользователей из США.

SELECT COUNT(DISTINCT cl.person_name) AS persons_from_usa_count
FROM car_shop.cars c
join car_shop.clients cl on c.client_id = cl.client_id
WHERE cl.phone LIKE '+1%';
