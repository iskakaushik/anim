import 'dart:collection';

import 'package:flutter/material.dart';
import 'input_form.dart';
import 'model.dart';

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

  @override
  Widget build(BuildContext context) {
    final PipelineSettings settings = widget.settings;
    return Container(
      child: Column(
        children: <Widget>[
          Text("total ticks simulating: ${settings.totalNumTicks}"),
          Text("ticks to build: ${settings.ticksToBuild}"),
          Text("ticks to raster: ${settings.ticksToRaster}"),
          Text("ticks per vsync: ${settings.ticksPerVsync}"),
          Text("tick: ${tickCounter.value}"),
          Text("blue is currently being rastered. green is rastered."
              " black is built not rastered. red is being built."),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: PipelineSimulator(
              settings: settings,
              tick: tickCounter.value,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

@immutable
class PipelineSimulator extends StatelessWidget {
  PipelineSimulator({
    Key key,
    @required this.settings,
    @required this.tick,
  }) : super(key: key);

  final PipelineSettings settings;
  final int tick;

  @override
  Widget build(BuildContext context) {
    /// current producer continuation strategy.

    // definitely not the most efficient way.
    final Queue<PipelineItem> builtNotRastered = Queue();
    final Queue<PipelineItem> rastered = Queue();

    PipelineItem uiThreadFrame;
    PipelineItem gpuThreadFrame;

    int frameNum = 1;

    for (int i = 0; i < tick; i++) {
      /// ui thread actions
      if (uiThreadFrame != null) {
        if (i - uiThreadFrame.metrics.buildStart >= settings.ticksToBuild) {
          builtNotRastered.add(PipelineItem(
            frameNum: uiThreadFrame.frameNum,
            color: Colors.black,
            metrics: uiThreadFrame.metrics.copyWith(buildEnd: i),
          ));
          uiThreadFrame = null;
        }
      } else {
        if (i % settings.ticksPerVsync == 0 &&
            builtNotRastered.length < settings.pipelineDepth) {
          uiThreadFrame = PipelineItem(
            frameNum: frameNum++,
            color: Colors.red,
            metrics: PipelineMetrics(buildStart: i),
          );
        }
      }

      // gpu thread actions
      if (gpuThreadFrame != null) {
        if (i - gpuThreadFrame.metrics.rasterStart >= settings.ticksToRaster) {
          rastered.add(PipelineItem(
            frameNum: gpuThreadFrame.frameNum,
            color: Colors.green,
            metrics: gpuThreadFrame.metrics.copyWith(rasterEnd: i),
          ));
          gpuThreadFrame = null;
        }
      } else if (builtNotRastered.isNotEmpty) {
        PipelineItem front = builtNotRastered.first;
        builtNotRastered.removeFirst();
        gpuThreadFrame = PipelineItem(
          frameNum: front.frameNum,
          color: Colors.blue,
          metrics: front.metrics.copyWith(rasterStart: i),
        );
      }
    }

    if (gpuThreadFrame != null) {
      rastered.add(gpuThreadFrame);
    }
    rastered.addAll(builtNotRastered);
    if (uiThreadFrame != null) {
      rastered.add(uiThreadFrame);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: rastered.toList(),
      ),
    );
  }
}

const kInvalid = -1;

class PipelineItem extends StatelessWidget {
  final Color color;
  final int frameNum;
  final PipelineMetrics metrics;

  const PipelineItem({
    Key key,
    this.color = Colors.blue,
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
            painter: StrokedRectPainter(this.color),
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
