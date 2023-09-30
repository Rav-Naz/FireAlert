import 'package:flutter/cupertino.dart';

/// Widget that switching between [firstChild] and [secondChild] with animation
/// depending on state of [isFirst] (true=[firstChild], false=[secondChild])
///
/// * **[firstChild]** - Widget displaying when [isFirst] value is true
/// * **[secondChild]** - Widget displaying when [isFirst] value is false
/// * **[isFirst]** - Variable that controls visibility of both widgets
class MyAnimatedSwitcher extends StatelessWidget {
  const MyAnimatedSwitcher(
      {super.key,
      required this.firstChild,
      required this.secondChild,
      required this.isFirst});

  /// Widget displaying when [isFirst] value is true
  final Widget firstChild;

  /// Widget displaying when [isFirst] value is false
  final Widget secondChild;

  /// Variable that controls visibility of both widgets
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(

        /// Default durations of animations
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 300),
        switchInCurve: Curves.linear,
        switchOutCurve: Curves.linear,
        child: isFirst ? firstChild : secondChild);
  }
}
