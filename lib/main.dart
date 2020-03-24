import 'package:flutter/material.dart';

void main() {
  runApp(FrameRenderHelperApp());
}

class FrameRenderHelperApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: FrameRenderHelper(title: 'Flutter Demo Home Page'),
    );
  }
}

class FrameRenderHelper extends StatelessWidget {
  FrameRenderHelper({Key key, this.title}) : super(key: key);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title);
  }
}
