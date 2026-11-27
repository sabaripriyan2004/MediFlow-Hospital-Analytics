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

Department Performance Analysis

Which departments handle the highest number of patient encounters
SELECT
    d.department_name,
    COUNT(e.encounter_id) AS total_encounters
FROM departments d
LEFT JOIN encounters e
    ON d.department_id = e.department_id
GROUP BY d.department_name
ORDER BY total_encounters DESC;

What is the average waiting time and target-breach rate for each department
SELECT
    d.department_name,
    COUNT(*) AS total_waiting_events,
    ROUND(AVG(w.wait_minutes), 2) AS average_wait_minutes,
    SUM(
        CASE WHEN w.wait_minutes > w.target_minutes
             THEN 1 ELSE 0 END
    ) AS breached_events,
    ROUND(
        100.0 * SUM(
            CASE WHEN w.wait_minutes > w.target_minutes
                 THEN 1 ELSE 0 END
        ) / COUNT(*), 2
    ) AS breach_percentage
FROM patient_wait_events w
JOIN encounters e
    ON w.encounter_id = e.encounter_id
JOIN departments d
    ON e.department_id = d.department_id
GROUP BY d.department_name
ORDER BY breach_percentage DESC;


Which department has the highest total excess waiting hours
SELECT
    d.department_name,
    ROUND(
        SUM(
            GREATEST(w.wait_minutes - w.target_minutes, 0)
        ) / 60, 2
    ) AS total_excess_hours
FROM patient_wait_events w
JOIN encounters e
    ON w.encounter_id = e.encounter_id
JOIN departments d
    ON e.department_id = d.department_id
GROUP BY d.department_name
ORDER BY total_excess_hours DESC;

What are the top three waiting stages contributing to delays in each department
WITH department_stage AS (
    SELECT
        d.department_name,
        w.wait_stage,
        COUNT(*) AS total_events,
        ROUND(
            SUM(
                GREATEST(w.wait_minutes - w.target_minutes, 0)
            ) / 60, 2
        ) AS excess_hours
    FROM patient_wait_events w
    JOIN encounters e
        ON w.encounter_id = e.encounter_id
    JOIN departments d
        ON e.department_id = d.department_id
    GROUP BY d.department_name, w.wait_stage
),
ranked_stages AS (
    SELECT
        *,
        DENSE_RANK() OVER (
            PARTITION BY department_name
            ORDER BY excess_hours DESC
        ) AS stage_rank
    FROM department_stage
)
SELECT *
FROM ranked_stages
WHERE stage_rank <= 3
ORDER BY department_name, stage_rank;

How does department performance differ between OP, IP and Emergency encounters
SELECT
    d.department_name,
    e.encounter_type,
    COUNT(*) AS total_waiting_events,
    ROUND(AVG(w.wait_minutes), 2) AS average_wait_minutes,
    ROUND(
        100.0 * SUM(
            CASE WHEN w.wait_minutes > w.target_minutes
                 THEN 1 ELSE 0 END
        ) / COUNT(*), 2
    ) AS breach_percentage
FROM patient_wait_events w
JOIN encounters e
    ON w.encounter_id = e.encounter_id
JOIN departments d
    ON e.department_id = d.department_id
GROUP BY d.department_name, e.encounter_type
ORDER BY d.department_name, e.encounter_type;

Peak-Hour Congestion Analysis
SELECT
    HOUR(arrival_time) AS arrival_hour,
    COUNT(*) AS total_arrivals
FROM encounters
WHERE arrival_time IS NOT NULL
GROUP BY HOUR(arrival_time)
ORDER BY total_arrivals DESC;

What is the average waiting time for each hour of the day

SELECT
    HOUR(wait_start_time) AS waiting_hour,
    COUNT(*) AS total_waiting_events,
    ROUND(AVG(wait_minutes), 2) AS average_wait_minutes
FROM patient_wait_events
WHERE wait_start_time IS NOT NULL
GROUP BY HOUR(wait_start_time)
ORDER BY waiting_hour;


