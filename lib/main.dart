import 'dart:collection';

import 'package:flutter/material.dart';

const kAnimationDurationSeconds = 10;
const kNumTicks = 800;
const kPipelineDepth = 5;

const kTicksToBuild = 30;
const kTicksToRaster = 95;
const kTicksPerVsync = 60;

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
      home: Material(child: PipelineSimatorAnimation()),
    );
  }
}

class PipelineSimatorAnimation extends StatefulWidget {
  @override
  _PipelineSimatorAnimationState createState() =>
      _PipelineSimatorAnimationState();
}

class _PipelineSimatorAnimationState extends State<PipelineSimatorAnimation>
    with SingleTickerProviderStateMixin {
  Animation<int> tickCounter;
  AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      duration: const Duration(seconds: kAnimationDurationSeconds),
      vsync: this,
    );
    tickCounter = IntTween(begin: 0, end: kNumTicks).animate(controller)
      ..addListener(() {
        setState(() {
          // The state that has changed here is the animation object’s value.
        });
      });
    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: <Widget>[
          Text("ticks to build: $kTicksToBuild"),
          Text("ticks to raster: $kTicksToRaster"),
          Text("ticks per vsync: $kTicksPerVsync"),
          Text("tick: ${tickCounter.value}"),
          Text(
              "green is rastered. black is built not rastered. red is being built."),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: PipelineSimulator(
              depth: kPipelineDepth,
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
    @required this.depth,
    @required this.tick,
  }) : super(key: key);

  final int depth;
  final int tick;

  @override
  Widget build(BuildContext context) {
    /// current producer continuation strategy.

    // definitely not the most efficient way.
    final Queue<PipelineItem> builtNotRastered = Queue();
    final Queue<PipelineItem> rastered = Queue();

    PipelineItem uiThreadFrame;
    int frameNum = 1;

    for (int i = 0; i < tick; i++) {
      /// ui thread actions
      if (uiThreadFrame != null) {
        if (i - uiThreadFrame.buildStart >= kTicksToBuild) {
          builtNotRastered.add(PipelineItem(
            frameNum: uiThreadFrame.frameNum,
            color: Colors.black,
            buildStart: uiThreadFrame.buildStart,
            buildEnd: i,
          ));
          uiThreadFrame = null;
        }
      } else {
        if (i % kTicksPerVsync == 0 && builtNotRastered.length < depth) {
          uiThreadFrame = PipelineItem(
            frameNum: frameNum++,
            color: Colors.red,
            buildStart: i,
          );
        }
      }

      // gpu thread actions
      if (builtNotRastered.isNotEmpty) {
        PipelineItem front = builtNotRastered.first;
        if (i - front.buildEnd >= kTicksToRaster) {
          builtNotRastered.removeFirst();
          rastered.add(PipelineItem(
            frameNum: front.frameNum,
            color: Colors.green,
            buildStart: front.buildStart,
            buildEnd: front.buildEnd,
            rasterStart: i - kTicksToRaster,
            rasterEnd: i,
          ));
        }
      }
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
