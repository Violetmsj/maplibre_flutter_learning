import 'dart:math';

import 'package:maplibre_gl/maplibre_gl.dart';

import 'map_state_mixin.dart';

mixin DrawPolygonMixin on MapStateMixin {
  // 地图中心屏幕坐标
  late Point mapCenter;
  // 画地开关
  bool isDrawingMode = false;
  // 切换画地模式
  void toggleDrawingMode() {
    isDrawingMode = !isDrawingMode;
    update(["maplibremap"]);
  }

  // 检查数据源是否存在
  Future<bool> isSourceExists(String sourceId) async {
    final controller = await mapController.future;
    List<String> sourceIds = await controller.getSourceIds();
    return sourceIds.contains(sourceId);
  }

  // 检查图层是否存在
  Future<bool> isLayerExists(String layerId) async {
    final controller = await mapController.future;
    List<String> layerIds = (await controller.getLayerIds()).cast<String>();
    return layerIds.contains(layerId);
  }

  //绘制多边形的坐标数组
  var drawPolygonPoints = <LatLng>[];
  void onDrawPolygonPoint() async {
    print("onDrawPolygonPoint");
    final controller = await mapController.future;
    var mapCenterLatlng = await controller.toLatLng(mapCenter);
    drawPolygonPoints.add(mapCenterLatlng);
    var coordinates = getCoordinatesFromPoints(drawPolygonPoints);

    // 检查数据源是否存在
    final drawLandPolygonSourceExists = await isSourceExists(
      "draw-land-polygon-source",
    );

    // 如果存在，则更新数据源，否则添加数据源
    if (drawLandPolygonSourceExists) {
      await updatePolygonSource(coordinates);
      print("更新数据源");
    } else {
      // 添加画地数据源
      await addPolygonSource(coordinates);
    }

    // 更新图层
    await updateLayers(coordinates.length > 2);

    print(mapCenterLatlng);
  }

  List<List<double>> getCoordinatesFromPoints(List<LatLng> points) {
    return points.map((e) => [e.longitude, e.latitude]).toList();
  }

  // 添加多边形数据源
  Future<void> addPolygonSource(List<List<double>> coordinates) async {
    final controller = await mapController.future;
    final features = <Map<String, dynamic>>[];

    // 添加点图层数据
    features.add({
      "type": "Feature",
      "geometry": {
        "type": "MultiPoint",
        "coordinates": coordinates,
      },
    });

    // 如果有至少2个点，添加线段数据
    if (coordinates.length >= 2) {
      features.add({
        "type": "Feature",
        "geometry": {
          "type": "LineString",
          "coordinates": coordinates,
        }
      });
    }

    try {
      await controller.addSource(
        "draw-land-polygon-source",
        GeojsonSourceProperties(
          data: {
            "type": "FeatureCollection",
            "features": features,
          },
        ),
      );
      print("添加画地数据源");
    } catch (e) {
      print(e);
    }
  }

  // 更新数据源的方法
  Future<void> updatePolygonSource(List<List<double>> coordinates) async {
    final controller = await mapController.future;
    final features = <Map<String, dynamic>>[];

    // 添加点图层数据
    features.add({
      "type": "Feature",
      "geometry": {
        "type": "MultiPoint",
        "coordinates": coordinates,
      },
    });
    // 添加线段数据（当有至少2个点时）
    if (coordinates.length >= 2) {
      features.add({
        "type": "Feature",
        "geometry": {
          "type": "LineString",
          "coordinates": coordinates,
        }
      });
    }
    // 如果点数足够，添加多边形数据
    if (coordinates.length > 2) {
      var polygonCoordinates = [...coordinates, coordinates[0]];
      features.add({
        "type": "Feature",
        "geometry": {
          "type": "Polygon",
          "coordinates": [polygonCoordinates],
        }
      });
    }

    // 更新数据源
    await controller.setGeoJsonSource("draw-land-polygon-source", {
      "type": "FeatureCollection",
      "features": features,
    });
  }

  // 更新图层的方法
  Future<void> updateLayers(bool showPolygon) async {
    final controller = await mapController.future;

    // 移除现有图层
    if (await isLayerExists("draw-land-polygon-layer")) {
      await controller.removeLayer("draw-land-polygon-layer");
    }
    if (await isLayerExists("draw-land-point-layer")) {
      await controller.removeLayer("draw-land-point-layer");
    }
    if (await isLayerExists("draw-land-line-layer")) {
      await controller.removeLayer("draw-land-line-layer");
    }
    // 添加线段图层
    await controller.addLayer(
      "draw-land-polygon-source",
      "draw-land-line-layer",
      LineLayerProperties(
        lineColor: "#ff098e", // 白色线段
        lineWidth: 10, // 线宽
      ),
    );
    // 添加点图层
    await controller.addLayer(
      "draw-land-polygon-source",
      "draw-land-point-layer",
      CircleLayerProperties(
        circleColor: "#FFA500",
        circleRadius: 6,
        circleStrokeWidth: 2,
        circleStrokeColor: "#FFFFFF",
      ),
    );

    // 如果需要显示多边形，添加多边形图层
    if (showPolygon) {
      await controller.addLayer(
        "draw-land-polygon-source",
        "draw-land-polygon-layer",
        FillLayerProperties(
          fillColor: "#808080",
          fillOutlineColor: "#ffffff",
          fillOpacity: 0.5,
        ),
      );
    }
  }

  // 撤销上一个点的方法
  void onUndoLastPoint() async {
    if (drawPolygonPoints.isEmpty) {
      return;
    }

    // 移除最后一个点
    drawPolygonPoints.removeLast();
    final coordinates = getCoordinatesFromPoints(drawPolygonPoints);

    // 更新数据源
    await updatePolygonSource(coordinates);

    // 更新图层
    await updateLayers(coordinates.length > 2);

    // 更新UI
    update(["maplibremap"]);
  }

  void onFinishDrawPolygon() {}
}
