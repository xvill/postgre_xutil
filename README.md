# postgre_xutil
 
经纬度转换支持: WGS2GCJ,WGS2BD,GCJ2BD,GCJ2WGS,BD2GCJ,BD2WGS

## usage
```sql
geometry x_bd2gcj(bd_lon double,bd_lon double)    -- 转换从 百度 到火星坐标
geometry x_trans(geometry geom1,transtype text)  -- 转换 Point/LineString/Polygon/MultiPoint/MultiLineString/MultiPolygon

select x_BD2GCJ(st_x(point),st_y(point)),
  st_astext(x_trans(mline,'WGS2BD')),
  st_astext(x_trans(mpoint,'WGS2BD')),
  st_astext(x_trans(mpolygon,'WGS2BD')),
  st_astext(x_trans(polygon,'WGS2BD')),
  st_geometrytype(mpolygon)
from (select ST_GeomFromText('Point (10 10)') point
  ,ST_GeomFromText('MULTIPOINT ((10 40), (40 30), (20 20), (30 10))') mpoint
  ,ST_GeomFromText('MULTIPOINT (10 40, 40 30, 20 20, 30 10)') mpoint2
  ,ST_GeomFromText('POLYGON ((30 10, 40 40, 20 40, 10 20, 30 10))') polygon
  ,ST_GeomFromText('MULTILINESTRING ((10 10, 20 20, 10 40),(40 40, 30 30, 40 20, 30 10))') mline
  ,ST_GeomFromText('MULTIPOLYGON (((30 20, 45 40, 10 40, 30 20)),((15 5, 40 10, 10 20, 5 10, 15 5)))') mpolygon
) t


```