Which hours have the highest waiting-time target-breach percentage

SELECT
    HOUR(wait_start_time) AS waiting_hour,
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
WHERE wait_start_time IS NOT NULL
GROUP BY HOUR(wait_start_time)
ORDER BY breach_percentage DESC;


Which departments contribute the most excess waiting hours during peak hours

SELECT
    d.department_name,
    HOUR(w.wait_start_time) AS waiting_hour,
    COUNT(*) AS total_events,
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
WHERE HOUR(w.wait_start_time) BETWEEN 16 AND 20
GROUP BY d.department_name, HOUR(w.wait_start_time)
ORDER BY excess_waiting_hours DESC;


Is higher patient arrival volume associated with higher average waiting time

WITH hourly_arrivals AS (
    SELECT
        HOUR(arrival_time) AS hour_of_day,
        COUNT(*) AS patient_arrivals
    FROM encounters
    WHERE arrival_time IS NOT NULL
    GROUP BY HOUR(arrival_time)
),
hourly_waits AS (
    SELECT
        HOUR(wait_start_time) AS hour_of_day,
        COUNT(*) AS waiting_events,
        AVG(wait_minutes) AS average_wait_minutes
    FROM patient_wait_events
    WHERE wait_start_time IS NOT NULL
    GROUP BY HOUR(wait_start_time)
)
SELECT
    a.hour_of_day,
    a.patient_arrivals,
    w.waiting_events,
    ROUND(w.average_wait_minutes, 2) AS average_wait_minutes
FROM hourly_arrivals a
JOIN hourly_waits w
    ON a.hour_of_day = w.hour_of_day
ORDER BY a.hour_of_day;

Discharge Delay Analysis

What is the average discharge delay across valid encounters

SELECT
    COUNT(*) AS valid_discharge_encounters,
    ROUND(
        AVG(
            TIMESTAMPDIFF(
                MINUTE,
                clinical_discharge_approval_time,
                actual_exit_time
            )
        ), 2
    ) AS average_discharge_delay_minutes
FROM encounters
WHERE clinical_discharge_approval_time IS NOT NULL
  AND actual_exit_time IS NOT NULL
  AND actual_exit_time >= clinical_discharge_approval_time;


  Which departments have the highest average and cumulative discharge delays

  SELECT
    d.department_name,
    COUNT(*) AS discharge_encounters,
    ROUND(
        AVG(
            TIMESTAMPDIFF(
                MINUTE,
                e.clinical_discharge_approval_time,
                e.actual_exit_time
            )
        ), 2
    ) AS average_delay_minutes,
    ROUND(
        SUM(
            TIMESTAMPDIFF(
                MINUTE,
                e.clinical_discharge_approval_time,
                e.actual_exit_time
            )
        ) / 60, 2
    ) AS total_delay_hours
FROM encounters e
JOIN departments d
    ON e.department_id = d.department_id
WHERE e.clinical_discharge_approval_time IS NOT NULL
  AND e.actual_exit_time IS NOT NULL
  AND e.actual_exit_time >= e.clinical_discharge_approval_time
GROUP BY d.department_name
ORDER BY total_delay_hours DESC;

During which hours do the highest discharge delays occur

SELECT
    HOUR(clinical_discharge_approval_time) AS approval_hour,
    COUNT(*) AS discharge_count,
    ROUND(
        AVG(
            TIMESTAMPDIFF(
                MINUTE,
                clinical_discharge_approval_time,
                actual_exit_time
            )
        ), 2
    ) AS average_delay_minutes
FROM encounters
WHERE clinical_discharge_approval_time IS NOT NULL
  AND actual_exit_time IS NOT NULL
  AND actual_exit_time >= clinical_discharge_approval_time
GROUP BY HOUR(clinical_discharge_approval_time)
ORDER BY average_delay_minutes DESC;


How does discharge delay differ between insured and uninsured encounters

