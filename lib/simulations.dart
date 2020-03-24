import 'dart:collection';

import 'model.dart';

abstract class PipelineSimulator {
  List<FrameMetrics> simulate(int numTicksDone, PipelineSettings settings);
}

class ProducerContinuationSimulator extends PipelineSimulator {
  @override
  List<FrameMetrics> simulate(int numTicksDone, PipelineSettings settings) {
    // definitely not the most efficient way.
    final Queue<FrameMetrics> builtNotRastered = Queue();
    final Queue<FrameMetrics> rastered = Queue();

    FrameMetrics uiThreadFrame;
    FrameMetrics gpuThreadFrame;

    int frameNum = 1;

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
          uiThreadFrame = FrameMetrics(
            frameNum: frameNum++,
            buildStart: i,
            frameState: FrameState.BUILDING,
          );
        }
      }

      // gpu thread actions
      if (gpuThreadFrame != null) {
        if (i - gpuThreadFrame.rasterStart >= settings.ticksToRaster) {
          rastered.add(gpuThreadFrame.copyWith(
            rasterEnd: i,
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
}
