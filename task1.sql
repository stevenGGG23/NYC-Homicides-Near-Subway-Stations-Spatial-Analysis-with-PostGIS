-- Task 1: Homicides within 2,500 ft of each subway station
-- SRID is 26918 (UTM zone 18N, meters), so 2,500 ft = 2,500 x 0.3048 = 762 m
SELECT
    s.gid,
    s.name     AS station_name,
    s.borough,
    COUNT(h.gid) AS homicide_count
FROM nyc_subway_stations AS s
LEFT JOIN nyc_homicides AS h
    ON ST_DWithin(s.geom, h.geom, 762)
GROUP BY s.gid, s.name, s.borough
ORDER BY homicide_count DESC, s.name;
