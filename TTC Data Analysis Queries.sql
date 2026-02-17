USE ttc_delay;

select * from ttc_clean limit 5;

## Q:1 What Causes the Most Total Delay?
SELECT 
    code, description,
    COUNT(*) AS incident_count,
    SUM(min_delay) AS total_delay_minutes,
    ROUND(AVG(min_delay),2) AS avg_delay
FROM ttc
GROUP BY code, description
ORDER BY total_delay_minutes DESC
LIMIT 10;

## Q:2 Which Stations Are Operational Risk Zones?

SELECT 
    station,
    COUNT(*) AS incident_count,
    SUM(min_delay) AS total_delay,
    ROUND(AVG(min_delay),2) AS avg_delay
FROM ttc
GROUP BY station
ORDER BY total_delay DESC
LIMIT 10;

## Q:3 Line-Level Reliability Comparison

SELECT 
    line,
    COUNT(*) AS incidents,
    SUM(min_delay) AS total_delay,
    ROUND(AVG(min_delay),2) AS avg_delay
FROM ttc
GROUP BY line
ORDER BY avg_delay DESC;

## Q:4 Severe Delay Rate by Cause

SELECT code,
COUNT(*) AS incidents,
SUM(CASE WHEN delay_category = 'Severe (30+ min)' THEN 1 ELSE 0 END) AS severe_cases,
ROUND( SUM(CASE WHEN delay_category = 'Severe (30+ min)' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2) AS severe_percentage
FROM ttc
GROUP BY code
ORDER BY severe_percentage DESC;

## Q:5 Create the ranking by delay causes
WITH cause_stats AS (SELECT 
        code,
        SUM(min_delay) AS total_delay
    FROM ttc
    GROUP BY code
)

SELECT code, total_delay,
RANK() OVER (ORDER BY total_delay DESC) AS delay_rank
FROM cause_stats;

## Q:6 What percentage of total incidents result in a delay?

SELECT COUNT(*) AS total_incidents, SUM(CASE WHEN min_delay > 0 THEN 1 ELSE 0 END) AS delayed_incidents,
ROUND(
	SUM(CASE WHEN min_delay > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2) AS delay_rate_percentage
FROM ttc_clean;

## Q:7 What is the average delay during delayed incidents only?

SELECT ROUND(AVG(min_delay),2) AS avg_delay_when_delayed
FROM ttc
WHERE min_delay > 0;

## Q:8 Which causes contribute 80% of total delay impact?

WITH cause_delay AS (SELECT code, SUM(min_delay) AS total_delay
    FROM ttc
    GROUP BY code
),
ranked AS (
    SELECT code, total_delay, SUM(total_delay) OVER (ORDER BY total_delay DESC) / SUM(total_delay) OVER () AS cumulative_pct
    FROM cause_delay
)
SELECT *
FROM ranked
WHERE cumulative_pct <= 0.8;

## Q:9 Which stations have the highest severe delay rate?

SELECT station, COUNT(*) AS incidents,
    SUM(CASE WHEN delay_category = 'Severe (30+ min)' THEN 1 ELSE 0 END) AS severe_cases,
    ROUND(SUM(CASE WHEN delay_category = 'Severe (30+ min)' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2
    ) AS severe_rate
FROM ttc
GROUP BY station
HAVING incidents > 20
ORDER BY severe_rate DESC
LIMIT 10;

## Q:10 Which stations create the most total system delay?
SELECT station, SUM(min_delay) AS total_delay
FROM ttc
GROUP BY station
ORDER BY total_delay DESC
LIMIT 10;

## Q:11 During which hours are delays most severe?

SELECT hour, COUNT(*) AS incidents, ROUND(AVG(min_delay),2) AS avg_delay
FROM ttc
WHERE min_delay > 0
GROUP BY hour
ORDER BY avg_delay DESC;

## Q:12 Monthly trend in average delay

SELECT year, month, ROUND(AVG(min_delay),2) AS avg_delay
FROM ttc
WHERE min_delay > 0
GROUP BY year, month
ORDER BY year, month;

## Q:13 Does service gap severity predict delay severity?

SELECT gap_category, ROUND(AVG(min_delay),2) AS avg_delay,
ROUND(SUM(CASE WHEN delay_category = 'Severe (30+ min)' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS severe_rate
FROM ttc
GROUP BY gap_category
ORDER BY avg_delay DESC;

## Q:14 Rank stations by total delay within each line

SELECT line, station, SUM(min_delay) AS total_delay,
RANK() OVER (PARTITION BY line ORDER BY SUM(min_delay) DESC)
AS station_rank_within_line
FROM ttc
GROUP BY line, station;

## Q:15 What % of total delay is caused by top 5 stations?

WITH station_delay AS (SELECT station, SUM(min_delay) AS total_delay
    FROM ttc
    GROUP BY station
),
ranked AS (SELECT station, total_delay,
        RANK() OVER (ORDER BY total_delay DESC) AS rnk,
        SUM(total_delay) OVER () AS overall_delay
    FROM station_delay
)
SELECT SUM(total_delay) / MAX(overall_delay) * 100 AS top5_contribution
FROM ranked
WHERE rnk <= 5;

