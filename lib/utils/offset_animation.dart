

import 'package:flutter/material.dart';

class CustomOffsetAnimation extends StatefulWidget {
  final AnimationController controller;
  final Widget child;

  const CustomOffsetAnimation({Key key, this.controller, this.child})
      : super(key: key);

  @override
  _CustomOffsetAnimationState createState() => _CustomOffsetAnimationState();
}

class _CustomOffsetAnimationState extends State<CustomOffsetAnimation> {
  Tween<Offset> tweenOffset;
  Tween<double> tweenScale;

  Animation<double> animation;

  @override
  void initState() {
    tweenOffset = Tween<Offset>(
      begin: const Offset(0.0, 0.8),
      end: Offset.zero,
    );
    tweenScale = Tween<double>(begin: 0.3, end: 1.0);
    animation =
        CurvedAnimation(parent: widget.controller, curve: Curves.decelerate);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      child: widget.child,
      animation: widget.controller,
      builder: (BuildContext context, Widget child) {
        return FractionalTranslation(
          translation: tweenOffset.evaluate(animation),
          child: ClipRect(
            child: Transform.scale(
              scale: tweenScale.evaluate(animation),
              child: Opacity(
                child: child,
                opacity: animation.value,
              ),
            ),
          ),
        );
      },
    );
  }
}