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
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 312),
        child: GenesisActionBoxSurface(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              actions.isEmpty ? 24 : 20,
              16,
              actions.isEmpty ? 24 : 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: GenesisColors.darkTextPrimary,
                    fontSize: 15,
                    height: 21 / 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        gemIconAsset,
                        key: const ValueKey('gem-task-reward-icon'),
                        width: 25,
                        height: 39,
                        excludeFromSemantics: true,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '+${formatWholeGemCent(rewardGemsCent)}',
                        key: const ValueKey('gem-task-reward-value'),
                        style: const TextStyle(
                          color: GenesisColors.darkTextPrimary,
                          fontSize: 38,
                          height: 44 / 38,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.38,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                if (memberships.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        for (final tier in memberships)
                          _DailyCheckInMembershipName(
                            key: ValueKey('daily-check-in-active-${tier.name}'),
                            tier: tier,
                            compact: true,
                          ),
                      ],
                    ),
                  ),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  ...actions,
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _DailyCheckInMembershipName extends StatelessWidget {
  const _DailyCheckInMembershipName({
    super.key,
    required this.tier,
    this.compact = false,
  });

  final MembershipType tier;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SvgPicture.asset(
        tier.crownAsset,
        width: compact ? 16 : 20,
        height: compact ? 12 : 14,
        excludeFromSemantics: true,
      ),
      SizedBox(width: compact ? 6 : 9),
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
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 13 : 14,
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
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: tier.cardBackground(MemoryMembershipSurfaceKind.profile),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: tier.cardSheen),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: ValueKey('daily-check-in-offer-${tier.name}'),
              onTap: onPressed,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Row(
                      children: [
                        Expanded(
                          child: _DailyCheckInMembershipName(tier: tier),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * .46,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: Text(
                                    context.l10n.gemsDailyCheckInReward(
                                      amount: amount % gemCentPerGem == 0
                                          ? formatWholeGemCent(amount)
                                          : formatGemCent(amount),
                                    ),
                                    maxLines: 1,
                                    softWrap: false,
                                    style: const TextStyle(
                                      color: GenesisColors.darkTextPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              SvgPicture.asset(
                                gemIconAsset,
                                key: ValueKey(
                                  'daily-check-in-subscription-gem-${tier.name}',
                                ),
                                width: 10,
                                height: 16,
                                excludeFromSemantics: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: tier.bodyColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
