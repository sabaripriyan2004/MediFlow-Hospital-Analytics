#Patient Waiting-Time Analysis
SELECT
    COUNT(*) AS total_waiting_events
FROM patient_wait_events;


#What are the average, median and maximum waiting times for each waiting stage

WITH ranked_waits AS (
    SELECT
        wait_stage,
        wait_minutes,
        ROW_NUMBER() OVER (
            PARTITION BY wait_stage
            ORDER BY wait_minutes
        ) AS row_num,
        COUNT(*) OVER (
            PARTITION BY wait_stage
        ) AS total_rows
    FROM patient_wait_events
    WHERE wait_minutes IS NOT NULL
)
SELECT
    wait_stage,
    ROUND(AVG(wait_minutes), 2) AS average_wait_minutes,
    MAX(wait_minutes) AS maximum_wait_minutes,
    ROUND(
        AVG(
            CASE
                WHEN row_num IN (
                    FLOOR((total_rows + 1) / 2),
                    FLOOR((total_rows + 2) / 2)
                )
                THEN wait_minutes
            END
        ), 2
    ) AS median_wait_minutes
FROM ranked_waits
GROUP BY wait_stage;


#Which waiting stages have the highest target-breach percentage
SELECT
    wait_stage,
    COUNT(*) AS total_events,
    SUM(
        CASE WHEN wait_minutes > target_minutes
             THEN 1 ELSE 0 END
    ) AS breached_events,
    ROUND(
        100.0 * SUM(
            CASE WHEN wait_minutes > target_minutes
                 THEN 1 ELSE 0 END
        ) / COUNT(*), 2
    ) AS breach_percentage
FROM patient_wait_events
WHERE wait_minutes IS NOT NULL
  AND target_minutes IS NOT NULL
GROUP BY wait_stage
ORDER BY breach_percentage DESC;

#Which departments contribute the highest total excess waiting hours
SELECT
    d.department_name,
    COUNT(*) AS waiting_events,
    ROUND(
        SUM(
            GREATEST(w.wait_minutes - w.target_minutes, 0)
        ) / 60, 2
    ) AS excess_waiting_hours
FROM patient_wait_events w
JOIN encounters e
    ON w.encounter_id = e.encounter_id
JOIN departments d
    ON e.department_id = d.department_id
GROUP BY d.department_name
ORDER BY excess_waiting_hours DESC;

What are the top five encounters with the longest waiting times
SELECT
    encounter_id,
    wait_stage,
    wait_minutes,
    target_minutes,
    ROUND(
        GREATEST(wait_minutes - target_minutes, 0), 2
    ) AS excess_wait_minutes
FROM patient_wait_events
WHERE wait_minutes IS NOT NULL
ORDER BY wait_minutes DESC
LIMIT 5;