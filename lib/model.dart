import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

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

enum FrameState { BUILDING, BUILT, RASTERIZING, RASTERIZED }

class FrameMetrics {
  final int frameNum;
  final int buildStart;
  final int buildEnd;
  final int rasterStart;
  final int rasterEnd;
  final FrameState frameState;

  FrameMetrics({
    @required this.frameNum,
    this.buildStart,
    this.buildEnd,
    this.rasterStart,
    this.rasterEnd,
    this.frameState,
  });

  FrameMetrics copyWith({
    int buildStart,
    int buildEnd,
    int rasterStart,
    int rasterEnd,
    FrameState frameState,
  }) {
    int bs = buildStart ?? this.buildStart;
    int be = buildEnd ?? this.buildEnd;
    int rs = rasterStart ?? this.rasterStart;
    int re = rasterEnd ?? this.rasterEnd;
    FrameState fs = frameState ?? this.frameState;
    return FrameMetrics(
      frameNum: frameNum,
      buildStart: bs,
      buildEnd: be,
      rasterStart: rs,
      rasterEnd: re,
      frameState: fs,
    );
  }
}
