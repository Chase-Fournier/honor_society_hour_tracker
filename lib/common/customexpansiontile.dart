import 'package:flutter/material.dart';

class CustomExpansionTile extends ExpansionTile {
  const CustomExpansionTile({
    super.key,
    required super.title,
    required super.children,
    super.initiallyExpanded,
    super.tilePadding,
  });

  @override
  Widget _buildChildren(BuildContext context, Widget? child,
      AnimationController? controller, bool expanded) {
    return Container(
      child: Column(
        children: children,
      ),
    );
  }
}
