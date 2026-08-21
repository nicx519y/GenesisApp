import 'package:flutter/material.dart';

import '../tokens/genesis_radii.dart';
import '../tokens/genesis_spacing.dart';
import 'genesis_section_header.dart';
import 'genesis_surface.dart';

/// A page section made from the shared section header and surface primitives.
class GenesisSectionPanel extends StatelessWidget {
  const GenesisSectionPanel({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.leading,
    this.trailing,
    this.compactHeader = false,
    this.surfaceVariant = GenesisSurfaceVariant.raised,
    this.padding = const EdgeInsets.all(GenesisSpacing.page),
    this.borderRadius = GenesisRadii.card,
    this.border,
    this.headerToContentSpacing = GenesisSpacing.xl,
    this.margin = EdgeInsets.zero,
  });

  final String title;
  final Widget child;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool compactHeader;
  final GenesisSurfaceVariant surfaceVariant;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final BoxBorder? border;
  final double headerToContentSpacing;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GenesisSectionHeader(
            title: title,
            subtitle: subtitle,
            leading: leading,
            trailing: trailing,
            compact: compactHeader,
          ),
          SizedBox(height: headerToContentSpacing),
          GenesisSurface(
            variant: surfaceVariant,
            padding: padding,
            borderRadius: borderRadius,
            border: border,
            child: child,
          ),
        ],
      ),
    );
  }
}
