import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/gems/gem_wallet_store.dart';
import '../../components/page_header.dart';
import '../../network/models/gem_home.dart';

class GemWalletPage extends StatefulWidget {
  const GemWalletPage({super.key, this.homeLoader, this.walletStore});

  final Future<GemHome> Function(BuildContext context)? homeLoader;
  final GemWalletStore? walletStore;

  @override
  State<GemWalletPage> createState() => _GemWalletPageState();
}

class _GemWalletPageState extends State<GemWalletPage>
    with WidgetsBindingObserver {
  Future<GemHome>? _homeFuture;
  GemHome? _home;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh(silent: _home != null);
    }
  }

  void _refresh({bool silent = false}) {
    final future = _loadHome();
    unawaited(_walletStore.refresh());
    setState(() {
      _error = null;
      _homeFuture = future;
      if (!silent) _home = null;
    });
    unawaited(
      future.then(
        (home) {
          if (!mounted) return;
          setState(() {
            _home = home;
            _error = null;
          });
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!mounted) return;
          setState(() {
            _error = error;
          });
        },
      ),
    );
  }

  Future<GemHome> _loadHome() {
    final loader = widget.homeLoader;
    if (loader != null) return loader(context);
    return AppServicesScope.read(context).api.v1.gem.home();
  }

  GemWalletStore get _walletStore =>
      widget.walletStore ?? AppServicesScope.read(context).gemWallet;

  @override
  Widget build(BuildContext context) {
    final home = _home;
    final walletStateListenable = _walletStore.state;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: GenesisBackAppBar(
        pageName: 'Buy Gems',
        onBack: () => Navigator.of(context).maybePop(),
        actions: [
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF333333),
              padding: const EdgeInsets.only(right: 20),
              textStyle: const TextStyle(
                fontSize: 16,
                height: 20 / 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Records'),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<GemHome>(
          future: _homeFuture,
          builder: (context, snapshot) {
            if (home == null &&
                snapshot.connectionState != ConnectionState.done) {
              return const _GemWalletLoading();
            }
            if (home == null && _error != null) {
              return _GemWalletError(onRetry: () => _refresh());
            }
            final data = home ?? snapshot.data;
            if (data == null) return const _GemWalletLoading();
            return RefreshIndicator(
              color: const Color(0xFFFF2D4F),
              onRefresh: () async {
                final future = _loadHome();
                unawaited(_walletStore.refresh());
                setState(() {
                  _homeFuture = future;
                  _error = null;
                });
                try {
                  final next = await future;
                  if (!mounted) return;
                  setState(() => _home = next);
                } catch (error) {
                  if (!mounted) return;
                  setState(() => _error = error);
                }
              },
              child: _GemWalletContent(
                home: data,
                walletStateListenable: walletStateListenable,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GemWalletContent extends StatelessWidget {
  const _GemWalletContent({
    required this.home,
    required this.walletStateListenable,
  });

  final GemHome home;
  final ValueListenable<GemWalletState> walletStateListenable;

  @override
  Widget build(BuildContext context) {
    final taskGroups = [...home.taskGroups]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        ValueListenableBuilder<GemWalletState>(
          valueListenable: walletStateListenable,
          builder: (context, walletState, _) {
            return _BalancePanel(balance: walletState.balance ?? 0);
          },
        ),
        const SizedBox(height: 20),
        if (home.products.isEmpty)
          const _GemEmptyPanel(message: 'No gem packs available.')
        else
          _ProductGrid(products: home.products),
        const SizedBox(height: 26),
        for (final group in taskGroups)
          if (group.tasks.isNotEmpty) ...[
            _TaskGroupSection(group: group),
            const SizedBox(height: 20),
          ],
      ],
    );
  }
}

class _BalancePanel extends StatelessWidget {
  const _BalancePanel({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 112,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Transform.translate(
          offset: const Offset(0, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SvgPicture.asset(
                    'assets/custom-icons/svg/ruby.svg',
                    width: 22,
                    height: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'My Balance',
                    style: TextStyle(
                      fontSize: 12,
                      height: 18 / 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                _formatInteger(balance),
                key: const ValueKey('gem-wallet-balance'),
                style: const TextStyle(
                  fontSize: 34,
                  height: 40 / 34,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF333333),
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.products});

  final List<GemProduct> products;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
        childAspectRatio: 105 / 142,
      ),
      itemBuilder: (context, index) {
        return _ProductCard(product: products[index], index: index);
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.index});

  final GemProduct product;
  final int index;

  @override
  Widget build(BuildContext context) {
    final tag = product.tagText.isNotEmpty
        ? product.tagText
        : index == 0
        ? 'New user'
        : '';
    const tagTextStyle = TextStyle(
      fontSize: 10,
      height: 1,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    );
    final tagPainter = TextPainter(
      text: TextSpan(text: tag, style: tagTextStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    final tagWidth = (tagPainter.width + 8).clamp(46.0, 86.0).toDouble();
    return Opacity(
      opacity: product.canPurchase ? 1 : 0.45,
      child: Container(
        clipBehavior: Clip.none,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEBEBEB)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (tag.isNotEmpty)
              Positioned(
                left: -1,
                top: -1,
                child: SizedBox(
                  width: tagWidth,
                  height: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4B6192),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(tag, maxLines: 1, style: tagTextStyle),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 30,
              left: 0,
              right: 0,
              child: Center(
                child: SvgPicture.asset(
                  'assets/custom-icons/svg/ruby.svg',
                  width: 24,
                  height: 24,
                ),
              ),
            ),
            Positioned(
              top: 60,
              left: 8,
              right: 8,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '+${_formatInteger(product.baseGems)}',
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 20 / 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
            ),
            if (product.bonusGems > 0)
              Positioned(
                top: 84,
                left: 8,
                right: 8,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '+${_formatInteger(product.bonusGems)} Bonus',
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 10,
                      height: 14 / 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF42C47),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              height: 24,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF42C47),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formatPrice(
                      product.priceAmount,
                      product.priceCurrencyCode,
                    ),
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 14 / 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskGroupSection extends StatelessWidget {
  const _TaskGroupSection({required this.group});

  final GemTaskGroup group;

  @override
  Widget build(BuildContext context) {
    final isJoinUs =
        group.groupCode == 'join_us' ||
        group.groupTitle.trim().toLowerCase() == 'join us';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.groupTitle,
          style: const TextStyle(
            fontSize: 14,
            height: 20 / 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 10),
        for (final task in group.tasks) ...[
          if (isJoinUs) _JoinUsTaskRow(task: task) else _TaskRow(task: task),
          SizedBox(height: isJoinUs ? 10 : 12),
        ],
      ],
    );
  }
}

class _JoinUsTaskRow extends StatelessWidget {
  const _JoinUsTaskRow({required this.task});

  final GemTask task;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/custom-icons/svg/discord-svgrepo-com.svg',
            width: 22,
            height: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                height: 18 / 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+${_formatInteger(task.rewardGems)}',
            maxLines: 1,
            style: const TextStyle(
              fontSize: 13,
              height: 18 / 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(width: 4),
          SvgPicture.asset(
            'assets/custom-icons/svg/ruby.svg',
            width: 14,
            height: 14,
          ),
          const SizedBox(width: 10),
          Container(
            width: 54,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF42C47),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              task.isClaimed ? 'Claimed' : task.actionText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                height: 14 / 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final GemTask task;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 16 / 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 14 / 10,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '+${_formatInteger(task.rewardGems)}',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 18 / 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(width: 2),
                    SvgPicture.asset(
                      'assets/custom-icons/svg/ruby.svg',
                      width: 14,
                      height: 14,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Container(
                  height: 19,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF42C47),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    task.isClaimed ? 'Claimed' : task.actionText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 13 / 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GemWalletLoading extends StatelessWidget {
  const _GemWalletLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Color(0xFFFF2D4F),
        ),
      ),
    );
  }
}

class _GemWalletError extends StatelessWidget {
  const _GemWalletError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Unable to load gems.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _GemEmptyPanel extends StatelessWidget {
  const _GemEmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 13,
          height: 18 / 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF999999),
        ),
      ),
    );
  }
}

String _formatInteger(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i += 1) {
    final remaining = text.length - i;
    buffer.write(text[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

String _formatPrice(int cents, String currencyCode) {
  final sign = switch (currencyCode.toUpperCase()) {
    'USD' => r'$',
    'HKD' => r'HK$',
    'TWD' => r'NT$',
    'CNY' => r'¥',
    'JPY' => r'¥',
    'KRW' => r'₩',
    'EUR' => r'€',
    'GBP' => r'£',
    _ => '${currencyCode.toUpperCase()} ',
  };
  final amount = cents / 100;
  var text = amount.toStringAsFixed(2);
  if (text.endsWith('0')) text = text.substring(0, text.length - 1);
  if (text.endsWith('.0')) text = text.substring(0, text.length - 2);
  return '$sign$text';
}
