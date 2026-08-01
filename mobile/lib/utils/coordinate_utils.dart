import 'dart:math' as math;

/// WGS84 <-> GCJ-02 coordinate conversion utilities.
/// GCJ-02 (Mars coordinate system) is used by Amap and other Chinese map services.
class CoordinateUtils {
  static const double _pi = math.pi;
  static const double _a = 6378245.0;
  static const double _ee = 0.00669342162296594323;

  static bool _isOutOfChina(double lng, double lat) {
    return lng < 72.004 || lng > 137.8347 || lat < 0.8293 || lat > 55.8271;
  }

  static double _transformLat(double x, double y) {
    double ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * math.sqrt(x.abs());
    ret += ((20.0 * math.sin(6.0 * x * _pi) + 20.0 * math.sin(2.0 * x * _pi)) * 2.0) / 3.0;
    ret += ((20.0 * math.sin(y * _pi) + 40.0 * math.sin((y / 3.0) * _pi)) * 2.0) / 3.0;
    ret += ((160.0 * math.sin((y / 12.0) * _pi) + 320.0 * math.sin((y * _pi) / 30.0)) * 2.0) / 3.0;
    return ret;
  }

  static double _transformLng(double x, double y) {
    double ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * math.sqrt(x.abs());
    ret += ((20.0 * math.sin(6.0 * x * _pi) + 20.0 * math.sin(2.0 * x * _pi)) * 2.0) / 3.0;
    ret += ((20.0 * math.sin(x * _pi) + 40.0 * math.sin((x / 3.0) * _pi)) * 2.0) / 3.0;
    ret += ((150.0 * math.sin((x / 12.0) * _pi) + 300.0 * math.sin((x / 15.0) * _pi)) * 2.0) / 3.0;
    return ret;
  }

  /// Convert WGS84 to GCJ-02
  static List<double> wgs84ToGcj02(double lng, double lat) {
    if (_isOutOfChina(lng, lat)) {
      return [lng, lat];
    }
    double dlat = _transformLat(lng - 105.0, lat - 35.0);
    double dlng = _transformLng(lng - 105.0, lat - 35.0);
    final radlat = (lat / 180.0) * _pi;
    double magic = math.sin(radlat);
    magic = 1 - _ee * magic * magic;
    final sqrtmagic = math.sqrt(magic);
    dlat = (dlat * 180.0) / (((_a * (1 - _ee)) / (magic * sqrtmagic)) * _pi);
    dlng = (dlng * 180.0) / ((_a / sqrtmagic) * math.cos(radlat) * _pi);
    return [lng + dlng, lat + dlat];
  }

  /// Convert GCJ-02 to WGS84
  static List<double> gcj02ToWgs84(double lng, double lat) {
    if (_isOutOfChina(lng, lat)) {
      return [lng, lat];
    }
    final result = wgs84ToGcj02(lng, lat);
    return [lng * 2 - result[0], lat * 2 - result[1]];
  }
}
