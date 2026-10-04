# NYC Homicides Near Subway Stations: Spatial Analysis with PostGIS

Which New York City subway stations have the most homicides nearby? This project uses PostgreSQL and PostGIS to count homicides within 2,500 feet of every subway station, then finds the stations that are above average for their borough. 

<img width="2400" height="1275" alt="image" src="https://github.com/user-attachments/assets/e2942205-b3a4-48cf-a5bd-6fcb79120335" />


## Key results

| | Result |
|---|---|
| Subway stations | 491 |
| Homicides (2003 to 2011) | 3,982 |
| Search radius | 2,500 ft (762 m) |
| Stations above their borough's average | **195** |
| Stations with zero homicides nearby | 16 |

**Top 10 stations by homicides within 2,500 ft**

| Station | Borough | Homicides |
|---|---|---:|
| Sutter Ave | Brooklyn | 80 |
| 145th St | Manhattan | 76 |
| 182nd St | Bronx | 76 |
| Rockaway Ave | Brooklyn | 75 |
| Mt Eden Ave | Bronx | 74 |
| 167th St | Bronx | 71 |
| 170th St | Bronx | 71 |
| 135th St | Manhattan | 70 |
| 170th St | Bronx | 70 |
| Fordham Rd | Bronx | 70 |

There are two different stations named 170th St in the Bronx, which is why it shows up twice.

**Borough averages**

| Borough | Avg homicides per station | Stations above average |
|---|---:|---:|
| Bronx | 32.67 | 30 of 69 |
| Brooklyn | 22.25 | 69 of 170 |
| Manhattan | 17.87 | 53 of 140 |
| Queens | 7.12 | 35 of 90 |
| Staten Island | 1.68 | 8 of 22 |

The Bronx has the highest average by a wide margin. Staten Island stations average fewer than 2 homicides nearby.

## Data

This project uses `nyc_data.backup` from the official [PostGIS workshop](https://postgis.net/workshops/postgis-intro/).

| Table | Geometry | Description |
|---|---|---|
| `nyc_subway_stations` | POINT | Subway station locations (491) |
| `nyc_homicides` | POINT | Locations of reported homicides (3,982) |
| `nyc_neighborhoods` | MULTIPOLYGON | Neighborhood boundaries |
| `nyc_streets` | MULTILINESTRING | Street centerlines |
| `nyc_census_blocks` | MULTIPOLYGON | Census blocks with population data |

Only the first two tables are used here.

### Checking the SRID

```sql
SELECT f_table_name, srid FROM geometry_columns;
```

Every table uses **SRID 26918** (NAD83 / UTM zone 18N), which measures distance in **meters**. So the 2,500 ft radius has to be converted before it goes into `ST_DWithin`:

```
2,500 ft × 0.3048 = 762 m
```

Using 2,500 directly would search a radius of 2,500 meters, about three times too large.

## Task 1: Homicides near each subway station

```sql
-- SRID is 26918 (UTM, meters), so 2,500 ft = 762 m
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
```

**Output:** `Steven_Gobran_E1_station_homicides.csv` (491 rows)

## Task 2: Stations above their borough's average

```sql
-- SRID is 26918 (UTM, meters), so 2,500 ft = 762 m
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
```

**Output:** `Steven_Gobran_E1_borough_above_avg_stations.csv` (195 rows)

## How the queries work

- **`ST_DWithin(a, b, 762)`** returns true when two geometries are within 762 meters of each other. It uses the spatial (GiST) index on `geom`, so it runs much faster than computing `ST_Distance` for every pair.
- **`LEFT JOIN`** keeps stations with no homicides nearby, so they count as 0. A plain `JOIN` would drop those 16 stations and push the borough averages up.
- **Grouping by `gid`** keeps each station separate. Station names repeat in this data (491 stations, only 357 names), so grouping by name alone would merge different stations.
- **`AVG(...) OVER (PARTITION BY borough)`** is a window function. It puts each borough's average next to every station in that borough, so the query can compare a station's count to its own borough's average in a single pass.

## Run it yourself

1. Install [PostgreSQL](https://www.postgresql.org/download/) and the PostGIS extension (Stack Builder on Windows).
2. In pgAdmin, create a database named `nyc`.
3. Open the Query Tool on `nyc` and run:
   ```sql
   CREATE EXTENSION postgis;
   ```
4. Right-click `nyc` > **Restore**, choose `nyc_data.backup` (format: Custom or tar), and under **Data Options** turn on **Do not save: Owner**.
5. Run `task1.sql` and `task2.sql` in the Query Tool. Press **F8** to save each result as a CSV.

## Repo structure

```
├── README.md
├── task1.sql                                       # Homicides per station
├── task2.sql                                       # Stations above borough average
├── Steven_Gobran_E1_station_homicides.csv          # Task 1 output (491 rows)
└── Steven_Gobran_E1_borough_above_avg_stations.csv # Task 2 output (195 rows)
```

## Notes

- Homicide records cover 2003 to 2011, so these counts reflect that period, not current conditions.
- Counts measure how many homicides happened near a station, not at it. Stations in dense neighborhoods will naturally have more incidents within 2,500 ft.
- A homicide can fall within 2,500 ft of several stations, so it can be counted more than once across stations.

## Tools

PostgreSQL 18 · PostGIS · pgAdmin 4 · SQL

---

*Steven Gobran · Middle Tennessee State University*
