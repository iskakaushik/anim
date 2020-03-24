import 'package:equatable/equatable.dart';

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
