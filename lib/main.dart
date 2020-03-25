import 'package:flutter/material.dart';
import 'input_form.dart';
import 'model.dart';
import 'simulations.dart';
import 'package:charts_flutter/flutter.dart' as charts;

void main() {
  runApp(PipelineSimulatorApp());
}

class PipelineSimulatorApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pipeline Simulator App',
      theme: ThemeData.light(),
      home: Material(child: SimulationAndForm()),
    );
  }
}

class SimulationAndForm extends StatefulWidget {
  @override
  _SimulationAndFormState createState() => _SimulationAndFormState();
}

class _SimulationAndFormState extends State<SimulationAndForm> {
  PipelineSettings settings = PipelineSettings.fromMap(kDefaultSettings);

  void onSuccess(Map<String, int> map) {
    setState(() {
      settings = PipelineSettings.fromMap(map);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 300,
          child: InputSettings(
            fields: kDefaultSettings,
            successCallback: onSuccess,
          ),
        ),
        PipelineSimatorAnimation(
          settings: settings,
        )
      ],
    );
  }
}

class PipelineSimatorAnimation extends StatefulWidget {
  final PipelineSettings settings;

  const PipelineSimatorAnimation({Key key, this.settings}) : super(key: key);

  @override
  _PipelineSimatorAnimationState createState() =>
      _PipelineSimatorAnimationState();
}

class _PipelineSimatorAnimationState extends State<PipelineSimatorAnimation>
    with SingleTickerProviderStateMixin {
  Animation<int> tickCounter;
  AnimationController controller;

  void _initAnimations() {
    controller.duration =
        Duration(seconds: widget.settings.animationDurationInSecs);
    tickCounter = IntTween(begin: 0, end: widget.settings.totalNumTicks)
        .animate(controller)
          ..addListener(() {
            setState(() {
              // The state that has changed here is the animation object’s value.
            });
          });
    controller.forward();
  }

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
    );
    _initAnimations();
  }

  @override
  void didUpdateWidget(PipelineSimatorAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      controller.reset();
      _initAnimations();
    }
  }

  List<Widget> getSimulations() {
    List<PipelineSimulation> simulations = <PipelineSimulation>[
      ProducerContinuationSimulation()
    ];
    return simulations
        .map((sim) => PipelineSimulationView(
              settings: widget.settings,
              simulation: sim,
              animationStatus: controller.status,
              tick: tickCounter.value,
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final PipelineSettings settings = widget.settings;

    List<Widget> cols = <Widget>[
          SimulatorSettingsView(settings: settings),
          Text("tick: ${tickCounter.value}"),
        ] +
        getSimulations();

    return Container(
      child: Column(
        children: cols,
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class PipelineSimulationView extends StatelessWidget {
  final PipelineSettings settings;
  final PipelineSimulation simulation;
  final AnimationStatus animationStatus;
  final int tick;

  const PipelineSimulationView({
    Key key,
    this.settings,
    this.simulation,
    this.animationStatus,
    this.tick,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget metricsView = Container();
    if (animationStatus == AnimationStatus.completed) {
      List<FrameMetrics> simulated =
          simulation.simulate(settings.totalNumTicks, settings);
      metricsView = MetricsView(simulated: simulated);
    }
    var children = <Widget>[
      Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          '${simulation.getName()}',
          style: TextStyle(fontSize: 20),
        ),
      ),
      metricsView,
      PipelineSimulator(
        settings: settings,
        tick: tick,
        sim: ProducerContinuationSimulation(),
      ),
    ];
    return Column(
      children: children,
    );
  }
}

class MetricsView extends StatelessWidget {
  const MetricsView({
    Key key,
    @required this.simulated,
  }) : super(key: key);

  final List<FrameMetrics> simulated;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 500,
      height: 300,
      child: new charts.ScatterPlotChart(
        <charts.Series<FrameMetrics, int>>[
          charts.Series<FrameMetrics, int>(
            id: 'Tablet',
            colorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
            domainFn: (FrameMetrics metrics, _) => metrics.buildStart,
            measureFn: (FrameMetrics metrics, _) =>
                (metrics.rasterEnd - metrics.buildStart),
            data: simulated
                .where((element) => element.rasterEnd != null)
                .toList(),
          )
        ],
        animate: false,
        defaultRenderer: new charts.PointRendererConfig(),
      ),
    );
  }
}

class SimulatorSettingsView extends StatelessWidget {
  final PipelineSettings settings;

  const SimulatorSettingsView({Key key, this.settings}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(children: <Widget>[
      Text("total ticks simulating: ${settings.totalNumTicks}"),
      Text("ticks to build: ${settings.ticksToBuild}"),
      Text("ticks to raster: ${settings.ticksToRaster}"),
      Text("ticks per vsync: ${settings.ticksPerVsync}"),
      Text("Blue is currently being rastered. Green is rastered."
          " Black is built not rastered. Red is being built."),
    ]);
  }
}

@immutable
class PipelineSimulator extends StatelessWidget {
  PipelineSimulator({
    Key key,
    @required this.settings,
    @required this.tick,
    @required this.sim,
  }) : super(key: key);

  final PipelineSettings settings;
  final int tick;
  final PipelineSimulation sim;

  @override
  Widget build(BuildContext context) {
    final List<FrameMetrics> frameMetrics = sim.simulate(tick, settings);
    final simmed = frameMetrics.map((FrameMetrics frameMetrics) {
      return PipelineItem(
        frameNum: frameMetrics.frameNum,
        metrics: frameMetrics,
      );
    }).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: simmed),
    );
  }
}

class PipelineItem extends StatelessWidget {
  final int frameNum;
  final FrameMetrics metrics;

  const PipelineItem({
    Key key,
    @required this.frameNum,
    @required this.metrics,
  }) : super(key: key);

  Widget displayTimes() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: <Widget>[
          Text("frameNum: $frameNum"),
          Text("buildStart: ${metrics.buildStart}"),
          Text("buildEnd: ${metrics.buildEnd}"),
          Text("rasterStart: ${metrics.rasterStart}"),
          Text("rasterEnd: ${metrics.rasterEnd}"),
        ],
      ),
    );
  }

  Color getColor() {
    switch (metrics.frameState) {
      case FrameState.BUILDING:
        return Colors.red;
      case FrameState.BUILT:
        return Colors.black;
      case FrameState.RASTERIZING:
        return Colors.blue;
      case FrameState.RASTERIZED:
        return Colors.green;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 100,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: <Widget>[
          displayTimes(),
          CustomPaint(
            painter: StrokedRectPainter(getColor()),
          )
        ],
      ),
    );
  }
}

class StrokedRectPainter extends CustomPainter {
  final Color color;

  StrokedRectPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint rectFill = Paint();
    rectFill.style = PaintingStyle.fill;
    rectFill.color = this.color.withAlpha(50);

    final Paint rectStroke = Paint();
    rectStroke.strokeWidth = 5.0;
    rectStroke.style = PaintingStyle.stroke;
    rectStroke.color = this.color;

    final Rect rectPath = Rect.fromLTWH(
      0.0,
      0.0,
      size.width,
      size.height,
    );

    canvas.drawRect(rectPath, rectFill);
    canvas.drawRect(rectPath, rectStroke);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
