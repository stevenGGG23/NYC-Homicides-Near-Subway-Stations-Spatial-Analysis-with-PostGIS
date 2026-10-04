-- Task 2: Stations with more homicides within 2,500 ft than their borough's average
WITH station_counts AS (
    SELECT
        s.gid,
        s.name     AS station_name,
        s.borough,
        COUNT(h.gid) AS homicide_count
    FROM nyc_subway_stations AS s
    LEFT JOIN nyc_homicides AS h
        ON ST_DWithin(s.geom, h.geom, 762)
    GROUP BY s.gid, s.name, s.borough
),
with_avg AS (
    SELECT
        *,
        AVG(homicide_count) OVER (PARTITION BY borough) AS borough_avg
    FROM station_counts
)
SELECT
    borough,
    station_name,
    homicide_count,
    ROUND(borough_avg, 2) AS borough_avg
FROM with_avg
WHERE homicide_count > borough_avg
ORDER BY borough, homicide_count DESC, station_name;
