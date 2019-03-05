--===============================================================================
/*
	WGS-84: 国际标准,GPS坐标（GoogleEarth、或GPS模块）
	GCJ-02: 火星坐标,中国坐标偏移标准(GoogleMap、高德、腾讯)
	BD-09: 百度坐标偏移标准(BaiduMap)
 **/
--===============================================================================

-- 百度坐标系 (BD-09) 与 火星坐标系 (GCJ-02)的转换
CREATE OR REPLACE FUNCTION X_BD2GCJ(
  bd_lon double precision,
  bd_lat double precision
) RETURNS float[] As
$BODY$
DECLARE
  x double precision;
  y double precision;
  z double precision;
  lon double precision;
  lat double precision;
  theta double precision;
  x_pi double precision:=3.14159265358979324 * 3000.0 / 180.0;
BEGIN
  x:= bd_lon - 0.0065;
  y:= bd_lat - 0.006;
  z:=sqrt(power(x,2) + power(y,2)) - 0.00002 *sin(y * x_pi);
  theta:= atan2(y, x) - 0.000003 * cos(x * x_pi);
  lon:= z *cos(theta);
  lat:= z *sin(theta);
  return ARRAY[lon,lat];
END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE STRICT;

--===============================================================================
--火星坐标系 (GCJ-02) 与百度坐标系 (BD-09) 的转换
CREATE OR REPLACE FUNCTION X_GCJ2BD(
  gj_lon double precision,
  gj_lat double precision
) RETURNS float[] As
$BODY$
DECLARE
  z double precision;
  theta double precision;
  lon double precision;
  lat double precision;
  x_pi double precision:=3.14159265358979324 * 3000.0 / 180.0;
BEGIN
  z:= sqrt(power(gj_lon,2) + power(gj_lat,2)) + 0.00002 * sin(gj_lat * x_pi);
  theta:= atan2(gj_lat, gj_lon) + 0.000003 * cos(gj_lon * x_pi);
  lon:= z * cos(theta) + 0.0065;
  lat:= z * sin(theta) + 0.006;
  return ARRAY[lon,lat];
END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE STRICT;


--===============================================================================
--WGS84转火星
CREATE OR REPLACE FUNCTION X_WGS2GCJ(
  wgs_lon double precision,
  wgs_lat double precision
) RETURNS float[] As
$BODY$
DECLARE
  a double precision:= 6378245.0;
  ee double precision:= 0.00669342162296594323;
  dLat double precision;
  dLon double precision;
  x double precision;
  y double precision;
  radLat double precision;
  magic double precision;
  SqrtMagic double precision;
  lon double precision;
  lat double precision;
BEGIN
  --坐标在国外
  if(wgs_lon < 72.004 or wgs_lon > 137.8347 or wgs_lat < 0.8293 or wgs_lat > 55.8271) then
    return ARRAY[wgs_lon,wgs_lat];
  end if;
  --国内坐标
  x:=wgs_lon - 105.0;
  y:=wgs_lat - 35.0;
  dLat:= -100.0 + 2.0 * x + 3.0 * y + 0.2 * power(y,2) + 0.1 * x * y + 0.2 * sqrt(abs(x))
    +(20.0 * sin(6.0 * x * pi()) + 20.0 * sin(2.0 * x * pi())) * 2.0 / 3.0
    + (20.0 * sin(y * pi()) + 40.0 * sin(y / 3.0 * pi())) * 2.0 / 3.0
    + (160.0 * sin(y / 12.0 * pi()) + 320 * sin(y * pi() / 30.0)) * 2.0 / 3.0;
  dLon:= 300.0 + x + 2.0 * y + 0.1 * power(x,2) + 0.1 * x * y + 0.1 * sqrt(abs(x))
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
  return ARRAY[lon,lat];
END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE STRICT;

--===============================================================================
--火星转 WGS84
CREATE OR REPLACE FUNCTION X_GCJ2WGS(
  gcj_lon double precision,
  gcj_lat double precision
) RETURNS float[] As
$BODY$
DECLARE
  rec float[];
  d_lon double precision;
  d_lat double precision;
  lon double precision;
  lat double precision;
BEGIN
  select X_WGS2GCJ(gcj_lon, gcj_lat) into rec;
  d_lon:= rec[1] - gcj_lon;
  d_lat:= rec[2] - gcj_lat;
  lon:= gcj_lon - d_lon;
  lat:= gcj_lat - d_lat;
  return ARRAY[lon,lat];
