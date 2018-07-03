--==========================================================================
-- 转换point 从国际标准 到火星坐标
create function x_wgs2gcj(geoma geometry) returns geometry
LANGUAGE plpgsql
AS $$
DECLARE
  wgs_lon DOUBLE PRECISION;
  wgs_lat DOUBLE PRECISION;
  lon     DOUBLE PRECISION;
  lat     DOUBLE PRECISION;
  a         DOUBLE PRECISION := 6378245.0;
  ee        DOUBLE PRECISION := 0.00669342162296594323;
  dLat      DOUBLE PRECISION;
  dLon      DOUBLE PRECISION;
  x         DOUBLE PRECISION;
  y         DOUBLE PRECISION;
  radLat    DOUBLE PRECISION;
  magic     DOUBLE PRECISION;
  SqrtMagic DOUBLE PRECISION;
BEGIN
  --坐标在国外
  wgs_lon :=st_x(geomA);
  wgs_lat :=st_y(geomA);

  IF (wgs_lon < 72.004 OR wgs_lon > 137.8347 OR wgs_lat < 0.8293 OR wgs_lat > 55.8271)
  THEN
    lon:= wgs_lon;
    lat:= wgs_lat;
    return st_makepoint(lon,lat);
  END IF;
  --国内坐标
  x:=wgs_lon - 105.0;
  y:=wgs_lat - 35.0;
  dLat:= -100.0 + 2.0 * x + 3.0 * y + 0.2 * power(y, 2) + 0.1 * x * y + 0.2 * sqrt(abs(x))
         + (20.0 * sin(6.0 * x * pi()) + 20.0 * sin(2.0 * x * pi())) * 2.0 / 3.0
         + (20.0 * sin(y * pi()) + 40.0 * sin(y / 3.0 * pi())) * 2.0 / 3.0
         + (160.0 * sin(y / 12.0 * pi()) + 320 * sin(y * pi() / 30.0)) * 2.0 / 3.0;
  dLon:= 300.0 + x + 2.0 * y + 0.1 * power(x, 2) + 0.1 * x * y + 0.1 * sqrt(abs(x))
         + (20.0 * sin(6.0 * x * pi()) + 20.0 * sin(2.0 * x * pi())) * 2.0 / 3.0
         + (20.0 * sin(x * pi()) + 40.0 * sin(x / 3.0 * pi())) * 2.0 / 3.0
         + (150.0 * sin(x / 12.0 * pi()) + 300.0 * sin(x / 30.0 * pi())) * 2.0 / 3.0;
  radLat:=wgs_lat / 180.0 * pi();
  magic:= sin(radLat);
  magic:=1 - ee * magic * magic;
  SqrtMagic:= sqrt(magic);

  dLon:= (dLon * 180.0) / (a / SqrtMagic * cos(radLat) * pi());
  dLat:= (dLat * 180.0) / ((a * (1 - ee)) / (magic * SqrtMagic) * pi());

  lon:= wgs_lon + dLon;
  lat:= wgs_lat + dLat;

  return st_makepoint(lon,lat);
END;
$$;

--==========================================================================
-- 转换支持类型 从国际标准 到火星坐标
CREATE OR REPLACE FUNCTION xgeo_wgs2gcj(geomA GEOMETRY)
  RETURNS GEOMETRY AS
$BODY$
DECLARE
  geotype TEXT;
  geomB   GEOMETRY;
BEGIN
  geotype :=st_geometrytype(geomA);

  CASE geotype
    WHEN 'ST_Point' THEN
      SELECT x_wgs2gcj(geomA) INTO geomB;
    WHEN 'ST_MultiPoint' THEN
      SELECT st_Collect(x_wgs2gcj(geom)) INTO geomB
      FROM st_dumppoints(geomA);
    WHEN 'ST_LineString' THEN
      SELECT st_makeline(x_wgs2gcj(geom)) INTO geomB
      FROM st_dumppoints(geomA);
    WHEN 'ST_MultiLineString' THEN
      SELECT st_collect(p) INTO geomB
      FROM (
             SELECT st_makeline(point) AS p
             FROM
               (SELECT
                  x_wgs2gcj(geom)     AS point,
                  path [1] AS p1
                FROM st_dumppoints(geomA)
                ORDER BY path
               ) AS foo2
             GROUP BY p1
             ORDER BY p1) AS foo3;
    WHEN 'ST_Polygon' THEN
      SELECT st_makepolygon(pl [1], pl [2 :]) INTO geomB
      FROM (SELECT ARRAY_AGG(p) AS pl
            FROM (SELECT st_makeline(point) AS p
                  FROM (SELECT
                          x_wgs2gcj(geom) AS point,
                          path [1] AS p1
                		FROM st_dumppoints(geomA)
                        ORDER BY path
                       ) AS foo2
                  GROUP BY p1
                  ORDER BY p1
                 ) AS foo3
           ) AS foo4;
    WHEN 'ST_MultiPolygon' THEN
      SELECT st_collect(po) INTO geomB
      FROM (SELECT st_makepolygon(pl [1], pl [2 :]) AS po
            FROM (SELECT
                    p1,
                    ARRAY_AGG(p) AS pl
                  FROM (SELECT
                          p1,
                          p2,
                          st_makeline(point) AS p
                        FROM (SELECT
                                x_wgs2gcj(geom) AS point,
                                path [1] AS p1,
                                path [2] AS p2
                			  FROM st_dumppoints(geomA)
                              ORDER BY path
                             ) AS foo2
                        GROUP BY p1, p2
                        ORDER BY p1, p2
                       ) AS foo3
                  GROUP BY p1
                  ORDER BY p1
                 ) AS foo4) AS foo5;
  ELSE
    RETURN geomB;
  END CASE;
  RETURN geomB;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;
--==========================================================================
