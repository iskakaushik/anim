import 'dart:collection';

import 'model.dart';

abstract class PipelineSimulation {
  String getName();

  List<FrameMetrics> simulate(int numTicksDone, PipelineSettings settings);
}

class DisplayTimer {
  final int ticksPerVsync;
  int _lastDisplayTime = 0;

  DisplayTimer(this.ticksPerVsync);

  int getNextDisplayTime(int tick) {
    int dt = _lastDisplayTime + ticksPerVsync;
    while (dt <= tick) {
      dt += ticksPerVsync;
    }
    _lastDisplayTime = dt;
    return dt;
  }
}

class KeepOneFrameSimulation extends PipelineSimulation {
  @override
  String getName() {
    return "KeepOneFrameSimulation";
  }

  @override
  List<FrameMetrics> simulate(int numTicksDone, PipelineSettings settings) {
    int frameNum = 1;
    final Queue<FrameMetrics> rastered = Queue();

    FrameMetrics beingBuilt;
    FrameMetrics doneBuilt;
    FrameMetrics beingRastered;
    final DisplayTimer dt = DisplayTimer(settings.ticksPerVsync);

    for (int i = 0; i < numTicksDone; i++) {
      if (beingBuilt != null) {
        // this frame has been built.
        if (i - beingBuilt.buildStart >= settings.ticksToBuild) {
          doneBuilt = beingBuilt.copyWith(
            frameState: FrameState.BUILT,
            buildEnd: i,
          );
          beingBuilt = null;
        }
      } else {
        // vsync so build!
        if (i % settings.ticksPerVsync == 0) {
          final int nextVsyncEnds = i + settings.ticksPerVsync;
          beingBuilt = FrameMetrics(
            frameNum: frameNum++,
            buildStart: i,
            targetTime: nextVsyncEnds,
            frameState: FrameState.BUILDING,
          );
        }
      }

      // gpu thread
      if (beingRastered != null) {
        if (i - beingRastered.rasterStart >= settings.ticksToRaster) {
          rastered.add(beingRastered.copyWith(
            rasterEnd: i,
            frameState: FrameState.RASTERIZED,
            displayTime: dt.getNextDisplayTime(i),
          ));
          beingRastered = null;
        }
      } else if (doneBuilt != null) {
        beingRastered = doneBuilt.copyWith(
          rasterStart: i,
          frameState: FrameState.RASTERIZING,
        );
        doneBuilt = null;
      }
    }

    if (beingRastered != null) {
      rastered.add(beingRastered);
    }
    if (doneBuilt != null) {
      rastered.add(doneBuilt);
    }
    if (beingBuilt != null) {
      rastered.add(beingBuilt);
    }

    return rastered.toList();
  }
}

class ProducerContinuationSimulation extends PipelineSimulation {
  @override
  List<FrameMetrics> simulate(int numTicksDone, PipelineSettings settings) {
    // definitely not the most efficient way.
    final Queue<FrameMetrics> builtNotRastered = Queue();
    final Queue<FrameMetrics> rastered = Queue();

    FrameMetrics uiThreadFrame;
    FrameMetrics gpuThreadFrame;

    int frameNum = 1;
    final DisplayTimer dt = DisplayTimer(settings.ticksPerVsync);

    for (int i = 0; i < numTicksDone; i++) {
      /// ui thread actions
      if (uiThreadFrame != null) {
        if (i - uiThreadFrame.buildStart >= settings.ticksToBuild) {
          builtNotRastered.add(uiThreadFrame.copyWith(
            buildEnd: i,
            frameState: FrameState.BUILT,
          ));
          uiThreadFrame = null;
        }
      } else {
        if (i % settings.ticksPerVsync == 0 &&
            builtNotRastered.length < settings.pipelineDepth) {
          final int nextVsyncEnds = i + settings.ticksPerVsync;
          uiThreadFrame = FrameMetrics(
            frameNum: frameNum++,
            buildStart: i,
            targetTime: nextVsyncEnds,
            frameState: FrameState.BUILDING,
          );
        }
      }

      // gpu thread actions
      if (gpuThreadFrame != null) {
        if (i - gpuThreadFrame.rasterStart >= settings.ticksToRaster) {
          rastered.add(gpuThreadFrame.copyWith(
            rasterEnd: i,
            displayTime: dt.getNextDisplayTime(i),
            frameState: FrameState.RASTERIZED,
          ));
          gpuThreadFrame = null;
        }
      } else if (builtNotRastered.isNotEmpty) {
        FrameMetrics front = builtNotRastered.first;
        builtNotRastered.removeFirst();
        gpuThreadFrame = front.copyWith(
          rasterStart: i,
          frameState: FrameState.RASTERIZING,
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

    return rastered.toList();
  }

  @override
  String getName() {
    return "ProducerContinuationSimulator";
  }
}
