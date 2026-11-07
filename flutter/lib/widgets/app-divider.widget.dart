import 'package:flutter/widgets.dart';

import '../constants/app-sizes.dart';
import '../constants/app-colors.dart';

/// Hairline horizontal divider placed between tiles inside cards.
class AppDivider extends StatelessWidget {
  final double indent;

  const AppDivider({
    super.key,
    this.indent = AppSizes.p16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.borderWidthThin,
      margin: EdgeInsets.only(left: this.indent),
      color : AppColors.divider(context),
    );
  }
}
