import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:nasa_spaceapp_challange_pireus/colors.dart';

/// Widget that is displaying during loading something
///
/// * Optional [textVisible] - display text under indicator (default visible)
/// * Optional [size] - size of loading indicator (default 50)
// ignore: must_be_immutable
class MyLoading extends StatelessWidget {
  MyLoading({super.key, this.textVisible, this.size});

  /// Optional: display text under indicator (default visible)
  bool? textVisible;

  /// Optional:  size of loading indicator (default 50)
  double? size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        /// Loading indicator
        SpinKitWave(
          color: MyColors.primary,
          size: size ?? 50,
        ),

        /// Spacer
        SizedBox(
          height: (textVisible ?? true) ? 15 : 0,
        ),

        /// Loading text
        Visibility(
          visible: textVisible ?? true,
          child: const Text(
            "Loading",
          ),
        )
      ],
    );
  }
}
