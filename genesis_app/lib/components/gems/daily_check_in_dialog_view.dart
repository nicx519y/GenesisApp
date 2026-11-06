part of 'daily_check_in_dialog.dart';

class _DailyCheckInPanel extends StatelessWidget {
  const _DailyCheckInPanel({
    required this.title,
    required this.rewardGemsCent,
    required this.memberships,
    this.actions = const [],
  });

  final String title;
  final int rewardGemsCent;
  final List<MembershipType> memberships;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width * .7).clamp(0.0, 800.0);
    return GenesisDarkTheme(
      child: Center(
        child: SizedBox(
          width: width,
          child: GenesisActionBoxSurface(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: GenesisActionBox.defaultTitleHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: GenesisActionBox.actionTextStyle.copyWith(
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: GemTaskReward(
                              rewardGemsCent: rewardGemsCent,
                              showWholeReward: true,
                            ),
                          ),
                          if (memberships.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 4,
                              children: [
                                for (final tier in memberships)
                                  _DailyCheckInMembershipName(
                                    key: ValueKey(
                                      'daily-check-in-active-${tier.name}',
                                    ),
                                    tier: tier,
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  for (final action in actions) ...[
                    const GenesisActionBoxDivider(),
                    action,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyCheckInMembershipName extends StatelessWidget {
  const _DailyCheckInMembershipName({super.key, required this.tier});

  final MembershipType tier;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SvgPicture.asset(
        tier.crownAsset,
        width: 16,
        height: 12,
        excludeFromSemantics: true,
      ),
      const SizedBox(width: 6),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: ShaderMask(
            shaderCallback: tier.foreground.createShader,
            blendMode: BlendMode.srcIn,
            child: Text(
              tier.title(context),
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _DailyCheckInOffer extends StatelessWidget {
  const _DailyCheckInOffer({
    required this.tier,
    required this.amount,
    required this.onPressed,
  });

  final MembershipType tier;
  final int amount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tier.title(context),
    child: InkWell(
      key: ValueKey('daily-check-in-offer-${tier.name}'),
      onTap: onPressed,
      child: SizedBox(
        height: GenesisActionBox.defaultRowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.gemsDailyCheckInReward(
                      amount: amount % gemCentPerGem == 0
                          ? formatWholeGemCent(amount)
                          : formatGemCent(amount),
                    ),
                    maxLines: 1,
                    softWrap: false,
                    style: GenesisActionBox.actionTextStyle.copyWith(
                      color: GenesisColors.redSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  SvgPicture.asset(
                    gemIconAsset,
                    key: ValueKey(
                      'daily-check-in-subscription-gem-${tier.name}',
                    ),
                    width: gemSmallIconSize,
                    height: gemSmallIconSize,
                    excludeFromSemantics: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
