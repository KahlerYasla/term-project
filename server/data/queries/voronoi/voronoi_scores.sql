-- Drop the view if it exists
DROP VIEW IF EXISTS market_voronoi_view;
-- Define the boundary polygon manually with the new coordinates
WITH boundary AS (
    SELECT ST_GeomFromText(
            'POLYGON((29.01807268351905 41.05749296161869, 29.01478522589497 41.064667722383234, 29.00924980870684 41.06669412356328, 28.980499381909993 41.06652300192371, 28.983324071220324 41.05024275884392, 28.98301197376756 41.038836135628145, 28.970654677284955 41.03540791580775, 28.968190553816214 41.02587027229552, 28.971902522744955 41.02237274262822, 28.977218519988583 41.02282133304152, 28.986742610250445 41.02803583837343, 28.99226316547913 41.03369423906301, 28.996090866384407 41.03761203196751, 29.002654517254342 41.03993240822828, 29.014482026365812 41.04323294346804, 29.023161041012344 41.04699672550589, 29.029585927554876 41.049831982518754, 29.01807268351905 41.05749296161869))',
            4326
        ) AS geom
),
voronoi AS (
    SELECT ST_VoronoiPolygons(ST_Collect(geom)) AS geom
    FROM markets
),
-- Dump the collection into individual polygons
voronoi_dump AS (
    SELECT (ST_Dump(geom)).geom AS geom
    FROM voronoi
),
-- Clip each Voronoi polygon with the defined boundary
clipped_voronoi AS (
    SELECT ST_Intersection(v.geom, b.geom) AS geom
    FROM voronoi_dump v,
        boundary b
),
-- Calculate the area of each clipped Voronoi polygon
voronoi_with_area AS (
    SELECT geom,
        ST_Area(geom::geography) AS area -- Calculate the area in square meters
    FROM clipped_voronoi
),
-- Get the min and max area values
area_stats AS (
    SELECT MIN(area) AS min_area,
        MAX(area) AS max_area
    FROM voronoi_with_area
),
-- Normalize the area values between 0 and 10
normalized_voronoi AS (
    SELECT geom,
        area,
        ((area - s.min_area) / (s.max_area - s.min_area)) * 10 AS voronoical_score
    FROM voronoi_with_area,
        area_stats s
),
-- Assign each normalized Voronoi polygon to the nearest market
market_voronoi AS (
    SELECT m.id AS market_id,
        n.voronoical_score
    FROM markets m
        JOIN normalized_voronoi n ON ST_Intersects(m.geom, n.geom)
)
SELECT *
FROM market_voronoi;