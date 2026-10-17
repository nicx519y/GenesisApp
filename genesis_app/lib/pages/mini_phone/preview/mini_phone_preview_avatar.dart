import 'package:flutter/material.dart';
import '../../../ui/components/genesis_avatar.dart';
import 'mini_phone_demo_store.dart';

class MiniAvatar extends StatelessWidget {
  const MiniAvatar(this.person, {super.key, this.size = 40, this.borderRadius});
  final MiniDemoPerson person;
  final double size;
  final double? borderRadius;
  @override
  Widget build(BuildContext context) => person.role == 'live'
      ? GenesisAvatar(
          url: person.image,
          name: person.name,
          size: size,
          borderRadius: borderRadius ?? size / 2,
        )
      : ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius ?? size / 2),
          child: Image.asset(
            '$miniPhoneAssets${person.image}',
            width: size,
            height: size,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -.6),
            semanticLabel: person.name,
          ),
        );
}
