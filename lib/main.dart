import 'dart:collection';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'input_form.dart';

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

const Map<String, int> kDefaultSettings = <String, int>{
  'animationDurationInSecs': 10,
  'totalNumTicks': 800,
  'pipelineDepth': 2,
  'ticksToBuild': 30,
  'ticksToRaster': 100,
  'ticksPerVsync': 60
};

class PipelineSettings extends Equatable {
  final int animationDurationInSecs;
  final int totalNumTicks;
  final int pipelineDepth;
  final int ticksToBuild;
  final int ticksToRaster;
  final int ticksPerVsync;

  PipelineSettings({
    this.animationDurationInSecs,
    this.totalNumTicks,
    this.pipelineDepth,
    this.ticksToBuild,
    this.ticksToRaster,
    this.ticksPerVsync,
  });

  factory PipelineSettings.fromMap(Map<String, int> map) {
    return PipelineSettings(
      animationDurationInSecs: map['animationDurationInSecs'],
      totalNumTicks: map['totalNumTicks'],
      pipelineDepth: map['pipelineDepth'],
      ticksToBuild: map['ticksToBuild'],
      ticksToRaster: map['ticksToRaster'],
      ticksPerVsync: map['ticksPerVsync'],
    );
  }

  @override
  List<Object> get props => [
        animationDurationInSecs,
        totalNumTicks,
        pipelineDepth,
        ticksToBuild,
        ticksToRaster,
        ticksPerVsync
      ];
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
        if (i - uiThreadFrame.buildStart >= settings.ticksToBuild) {
          builtNotRastered.add(PipelineItem(
            frameNum: uiThreadFrame.frameNum,
            color: Colors.black,
            buildStart: uiThreadFrame.buildStart,
            buildEnd: i,
          ));
          uiThreadFrame = null;
        }
      } else {
        if (i % settings.ticksPerVsync == 0 &&
            builtNotRastered.length < settings.pipelineDepth) {
          uiThreadFrame = PipelineItem(
            frameNum: frameNum++,
            color: Colors.red,
            buildStart: i,
          );
        }
      }

      // gpu thread actions
      if (gpuThreadFrame != null) {
        if (i - gpuThreadFrame.rasterStart >= settings.ticksToRaster) {
          rastered.add(PipelineItem(
            frameNum: gpuThreadFrame.frameNum,
            color: Colors.green,
            buildStart: gpuThreadFrame.buildStart,
            buildEnd: gpuThreadFrame.buildEnd,
            rasterStart: gpuThreadFrame.rasterStart,
            rasterEnd: i,
          ));
          gpuThreadFrame = null;
        }
      } else if (builtNotRastered.isNotEmpty) {
        PipelineItem front = builtNotRastered.first;
        builtNotRastered.removeFirst();
        gpuThreadFrame = PipelineItem(
          frameNum: front.frameNum,
          color: Colors.blue,
          buildStart: front.buildStart,
          buildEnd: front.buildEnd,
          rasterStart: i,
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
  final int buildStart;
  final int buildEnd;
  final int rasterStart;
  final int rasterEnd;

  const PipelineItem({
    Key key,
    this.color = Colors.blue,
    @required this.frameNum,
    this.buildStart = kInvalid,
    this.buildEnd = kInvalid,
    this.rasterStart = kInvalid,
    this.rasterEnd = kInvalid,
  }) : super(key: key);

  Widget displayTimes() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: <Widget>[
          Text("frameNum: $frameNum"),
          Text("buildStart: $buildStart"),
          Text("buildEnd: $buildEnd"),
          Text("rasterStart: $rasterStart"),
          Text("rasterEnd: $rasterEnd"),
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
