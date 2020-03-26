import 'package:flutter/material.dart';
import 'package:tuple/tuple.dart';
import 'package:charts_flutter/flutter.dart' as charts;

import 'model.dart';

class InputLatencyView extends StatelessWidget {
  const InputLatencyView({
    Key key,
    @required this.simulated,
  }) : super(key: key);

  final List<FrameMetrics> simulated;

  @override
  Widget build(BuildContext context) {
    final List<FrameMetrics> rendered =
        simulated.where((e) => e.displayTime != null).toList();
    final List<Tuple2<FrameMetrics, FrameMetrics>> pairs = [];

    int totalMinLatency = 0, count = 0;
    int totalMaxLatency = 0;
    for (int i = 1; i < rendered.length; i++) {
      pairs.add(
          Tuple2<FrameMetrics, FrameMetrics>(rendered[i - 1], rendered[i]));
      int minL = rendered[i].displayTime - rendered[i].buildStart;
      int maxL = rendered[i].displayTime - rendered[i - 1].buildStart;
      totalMinLatency += minL;
      totalMaxLatency += maxL;
      count++;
    }
    final String avgMinL = (totalMinLatency / count).toStringAsFixed(3);
    final String avgMaxL = (totalMaxLatency / count).toStringAsFixed(3);

    return Column(
      children: <Widget>[
        ChartName(name: 'Frame min and max input latency'),
        Text('min = displayTime - buildStart,'
            'max = displayTime - prevBuildStart'),
        Text('[Avg min latency = $avgMinL, Avg max latency = $avgMaxL]'),
        Container(
          width: 500,
          height: 250,
          child: new charts.ScatterPlotChart(
            <charts.Series<Tuple2<FrameMetrics, FrameMetrics>, int>>[
              charts.Series<Tuple2<FrameMetrics, FrameMetrics>, int>(
                id: 'min_latency_chart',
                colorFn: (_, __) => charts.MaterialPalette.green.shadeDefault,
                domainFn: (Tuple2<FrameMetrics, FrameMetrics> metrics, _) =>
                    metrics.item2.buildStart,
                measureFn: (Tuple2<FrameMetrics, FrameMetrics> metrics, _) =>
                    metrics.item2.displayTime - metrics.item2.buildStart,
                data: pairs,
              ),
              charts.Series<Tuple2<FrameMetrics, FrameMetrics>, int>(
                id: 'max_latency_chart',
                colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
                domainFn: (Tuple2<FrameMetrics, FrameMetrics> metrics, _) =>
                    metrics.item2.buildStart,
                measureFn: (Tuple2<FrameMetrics, FrameMetrics> metrics, _) =>
                    metrics.item2.displayTime - metrics.item1.buildStart,
                data: pairs,
              )
            ],
            animate: false,
            defaultRenderer: new charts.PointRendererConfig(),
          ),
        ),
        Divider(),
      ],
    );
  }
}

class LagView extends StatelessWidget {
  const LagView({
    Key key,
    @required this.simulated,
  }) : super(key: key);

  final List<FrameMetrics> simulated;

  @override
  Widget build(BuildContext context) {
    final List<FrameMetrics> rendered =
        simulated.where((e) => e.displayTime != null).toList();
    final int totalLag =
        rendered.map((e) => e.lag()).reduce((v1, v2) => v1 + v2);
    final String avgLag = (totalLag / rendered.length).toStringAsFixed(3);

    return Column(
      children: <Widget>[
        Text('Num frames rendered = ${rendered.length}'),
        ChartName(
            name: 'Frame Lag (displayTime - targetTime) [Avg = $avgLag ticks]'),
        Container(
          width: 500,
          height: 250,
          child: new charts.ScatterPlotChart(
            <charts.Series<FrameMetrics, int>>[
              charts.Series<FrameMetrics, int>(
                id: 'build_to_raster',
                colorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
                domainFn: (FrameMetrics metrics, _) => metrics.buildStart,
                measureFn: (FrameMetrics metrics, _) => metrics.lag(),
                data: rendered,
              )
            ],
            animate: false,
            defaultRenderer: new charts.PointRendererConfig(),
          ),
        ),
        Divider(),
      ],
    );
  }
}

class ChartName extends StatelessWidget {
  final String name;

  const ChartName({Key key, this.name}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      style: TextStyle(
        fontSize: 20,
        color: Colors.blueAccent,
      ),
    );
  }
}
