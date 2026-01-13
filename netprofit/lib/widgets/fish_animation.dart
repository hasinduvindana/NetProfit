import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class SwimmingFish extends StatefulWidget {
  final String fishImage;
  const SwimmingFish({required this.fishImage});

  @override
  _SwimmingFishState createState() => _SwimmingFishState();
}

class _SwimmingFishState extends State<SwimmingFish> {
  double left = 0;
  double top = 0;
  bool isFlipped = false;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    // Randomize initial position
    top = Random().nextInt(500).toDouble();
    left = Random().nextInt(300).toDouble();
    
    _timer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          double newLeft = Random().nextDouble() * MediaQuery.of(context).size.width;
          // If moving left, flip the image
          isFlipped = newLeft < left;
          left = newLeft;
          top = Random().nextDouble() * MediaQuery.of(context).size.height;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: Duration(seconds: 3),
      left: left,
      top: top,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(isFlipped ? 3.14159 : 0),
        child: Image.asset(widget.fishImage, width: 80),
      ),
    );
  }
}