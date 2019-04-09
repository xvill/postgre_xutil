CREATE OR REPLACE FUNCTION x_isvalidgeom(wkt text) RETURNS boolean AS
$$
BEGIN
  if st_isvalid(st_geomfromewkt(wkt)) then
    return true;
  end if;
  EXCEPTION
  WHEN others THEN
    return false;
END
$$ LANGUAGE PLPGSQL;
