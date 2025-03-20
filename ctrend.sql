-- Performance Trend Script for CDB level with ANSI colors
set ver off pages 50000 lines 270 tab off

-- Define input parameters
define start_time="&1"
define end_time="&2"
define interval_hours="&3"

-- Define color codes for easier reference
define COL_CPU=CHR(27)||'[34m'
define COL_IO=CHR(27)||'[32m'
define COL_CONC=CHR(27)||'[35m'
define COL_APP=CHR(27)||'[33m'
define COL_CMT=CHR(27)||'[31m'
define COL_NET=CHR(27)||'[36m'
define COL_OTH=CHR(27)||'[90m'
define COL_RESET=CHR(27)||'[0m'

-- Set column formatting with short headings
column start_time format a20
col io_val for a5 heading "IO"
col conc_val for a5 heading "CON"
col app_val for a5 heading "APP"
col cmt_val for a5 heading "CMT"
col net_val for a5 heading "NET"
col oth_val for a5 heading "OTH"
col chart for a80

-- Main query with expanded colored ASCII chart and colored column values
WITH aas_data AS (
    SELECT
        TO_CHAR(
            TRUNC(&start_time) +
            TRUNC((CAST(ash.sample_time AS DATE) - TRUNC(&start_time)) * 24 / (&interval_hours)) * (&interval_hours) / 24,
            'YYYY-MM-DD HH24:MI:SS'
        ) AS start_time,
        ROUND(SUM(aas_value)) AS aas,
        ROUND(SUM(DECODE(wait_category, 'CPU', aas_value, 0))) AS cpu,
        ROUND(SUM(DECODE(wait_category, 'IO', aas_value, 0))) AS io,
        ROUND(SUM(DECODE(wait_category, 'CONCURRENCY', aas_value, 0))) AS conc,
        ROUND(SUM(DECODE(wait_category, 'APPLICATION', aas_value, 0))) AS app,
        ROUND(SUM(DECODE(wait_category, 'COMMIT', aas_value, 0))) AS cmt,
        ROUND(SUM(DECODE(wait_category, 'NETWORK', aas_value, 0))) AS net,
        ROUND(SUM(DECODE(wait_category, 'OTHER', aas_value, 0))) AS oth,
        MAX(ROUND(SUM(aas_value))) OVER () AS max_aas_total
    FROM (
        SELECT
            ash.sample_time,
            CASE 
                WHEN session_state = 'ON CPU' THEN 'CPU'
                WHEN wait_class IN ('User I/O', 'System I/O') THEN 'IO'
                WHEN wait_class = 'Concurrency' THEN 'CONCURRENCY'
                WHEN wait_class = 'Application' THEN 'APPLICATION'
                WHEN wait_class = 'Commit' THEN 'COMMIT'
                WHEN wait_class = 'Network' THEN 'NETWORK'
                ELSE 'OTHER'
            END AS wait_category,
            SUM(ash.USECS_PER_ROW) / (&interval_hours * 3600 * 1000000) AS aas_value
        FROM 
            cdb_hist_active_sess_history ash
        WHERE 
            ash.sample_time >= &start_time
            AND ash.sample_time <= &end_time
        GROUP BY
            ash.sample_time,
            CASE 
                WHEN session_state = 'ON CPU' THEN 'CPU'
                WHEN wait_class IN ('User I/O', 'System I/O') THEN 'IO'
                WHEN wait_class = 'Concurrency' THEN 'CONCURRENCY'
                WHEN wait_class = 'Application' THEN 'APPLICATION'
                WHEN wait_class = 'Commit' THEN 'COMMIT'
                WHEN wait_class = 'Network' THEN 'NETWORK'
                ELSE 'OTHER'
            END
    ) ash
    GROUP BY
        TRUNC(&start_time) +
        TRUNC((CAST(ash.sample_time AS DATE) - TRUNC(&start_time)) * 24 / (&interval_hours)) * (&interval_hours) / 24
)
SELECT 
    start_time,
    aas as total,
    cpu,
    io,
    conc,
    app,
    cmt as commit,
    net as network,
    oth as other,
    &COL_CPU  || RPAD('*', ROUND(cpu), '*')  ||
    &COL_IO   || RPAD('*', ROUND(io), '*')   ||
    &COL_CONC || RPAD('*', ROUND(conc), '*') || 
    &COL_APP  || RPAD('*', ROUND(app), '*')  ||
    &COL_CMT  || RPAD('*', ROUND(cmt), '*')  ||
    &COL_NET  || RPAD('*', ROUND(net), '*')  ||
    &COL_OTH  || RPAD('*', ROUND(oth), '*')  || &COL_RESET AS chart
FROM 
    aas_data
ORDER BY 
    start_time;