END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE STRICT;


--===============================================================================
--百度转WGS
CREATE OR REPLACE FUNCTION X_BD2WGS(
  bd_lon double precision,
  bd_lat double precision
) RETURNS float[] As
$BODY$
DECLARE
  rec float[];
  d_lon double precision;
  d_lat double precision;
  lon double precision;
  lat double precision;
BEGIN
  select X_BD2GCJ(bd_lon, bd_lat) into rec;
  select X_GCJ2WGS(rec[1], rec[2]) into rec;
  lon:=rec[1];
  lat:=rec[2];
  return ARRAY[lon,lat];
END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE STRICT;

--WGS转百度
CREATE OR REPLACE FUNCTION X_WGS2BD(
  wgs_lon double precision,
  wgs_lat double precision
) RETURNS float[] As
$BODY$
DECLARE
  rec float[];
  d_lon double precision;
  d_lat double precision;
  lon double precision;
  lat double precision;
BEGIN
  select X_WGS2GCJ(wgs_lon, wgs_lat) into rec;
  select X_GCJ2BD(rec[1], rec[2]) into rec;
  lon:=rec[1];
  lat:=rec[2];
  return ARRAY[lon,lat];
END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE STRICT;
                              
--===============================================================================
--x_transpoint 转换点的坐标系
CREATE OR REPLACE FUNCTION x_transpoint(
  geom1 geometry,transtype text
) RETURNS geometry As
$BODY$
DECLARE
  retgeom geometry;
BEGIN
  with sa as (
    select case transtype
     when 'WGS2GCJ' then X_WGS2GCJ(st_x(geom1), st_y(geom1))
     when 'WGS2BD' then X_WGS2BD(st_x(geom1), st_y(geom1))
     when 'GCJ2BD' then X_GCJ2BD(st_x(geom1), st_y(geom1))
     when 'GCJ2WGS' then X_GCJ2WGS(st_x(geom1), st_y(geom1))
     when 'BD2GCJ' then X_BD2GCJ(st_x(geom1), st_y(geom1))
     when 'BD2WGS' then X_BD2WGS(st_x(geom1), st_y(geom1))
     else ARRAY[st_x(geom1), st_y(geom1)]
end points )
  select st_point(points[1],points[2]) from sa into retgeom;
  return retgeom;
END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE STRICT;

--===============================================================================
CREATE OR REPLACE FUNCTION x_makepoint(
  points double precision[]
) RETURNS geometry As
$BODY$
DECLARE
  retgeom geometry;
BEGIN
  select st_point(points[1],points[2]) into retgeom;
  return retgeom;
END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE STRICT;

--===============================================================================
--x_trans 转换geometry 的坐标系
CREATE OR REPLACE FUNCTION x_trans(
  geom1 geometry,transtype text
) RETURNS geometry As
$BODY$
DECLARE
  geomtype text;
  retgeom geometry;
BEGIN
  geomtype:=st_geometrytype(geom1);
  if  not (array[transtype] <@ ARRAY['WGS2GCJ','WGS2BD','GCJ2BD','GCJ2WGS','BD2GCJ','BD2WG']) then
    raise notice 'transtype not support';
  end if;
  case geomtype
    when 'ST_Point' then
      select x_transpoint(geom1,transtype) into retgeom;

    when 'ST_LineString' then
      select st_makeline(x_transpoint(o,transtype) order by p) from (
        select(dp).path p,(dp).geom o from (select ST_DumpPoints(geom1) as dp) as a ) as b
        into retgeom;

    when 'ST_Polygon' then
      with sa as (select p[1] p,st_makeline(x_transpoint(o,transtype) order by p[2]) po from (
          select(a.dp).path p,(a.dp).geom o from (select ST_DumpPoints(geom1) as dp) as a ) as b  group by p[1]
      ) select ST_MakePolygon((select po from sa where p=1),  ARRAY(select po from sa where p >1))
      into retgeom;

    when 'ST_MultiPoint' ,'ST_MultiLineString','ST_MultiPolygon' then
      select st_collect(x_trans(o,transtype))from (
          select (dp).geom o from (select st_dump(geom1) as dp )  as a ) as b
      into retgeom;

    else
      raise notice 'geomtype not support';
    end case;
  return retgeom;
END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE STRICT;
