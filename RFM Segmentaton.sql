-- Format Date

SELECT *
FROM retail_sales
LIMIT 5;

UPDATE retail_sales
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

ALTER TABLE retail_sales
MODIFY COLUMN `date` DATE;

-- Random 'customer_id'

ALTER TABLE retail_sales
ADD COLUMN customer_id_new VARCHAR(20);

UPDATE retail_sales
SET customer_id_new = CONCAT('CUST', LPAD(FLOOR(RAND() * 500), 3, '0'));

UPDATE retail_sales
SET customer_id = customer_id_new;

ALTER TABLE retail_sales
DROP COLUMN customer_id_new;

-- Duplicate 'customer_id'

SELECT customer_id, count(*) 
FROM retail_sales
GROUP BY customer_id;

-- RFM Customer Segmentation
 
-- Creating a view to store each customer and their recency score

CREATE VIEW r_score_view AS
(
	WITH date_rank AS   -- Selecting the lastest records for each customer
	(
	SELECT 
		customer_id,
		`date`,
		ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY `date` DESC) AS `rank`
	FROM retail_sales
	),
		recency_1 AS    -- Subtracting max date from the latest date each customer 
	(
	SELECT
		customer_id,
		DATEDIFF('2024-01-01', `date`) AS recency
	FROM date_rank
	WHERE `rank` = 1
	),
		recency_2 AS    -- Grouping the recency into 4 quartiles
	(
	SELECT
		customer_id,
		recency,
		NTILE(4) OVER (ORDER BY recency DESC) AS r_score
	FROM recency_1
	)
	SELECT *
	FROM recency_2
	ORDER BY customer_id
);

SELECT * FROM r_score_view;

-- Creating a view to store each customer and their frequency score

CREATE VIEW f_score_view AS
(
	WITH frequency AS   	    -- Aggregating the number of transactions per customer
	(
	SELECT
		customer_id,
		COUNT(transaction_id) AS frequency
	FROM retail_sales
	GROUP BY customer_id
	),
		frequency_quartile AS 	-- Grouping the frequency into 4 quartiles
	(
	SELECT
		customer_id,
		frequency,
		NTILE(4) OVER (ORDER BY frequency) AS f_score 
	FROM frequency
	)
	SELECT * 
	FROM frequency_quartile 
	ORDER BY customer_id
);

SELECT * FROM f_score_view;

-- Creating a view to store each customer and their monetary score

CREATE VIEW m_score_view AS 
(
	WITH total_spend AS 		-- Aggregating each customer spend
    (
    SELECT
		customer_id,
        SUM(total_amount) AS monetary
	FROM retail_sales
    GROUP BY customer_id
	),
		monetary_quartile AS 	-- -- Grouping the monetory into 4 quartiles
	(
	SELECT 	
		customer_id,
        monetary,
        NTILE(4) OVER (ORDER BY monetary) AS m_score
	FROM total_spend
    )
        
	SELECT * 
    FROM monetary_quartile 
    ORDER BY customer_id
);

SELECT * FROM m_score_view;

-- Creating the RFM_score table ( JOIN 3 Table )

CREATE VIEW rfm_score AS 
(
	WITH joined_views AS	
    (
    SELECT 
		r.customer_id,
		r.r_score,    
		f.f_score,      
		m.m_score 
    FROM r_score_view AS r
    JOIN f_score_view AS f	
		ON r.customer_id = f.customer_id
	JOIN m_score_view AS m
		ON f.customer_id = m.customer_id
    ),
		rfm_scoring AS 
	(
    SELECT *,
		CONCAT(r_score, f_score, m_score) AS rfm_score
    FROM joined_views
	)
    SELECT * 
    FROM rfm_scoring
);

SELECT * FROM rfm_score;
SELECT COUNT(*) AS total_rows FROM rfm_score;


-- Define cluster name

CREATE VIEW cluster_name AS 
(
	WITH cluster AS
    (
    SELECT	
		customer_id,
        r_score AS R,
        f_score AS F,
        m_score AS M
	FROM rfm_score
	)	
    SELECT customer_id,
		CASE
			WHEN (F * M > 10 AND F * M <= 16 AND R > 3.4 AND R <= 4)    THEN 'Champion'
			WHEN (F * M > 10 AND F * M <= 16 AND R > 2.2 AND R <= 3.4)  THEN 'Loyal'
			WHEN (F * M > 10 AND F * M <= 16 AND R >= 1 AND R <= 2.2)   THEN 'Cannot Lose Them'
			WHEN (F * M > 6 AND F * M <= 10 AND R > 2.8 AND R <= 4)     THEN 'Potential Loyalist'
			WHEN (F * M > 6 AND F * M <= 10 AND R > 2.2 AND R <= 2.8)   THEN 'Need Attention'
			WHEN (F * M > 6 AND F * M <= 10 AND R >= 1 AND R <= 2.2)    THEN 'At Risk'
			WHEN (F * M >= 1 AND F * M <= 6 AND R > 3.4 AND R <= 4)     THEN 'New Customer'
			WHEN (F * M >= 1 AND F * M <= 6 AND R > 2.8 AND R <= 3.4)   THEN 'Promising'
			WHEN (F * M >= 1 AND F * M <= 6 AND R > 2.2 AND R <= 2.8)   THEN 'About to Sleep'
			ELSE 'Hibernating'
		END AS customer_segment
	FROM cluster
);

SELECT * FROM cluster_name;

-- JOIN all columms

SELECT 
	ret.*,
    rfms.r_score,
    rfms.f_score,
    rfms.m_score,
    rfms.rfm_score,
    cls.customer_segment
FROM retail_sales AS ret
JOIN rfm_score AS rfms
	ON ret.customer_id = rfms.customer_id
JOIN cluster_name AS cls
	ON rfms.customer_id = cls.customer_id
ORDER BY ret.transaction_id;



    








	