SELECT
    CASE
        WHEN i.encounter_id IS NOT NULL THEN 'Insured'
        ELSE 'Uninsured'
    END AS insurance_category,
    COUNT(*) AS discharge_encounters,
    ROUND(
        AVG(
            TIMESTAMPDIFF(
                MINUTE,
                e.clinical_discharge_approval_time,
                e.actual_exit_time
            )
        ), 2
    ) AS average_discharge_delay_minutes
FROM encounters e
LEFT JOIN insurance_records i
    ON e.encounter_id = i.encounter_id
WHERE e.clinical_discharge_approval_time IS NOT NULL
  AND e.actual_exit_time IS NOT NULL
  AND e.actual_exit_time >= e.clinical_discharge_approval_time
GROUP BY insurance_category;


What percentage of encounters have missing clinical approval or actual exit timestamps

SELECT
    COUNT(*) AS total_encounters,
    SUM(
        CASE
            WHEN clinical_discharge_approval_time IS NULL
            THEN 1 ELSE 0
        END
    ) AS missing_approval_timestamp,
    SUM(
        CASE
            WHEN actual_exit_time IS NULL
            THEN 1 ELSE 0
        END
    ) AS missing_exit_timestamp,
    SUM(
        CASE
            WHEN clinical_discharge_approval_time IS NULL
              OR actual_exit_time IS NULL
            THEN 1 ELSE 0
        END
    ) AS missing_either_timestamp,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN clinical_discharge_approval_time IS NULL
                  OR actual_exit_time IS NULL
                THEN 1 ELSE 0
            END
        ) / COUNT(*), 2
    ) AS missing_timestamp_percentage
FROM encounters;


What is the average turnaround time for laboratory, radiology and pharmacy services

SELECT
    'Laboratory' AS service,
    COUNT(*) AS total_records,
    ROUND(
        AVG(TIMESTAMPDIFF(MINUTE, order_time, result_verified_time)),
        2
    ) AS average_tat_minutes
FROM lab_records
WHERE order_time IS NOT NULL
  AND result_verified_time IS NOT NULL

UNION ALL

SELECT
    'Radiology',
    COUNT(*),
    ROUND(
        AVG(TIMESTAMPDIFF(MINUTE, order_time, report_verified_time)),
        2
    )
FROM radiology_records
WHERE order_time IS NOT NULL
  AND report_verified_time IS NOT NULL

UNION ALL

SELECT
    'Pharmacy',
    COUNT(*),
    ROUND(
        AVG(TIMESTAMPDIFF(MINUTE, prescription_time, dispensing_time)),
        2
    )
FROM pharmacy_records
WHERE prescription_time IS NOT NULL
  AND dispensing_time IS NOT NULL;


Which service categories have the highest target-breach percentage

SELECT
    'Laboratory' AS service,
    test_name AS service_category,
    COUNT(*) AS total_records,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN TIMESTAMPDIFF(
                    MINUTE, order_time, result_verified_time
                ) > tat_target_minutes
                THEN 1 ELSE 0
            END
        ) / COUNT(*), 2
    ) AS breach_percentage
FROM lab_records
WHERE order_time IS NOT NULL
  AND result_verified_time IS NOT NULL
  AND tat_target_minutes IS NOT NULL
GROUP BY test_name

UNION ALL

SELECT
    'Radiology',
    modality,
    COUNT(*),
    ROUND(
        100.0 * SUM(
            CASE
                WHEN TIMESTAMPDIFF(
                    MINUTE, order_time, report_verified_time
                ) > tat_target_minutes
                THEN 1 ELSE 0
            END
        ) / COUNT(*), 2
    )
FROM radiology_records
WHERE order_time IS NOT NULL
  AND report_verified_time IS NOT NULL
  AND tat_target_minutes IS NOT NULL
GROUP BY modality

UNION ALL

SELECT
    'Pharmacy',
    medication_category,
    COUNT(*),
    ROUND(
        100.0 * SUM(
            CASE
                WHEN TIMESTAMPDIFF(
                    MINUTE, prescription_time, dispensing_time
                ) > tat_target_minutes
                THEN 1 ELSE 0
            END
        ) / COUNT(*), 2
    )
