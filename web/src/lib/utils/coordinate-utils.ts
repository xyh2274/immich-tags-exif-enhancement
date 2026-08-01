/**
 * WGS84 ↔ GCJ-02 coordinate conversion utilities.
 * GCJ-02 (Mars coordinate system) is used by Chinese map services including Amap (高德).
 * The offset can be 100-700 meters in China; outside China the conversion returns original coords.
 *
 * Based on the standard transformation algorithm:
 * https://en.wikipedia.org/wiki/Restrictions_on_geographic_data_in_China
 */

const PI = Math.PI;
const A = 6378245.0; // semi-major axis (Krasovsky 1940)
const EE = 0.00669342162296594323; // eccentricity squared

function _isOutOfChina(lng: number, lat: number): boolean {
  return lng < 72.004 || lng > 137.8347 || lat < 0.8293 || lat > 55.8271;
}

function _transformLat(x: number, y: number): number {
  let ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * Math.sqrt(Math.abs(x));
  ret += ((20.0 * Math.sin(6.0 * x * PI) + 20.0 * Math.sin(2.0 * x * PI)) * 2.0) / 3.0;
  ret += ((20.0 * Math.sin(y * PI) + 40.0 * Math.sin((y / 3.0) * PI)) * 2.0) / 3.0;
  ret += ((160.0 * Math.sin((y / 12.0) * PI) + 320.0 * Math.sin((y * PI) / 30.0)) * 2.0) / 3.0;
  return ret;
}

function _transformLng(x: number, y: number): number {
  let ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * Math.sqrt(Math.abs(x));
  ret += ((20.0 * Math.sin(6.0 * x * PI) + 20.0 * Math.sin(2.0 * x * PI)) * 2.0) / 3.0;
  ret += ((20.0 * Math.sin(x * PI) + 40.0 * Math.sin((x / 3.0) * PI)) * 2.0) / 3.0;
  ret += ((150.0 * Math.sin((x / 12.0) * PI) + 300.0 * Math.sin((x / 15.0) * PI)) * 2.0) / 3.0;
  return ret;
}

/**
 * Convert WGS84 coordinates to GCJ-02 (Mars coordinates).
 * Used when displaying markers on Amap/Chinese map tiles.
 */
export function wgs84ToGcj02(lng: number, lat: number): [number, number] {
  if (_isOutOfChina(lng, lat)) {
    return [lng, lat];
  }
  let dlat = _transformLat(lng - 105.0, lat - 35.0);
  let dlng = _transformLng(lng - 105.0, lat - 35.0);
  const radlat = (lat / 180.0) * PI;
  let magic = Math.sin(radlat);
  magic = 1 - EE * magic * magic;
  const sqrtmagic = Math.sqrt(magic);
  dlat = (dlat * 180.0) / (((A * (1 - EE)) / (magic * sqrtmagic)) * PI);
  dlng = (dlng * 180.0) / ((A / sqrtmagic) * Math.cos(radlat) * PI);
  return [lng + dlng, lat + dlat];
}

/**
 * Convert GCJ-02 coordinates back to WGS84.
 * Used when reading coordinates from Amap and storing in database.
 */
export function gcj02ToWgs84(lng: number, lat: number): [number, number] {
  if (_isOutOfChina(lng, lat)) {
    return [lng, lat];
  }
  const [mglng, mglat] = wgs84ToGcj02(lng, lat);
  return [lng * 2 - mglng, lat * 2 - mglat];
}