FROM pharmacy_records
WHERE prescription_time IS NOT NULL
  AND dispensing_time IS NOT NULL
  AND tat_target_minutes IS NOT NULL
GROUP BY medication_category

ORDER BY breach_percentage DESC;


Which service contributes the highest total excess turnaround hours

WITH service_excess AS (
    SELECT
        'Laboratory' AS service,
        SUM(
            GREATEST(
                TIMESTAMPDIFF(
                    MINUTE, order_time, result_verified_time
                ) - tat_target_minutes,
                0
            )
        ) / 60 AS excess_hours
    FROM lab_records
    WHERE order_time IS NOT NULL
      AND result_verified_time IS NOT NULL
      AND tat_target_minutes IS NOT NULL

    UNION ALL

    SELECT
        'Radiology',
        SUM(
            GREATEST(
                TIMESTAMPDIFF(
                    MINUTE, order_time, report_verified_time
                ) - tat_target_minutes,
                0
            )
        ) / 60
    FROM radiology_records
    WHERE order_time IS NOT NULL
      AND report_verified_time IS NOT NULL
      AND tat_target_minutes IS NOT NULL

    UNION ALL

    SELECT
        'Pharmacy',
        SUM(
            GREATEST(
                TIMESTAMPDIFF(
                    MINUTE, prescription_time, dispensing_time
                ) - tat_target_minutes,
                0
            )
        ) / 60
    FROM pharmacy_records
    WHERE prescription_time IS NOT NULL
      AND dispensing_time IS NOT NULL
      AND tat_target_minutes IS NOT NULL
)
SELECT
    service,
    ROUND(excess_hours, 2) AS total_excess_hours
FROM service_excess
ORDER BY excess_hours DESC;


Which radiology modalities have the longest average turnaround time

SELECT
    modality,
    COUNT(*) AS total_scans,
    ROUND(
        AVG(
            TIMESTAMPDIFF(
                MINUTE, order_time, report_verified_time
            )
        ), 2
    ) AS average_tat_minutes,
    ROUND(
        MAX(
            TIMESTAMPDIFF(
                MINUTE, order_time, report_verified_time
            )
        ), 2
    ) AS maximum_tat_minutes
FROM radiology_records
WHERE order_time IS NOT NULL
  AND report_verified_time IS NOT NULL
GROUP BY modality
ORDER BY average_tat_minutes DESC;

Year-wise Performance Analysis
WITH yearly_encounters AS (
    SELECT
        YEAR(arrival_time) AS analysis_year,
        COUNT(*) AS patient_encounters
    FROM encounters
    WHERE arrival_time IS NOT NULL
      AND YEAR(arrival_time) IN (2024, 2025)
    GROUP BY YEAR(arrival_time)
),
yearly_waiting AS (
    SELECT
        YEAR(wait_start_time) AS analysis_year,
        COUNT(*) AS waiting_events,
        ROUND(AVG(wait_minutes), 2) AS average_wait_minutes,
        ROUND(
            100.0 * SUM(
                CASE
                    WHEN wait_minutes > target_minutes
                    THEN 1 ELSE 0
                END
            ) / COUNT(*), 2
        ) AS waiting_breach_percentage
    FROM patient_wait_events
    WHERE wait_start_time IS NOT NULL
      AND wait_minutes IS NOT NULL
      AND target_minutes IS NOT NULL
      AND YEAR(wait_start_time) IN (2024, 2025)
    GROUP BY YEAR(wait_start_time)
)
SELECT
    e.analysis_year,
    e.patient_encounters,
    w.waiting_events,
    w.average_wait_minutes,
    w.waiting_breach_percentage
FROM yearly_encounters e
LEFT JOIN yearly_waiting w
    ON e.analysis_year = w.analysis_year
ORDER BY e.analysis_year;
