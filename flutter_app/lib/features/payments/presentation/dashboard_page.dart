import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config.dart';
import '../../../core/exceptions/api_exception.dart';
import '../../../core/utils/currency_options.dart';
import '../models/money.dart';
import '../models/payment_collection.dart';
import '../models/payment_request.dart';
import '../models/payment_response.dart';
import '../models/payment_record.dart';
import 'payments_providers.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  final _formKey = GlobalKey<FormState>();
  final _transactionIdController = TextEditingController();
  final _merchantIdController = TextEditingController();
  final _customerIdController = TextEditingController();
  final _amountMinorController = TextEditingController();
  final _currencyController = TextEditingController(text: 'INR');
  final _paymentMethodController = TextEditingController(text: 'card');
  final _referenceController = TextEditingController();

  int _selectedIndex = 0;
  static const List<_NavItem> _navItems = [
    _NavItem(
      label: 'Overview',
      description: 'Mission control for every transaction',
      icon: Icons.dashboard_customize_rounded,
    ),
    _NavItem(
      label: 'New Payment',
      description: 'Compose and dispatch a charge',
      icon: Icons.add_card_rounded,
    ),
    _NavItem(
      label: 'Payment History',
      description: 'Inspect ledger outcomes and statuses',
      icon: Icons.receipt_long_rounded,
    ),
  ];

  bool _isSubmitting = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _currencyController.addListener(_handleFormChange);
    _amountMinorController.addListener(_handleFormChange);
    _refreshTimer = Timer.periodic(paymentsAutoRefreshInterval, (_) {
      if (mounted) {
        ref.invalidate(paymentsListProvider);
      }
    });
  }

  @override
  void dispose() {
    _transactionIdController.dispose();
    _merchantIdController.dispose();
    _customerIdController.dispose();
    _amountMinorController.removeListener(_handleFormChange);
    _amountMinorController.dispose();
    _currencyController.removeListener(_handleFormChange);
    _currencyController.dispose();
    _paymentMethodController.dispose();
    _referenceController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _handleFormChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleNavigationTap(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  String get _amountHelperText {
    final currency = _currencyController.text.trim().toUpperCase();
    final amountMinor = int.tryParse(_amountMinorController.text.trim());
    if (amountMinor == null || amountMinor <= 0) {
      return 'Enter amount in minor units (e.g. cents, paise).';
    }
    final formatter = NumberFormat.currency(locale: 'en_US', name: currency);
    return 'Approx. ${formatter.format(amountMinor / 100)}';
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final request = PaymentRequest(
      transactionId: _transactionIdController.text.trim(),
      merchantId: _merchantIdController.text.trim(),
      customerId: _customerIdController.text.trim(),
      amount: Money(
        currency: _currencyController.text.trim().toUpperCase(),
        valueMinor: int.parse(_amountMinorController.text.trim()),
      ),
      paymentMethod: _paymentMethodController.text.trim(),
      reference: _referenceController.text.trim().isEmpty
          ? null
          : _referenceController.text.trim(),
    );

    setState(() => _isSubmitting = true);

    try {
      final response = await ref.read(createPaymentProvider(request).future);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Payment submitted · ${response.transactionId} (${response.status})',
          ),
          backgroundColor: Colors.green.shade600,
        ),
      );
      _retainDefaultsAndReset();
    } on ApiException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Something went wrong: $error'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _retainDefaultsAndReset() {
    final currency = _currencyController.text;
    final method = _paymentMethodController.text;
    _formKey.currentState?.reset();
    _transactionIdController.clear();
    _merchantIdController.clear();
    _customerIdController.clear();
    _amountMinorController.clear();
    _referenceController.clear();
    _currencyController.text = currency.isEmpty ? 'INR' : currency;
    _paymentMethodController.text = method.isEmpty ? 'card' : method;
  }

  @override
  Widget build(BuildContext context) {
    final paymentsAsync = ref.watch(paymentsListProvider);
    final statusFilter = ref.watch(statusFilterProvider);
    final lastSubmission = ref.watch(lastSubmissionProvider);
    final media = MediaQuery.of(context);
    final isDesktop = media.size.width >= 1100;

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: isDesktop
          ? null
          : _LedgerDrawer(
              items: _navItems,
              selectedIndex: _selectedIndex,
              onSelect: (index) => _handleNavigationTap(index),
            ),
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xF00B1120),
        toolbarHeight: 76,
        leadingWidth: isDesktop ? 220 : null,
        leading: isDesktop
            ? const Padding(
                padding: EdgeInsets.only(left: 32),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _BrandPill(),
                ),
              )
            : Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu_rounded, size: 28),
                  color: Colors.white,
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'Open navigation',
                ),
              ),
        titleSpacing: isDesktop ? 0 : 12,
        title: Text(
          'LedgerStream Control Center',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
        ),
        actions: const [
          _LiveStatusIndicator(),
          SizedBox(width: 24),
        ],
      ),
      body: Stack(
        children: [
          const _GradientBackground(),
          const _AmbientGlowOverlay(),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showSidebar = constraints.maxWidth >= 1080;
                final horizontalPadding = showSidebar ? 36.0 : 20.0;

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    24,
                    horizontalPadding,
                    32,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showSidebar)
                        _SidebarNavigation(
                          items: _navItems,
                          selectedIndex: _selectedIndex,
                          onSelect: _handleNavigationTap,
                        ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: SingleChildScrollView(
                            key: ValueKey(_selectedIndex),
                            padding: EdgeInsets.symmetric(
                              horizontal: showSidebar ? 16 : 0,
                              vertical: 8,
                            ),
                            child: _buildSectionContent(
                              context: context,
                              showSidebar: showSidebar,
                              paymentsAsync: paymentsAsync,
                              statusFilter: statusFilter,
                              lastSubmission: lastSubmission,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContent({
    required BuildContext context,
    required bool showSidebar,
    required AsyncValue<PaymentCollection> paymentsAsync,
    required String statusFilter,
    required PaymentResponse? lastSubmission,
  }) {
    switch (_selectedIndex) {
      case 0:
        return _OverviewSection(
          payments: paymentsAsync,
          lastSubmission: lastSubmission,
          onNavigate: (index) => _handleNavigationTap(index),
        );
      case 1:
        return _NewPaymentSection(
          formKey: _formKey,
          transactionIdController: _transactionIdController,
          merchantIdController: _merchantIdController,
          customerIdController: _customerIdController,
          amountMinorController: _amountMinorController,
          currencyController: _currencyController,
          paymentMethodController: _paymentMethodController,
          referenceController: _referenceController,
          amountHelperText: _amountHelperText,
          isSubmitting: _isSubmitting,
          onSubmit: _submit,
          lastSubmission: lastSubmission,
          tightLayout: !showSidebar,
        );
      case 2:
      default:
        return _PaymentHistorySection(
          payments: paymentsAsync,
          statusFilter: statusFilter,
          onSelectStatus: (value) =>
              ref.read(statusFilterProvider.notifier).state = value,
          onRefresh: () => ref.invalidate(paymentsListProvider),
          tightLayout: !showSidebar,
        );
    }
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.description,
    required this.icon,
  });

  final String label;
  final String description;
  final IconData icon;
}

class _BrandPill extends StatelessWidget {
  const _BrandPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x996EE7B7)),
        color: const Color(0x2E047857),
      ),
      child: const Text(
        'LEDGERSTREAM',
        style: TextStyle(
          letterSpacing: 6,
          fontWeight: FontWeight.w600,
          color: Color(0xFFCCFBEF),
        ),
        softWrap: false,
        maxLines: 1,
        overflow: TextOverflow.fade,
      ),
    );
  }
}

class _LiveStatusIndicator extends StatelessWidget {
  const _LiveStatusIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x3322C55E),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x6634D399)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.podcasts_rounded, size: 16, color: Color(0xFF34D399)),
            SizedBox(width: 6),
            Text(
              'Live backend',
              style: TextStyle(
                color: Color(0xFFCCFBEF),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LedgerDrawer extends StatelessWidget {
  const _LedgerDrawer({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0B1120),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: _BrandPill(),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isActive = index == selectedIndex;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelect(index);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0x3317253B) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive
                                ? const Color(0xFF38BDF8)
                                : const Color(0x332E3A5C),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.icon,
                              color: const Color(0xFF9BD5FF),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.label,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.description,
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemCount: items.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarNavigation extends StatelessWidget {
  const _SidebarNavigation({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 28),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0x33111B2E),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x332E3A5C)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 40,
            offset: const Offset(0, 28),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Navigate',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 18),
          ...List.generate(items.length, (index) {
            final item = items[index];
            final isActive = index == selectedIndex;
            return Padding(
              padding: EdgeInsets.only(bottom: index == items.length - 1 ? 0 : 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => onSelect(index),
                  splashColor: const Color(0xFF38BDF8).withOpacity(0.14),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: isActive ? const Color(0x331C253B) : Colors.transparent,
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFF38BDF8)
                            : const Color(0x332E3A5C),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          color: isActive
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.description,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({
    required this.payments,
    required this.lastSubmission,
    required this.onNavigate,
  });

  final AsyncValue<PaymentCollection> payments;
  final PaymentResponse? lastSubmission;
  final ValueChanged<int> onNavigate;

  static const Set<String> _successStates = {
    'CONFIRMED',
    'SUCCESS',
    'COMPLETED',
  };
  static const Set<String> _declineStates = {
    'DECLINED',
    'FAILED',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _HeaderSection(),
        const SizedBox(height: 32),
        payments.when(
          data: (collection) {
            var confirmed = 0;
            var declined = 0;
            for (final record in collection.items) {
              final status = record.status.toUpperCase();
              if (_successStates.contains(status)) {
                confirmed++;
              } else if (_declineStates.contains(status)) {
                declined++;
              }
            }
            final total = collection.items.length;
            final pending = total - confirmed - declined;
            final successRate = total == 0 ? 0.0 : confirmed / total;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatCard(
                  title: 'Total processed',
                  primaryText: total.toString(),
                  caption: 'Lifetime transactions observed in this client.',
                  icon: Icons.data_thresholding_rounded,
                  background: const Color(0x3321364A),
                  accent: const Color(0xFF38BDF8),
                ),
                _StatCard(
                  title: 'Confirmed',
                  primaryText: confirmed.toString(),
                  caption: 'Successful or completed payments.',
                  icon: Icons.verified_rounded,
                  background: const Color(0x3322453F),
                  accent: const Color(0xFF34D399),
                ),
                _StatCard(
                  title: 'Requires attention',
                  primaryText: (declined + pending).toString(),
                  caption: 'Declines and pending decisions to revisit.',
                  icon: Icons.warning_amber_rounded,
                  background: const Color(0x33B45309),
                  accent: const Color(0xFFFBBF24),
                ),
                _StatCard(
                  title: 'Success rate',
                  primaryText: total == 0
                      ? '–'
                      : '${(successRate * 100).clamp(0, 100).toStringAsFixed(1)}%',
                  caption: 'Rolling success ratio across captured records.',
                  icon: Icons.show_chart_rounded,
                  background: const Color(0x3321364A),
                  accent: const Color(0xFF60A5FA),
                ),
              ],
            );
          },
          loading: () => Wrap(
            spacing: 16,
            runSpacing: 16,
            children: List.generate(
              3,
              (_) => Container(
                width: 240,
                height: 130,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
              ),
            ),
          ),
          error: (error, _) => Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0x33B91C1C),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x55FCA5A5)),
            ),
            child: Text(
              'Unable to summarise payments: $error',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFFCA5A5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _ActionCard(
              title: 'Collect a payment',
              description: 'Craft a payment request and send it to the gateway.',
              icon: Icons.add_circle_rounded,
              background: const Color(0x3322C55E),
              borderColor: const Color(0x5534D399),
              onTap: () => onNavigate(1),
            ),
            _ActionCard(
              title: 'Review history',
              description: 'Filter, monitor, and export the latest payment records.',
              icon: Icons.history_rounded,
              background: const Color(0x3321554B),
              borderColor: const Color(0x5538BDF8),
              onTap: () => onNavigate(2),
            ),
            if (lastSubmission != null)
              _LastSubmissionCard(lastSubmission: lastSubmission!),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.primaryText,
    required this.caption,
    required this.icon,
    required this.background,
    required this.accent,
  });

  final String title;
  final String primaryText;
  final String caption;
  final IconData icon;
  final Color background;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withOpacity(0.42)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 30,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: 14),
          Text(
            primaryText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFCBD5F5),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            caption,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              height: 1.4,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.background,
    required this.borderColor,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color background;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        splashColor: borderColor.withOpacity(0.25),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: borderColor, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFFCBD5F5),
                        height: 1.5,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LastSubmissionCard extends StatelessWidget {
  const _LastSubmissionCard({required this.lastSubmission});

  final PaymentResponse lastSubmission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 320,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0x33065846),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x5534D399)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.26),
            blurRadius: 28,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last submission',
            style: theme.textTheme.labelLarge?.copyWith(
              color: const Color(0xFFCCFBEF),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            lastSubmission.transactionId,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Status · ${lastSubmission.status.toUpperCase()}',
            style: const TextStyle(
              color: Color(0xFF34D399),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (lastSubmission.reason != null) ...[
            const SizedBox(height: 6),
            Text(
              lastSubmission.reason!,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Text(
            subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withOpacity(0.74),
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

class _NewPaymentSection extends StatelessWidget {
  const _NewPaymentSection({
    required this.formKey,
    required this.transactionIdController,
    required this.merchantIdController,
    required this.customerIdController,
    required this.amountMinorController,
    required this.currencyController,
    required this.paymentMethodController,
    required this.referenceController,
    required this.amountHelperText,
    required this.isSubmitting,
    required this.onSubmit,
    required this.lastSubmission,
    required this.tightLayout,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController transactionIdController;
  final TextEditingController merchantIdController;
  final TextEditingController customerIdController;
  final TextEditingController amountMinorController;
  final TextEditingController currencyController;
  final TextEditingController paymentMethodController;
  final TextEditingController referenceController;
  final String amountHelperText;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final PaymentResponse? lastSubmission;
  final bool tightLayout;

  @override
  Widget build(BuildContext context) {
    final maxWidth = tightLayout ? 560.0 : 420.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          title: 'Submit a payment request',
          subtitle: 'Fill in the ledger metadata and dispatch the payment into the distributed gateway.',
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: _PaymentFormCard(
              formKey: formKey,
              transactionIdController: transactionIdController,
              merchantIdController: merchantIdController,
              customerIdController: customerIdController,
              amountMinorController: amountMinorController,
              currencyController: currencyController,
              paymentMethodController: paymentMethodController,
              referenceController: referenceController,
              amountHelperText: amountHelperText,
              isSubmitting: isSubmitting,
              onSubmit: onSubmit,
              lastSubmission: lastSubmission,
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentHistorySection extends StatelessWidget {
  const _PaymentHistorySection({
    required this.payments,
    required this.statusFilter,
    required this.onSelectStatus,
    required this.onRefresh,
    required this.tightLayout,
  });

  final AsyncValue<PaymentCollection> payments;
  final String statusFilter;
  final ValueChanged<String> onSelectStatus;
  final VoidCallback onRefresh;
  final bool tightLayout;

  @override
  Widget build(BuildContext context) {
    final maxWidth = tightLayout ? 880.0 : 980.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          title: 'Payment history',
          subtitle: 'Monitor transaction state changes, fraud outcomes, and ledger updates in real time.',
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: _PaymentsListCard(
              payments: payments,
              statusFilter: statusFilter,
              onSelectStatus: onSelectStatus,
              onRefresh: onRefresh,
            ),
          ),
        ),
      ],
    );
  }
}

class _GradientBackground extends StatelessWidget {
  const _GradientBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF09090B), Color(0xFF111827), Color(0xFF0B1120)],
        ),
      ),
    );
  }
}

class _AmbientGlowOverlay extends StatelessWidget {
  const _AmbientGlowOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.2, -0.92),
          radius: 1.2,
          colors: [
            const Color(0xFF34D399).withOpacity(0.32),
            Colors.transparent,
          ],
          stops: const [0.0, 1.0],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.9, 1.1),
            radius: 1.0,
            colors: [
              const Color(0xFF60A5FA).withOpacity(0.22),
              Colors.transparent,
            ],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF6EE7B7).withOpacity(0.6)),
            color: const Color(0xFF047857).withOpacity(0.18),
          ),
          child: Text(
            'LEDGERSTREAM',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 6,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFCCFBEF),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Distributed payments control center for your payment gateway',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(
            'Launch transactions, monitor fraud outcomes, and follow the full ledger lifecycle. This portal connects directly to the FastAPI gateway and distributed services running in your stack.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withOpacity(0.82),
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentFormCard extends StatelessWidget {
  const _PaymentFormCard({
    required this.formKey,
    required this.transactionIdController,
    required this.merchantIdController,
    required this.customerIdController,
    required this.amountMinorController,
    required this.currencyController,
    required this.paymentMethodController,
    required this.referenceController,
    required this.amountHelperText,
    required this.isSubmitting,
    required this.onSubmit,
    required this.lastSubmission,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController transactionIdController;
  final TextEditingController merchantIdController;
  final TextEditingController customerIdController;
  final TextEditingController amountMinorController;
  final TextEditingController currencyController;
  final TextEditingController paymentMethodController;
  final TextEditingController referenceController;
  final String amountHelperText;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final PaymentResponse? lastSubmission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme.apply(
      bodyColor: const Color(0xFF0F172A),
      displayColor: const Color(0xFF0F172A),
    );

    return Theme(
      data: theme.copyWith(
        textTheme: textTheme,
        iconTheme: theme.iconTheme.copyWith(color: const Color(0xFF6B7280)),
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: Colors.white,
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
          labelStyle: const TextStyle(color: Color(0xFF4B5563)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.6),
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF1F2937).withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.28),
              blurRadius: 46,
              offset: const Offset(0, 28),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Submit a payment',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Provide the transaction details and let the fraud service evaluate the risk.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 28),
                _LedgerTextField(
                  controller: transactionIdController,
                  label: 'Transaction ID',
                  hintText: 'txn-123456',
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Transaction ID is required';
                    if (text.length < 8 || text.length > 64) {
                      return 'Use between 8 and 64 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _LedgerTextField(
                  controller: merchantIdController,
                  label: 'Merchant ID',
                  hintText: 'merchant-001',
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Merchant ID is required';
                    if (text.length < 4) return 'Minimum 4 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _LedgerTextField(
                  controller: customerIdController,
                  label: 'Customer ID',
                  hintText: 'customer-001',
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Customer ID is required';
                    if (text.length < 4) return 'Minimum 4 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _LedgerTextField(
                        controller: amountMinorController,
                        label: 'Amount (minor units)',
                        hintText: '2500',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        helperText: amountHelperText,
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return 'Amount is required';
                          final amount = int.tryParse(text);
                          if (amount == null || amount <= 0) {
                            return 'Enter a positive integer';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _LedgerTextField(
                        controller: currencyController,
                        label: 'Currency',
                        hintText: 'INR',
                        textCapitalization: TextCapitalization.characters,
                        validator: (value) {
                          final text = value?.trim().toUpperCase() ?? '';
                          if (text.isEmpty) return 'Currency is required';
                          if (text.length != 3) return 'Use 3-letter ISO code';
                          return null;
                        },
                        suffix: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: supportedCurrencies.contains(
                              currencyController.text.trim().toUpperCase(),
                            )
                                ? currencyController.text.trim().toUpperCase()
                                : null,
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF0F172A)),
                            items: supportedCurrencies
                                .map(
                                  (code) => DropdownMenuItem<String>(
                                    value: code,
                                    child: Text(
                                      code,
                                      style: const TextStyle(color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                )
                                .toList(),
                            dropdownColor: Colors.white,
                            onChanged: (value) {
                              if (value != null) {
                                currencyController.text = value;
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _LedgerTextField(
                  controller: paymentMethodController,
                  label: 'Payment Method',
                  hintText: 'card',
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Payment method is required';
                    if (text.length < 2) return 'Minimum 2 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _LedgerTextField(
                  controller: referenceController,
                  label: 'Reference (optional)',
                  hintText: 'order-123',
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.length > 128) {
                      return 'Reference must be <= 128 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : onSubmit,
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Submit payment'),
                  ),
                ),
                if (lastSubmission != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF065F46),
                      border: Border.all(color: const Color(0xFF34D399).withOpacity(0.6)),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 24,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Text(
                      'Last submission — ${lastSubmission!.transactionId} · ${lastSubmission!.status}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentsListCard extends StatelessWidget {
  const _PaymentsListCard({
    required this.payments,
    required this.statusFilter,
    required this.onSelectStatus,
    required this.onRefresh,
  });

  final AsyncValue<PaymentCollection> payments;
  final String statusFilter;
  final ValueChanged<String> onSelectStatus;
  final VoidCallback onRefresh;

  static const _statusOptions = <String>['all', 'pending', 'confirmed', 'declined', 'retry'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceTextTheme = theme.textTheme.apply(
      bodyColor: const Color(0xFF0F172A),
      displayColor: const Color(0xFF0F172A),
    );

    return Theme(
      data: theme.copyWith(textTheme: surfaceTextTheme),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFF1F2937).withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.24),
              blurRadius: 48,
              offset: const Offset(0, 32),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent payments',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Monitor processing outcomes and fraud decisions.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFCBD5F5).withOpacity(0.4)),
                  ),
                  child: IconButton(
                    tooltip: 'Refresh payments',
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                    color: const Color(0xFF0F172A),
                    splashRadius: 22,
                    padding: const EdgeInsets.all(10),
                    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _statusOptions.map((option) {
                final isActive = option == statusFilter;
                return ChoiceChip(
                  label: Text(option == 'all' ? 'All' : option),
                  selected: isActive,
                  onSelected: (_) => onSelectStatus(option),
                  selectedColor: const Color(0xFF0F172A),
                  labelStyle: TextStyle(
                    color: isActive ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: const Color(0xFFF8FAFC),
                  shape: const StadiumBorder(),
                  side: BorderSide(
                    color: isActive
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFFE2E8F0),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            payments.when(
              data: (collection) {
                if (collection.items.isEmpty) {
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      'No payments captured yet. Submit a transaction to see it here.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  );
                }

                return _PaymentsList(collection: collection);
              },
              loading: () => const _PaymentsSkeleton(),
              error: (error, stackTrace) => _PaymentsError(
                error: error,
                onRetry: onRefresh,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentsSkeleton extends StatelessWidget {
  const _PaymentsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(5, (index) => index).map((_) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                height: 16,
                width: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Container(
                height: 16,
                width: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Container(
                height: 16,
                width: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _PaymentsError extends StatelessWidget {
  const _PaymentsError({
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Unable to load payments',
            style: TextStyle(
              color: Color(0xFFB91C1C),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: const TextStyle(color: Color(0xFFB91C1C)),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _PaymentsList extends StatelessWidget {
  const _PaymentsList({required this.collection});

  final PaymentCollection collection;
  static const double _compactBreakpoint = 520;

  void _showPaymentDetail(BuildContext context, PaymentRecord record, String amount) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xCC020617),
      barrierLabel: 'Payment detail',
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => _PaymentDetailOverlay(
        record: record,
        formattedAmount: amount,
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = Curves.easeOutCubic.transform(animation.value);
        return Opacity(
          opacity: animation.value,
          child: Transform.scale(
            scale: 0.92 + 0.08 * curved,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final numberFormatters = <String, NumberFormat>{};

    NumberFormat formatterFor(String currency) {
      return numberFormatters.putIfAbsent(
        currency,
        () => NumberFormat.currency(locale: 'en_US', name: currency),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < _compactBreakpoint;
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: collection.items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final record = collection.items[index];
            final formatter = formatterFor(record.amount.currency);
            final amount = formatter.format(record.amount.valueMinor / 100);
            final updatedAt = record.updatedAt ?? record.createdAt;
            final timestamp = updatedAt != null
                ? DateFormat.yMMMd().add_jm().format(updatedAt)
                : 'Timestamp unavailable';

            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                splashColor: const Color(0xFF38BDF8).withOpacity(0.12),
                onTap: () => _showPaymentDetail(context, record, amount),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: EdgeInsets.all(isCompact ? 18 : 22),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.96),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 30,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: isCompact
                      ? _CompactPaymentTile(
                          record: record,
                          amount: amount,
                          timestamp: timestamp,
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          record.transactionId,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: Color(0xFF0F172A),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      _StatusBadge(status: record.status),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 6,
                                    children: [
                                      _MetaChip(label: 'Merchant', value: record.merchantId),
                                      _MetaChip(label: 'Customer', value: record.customerId),
                                      _MetaChip(label: 'Method', value: record.paymentMethod),
                                      _MetaChip(label: 'Updated', value: timestamp),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  amount,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: Color(0xFF94A3B8),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CompactPaymentTile extends StatelessWidget {
  const _CompactPaymentTile({
    required this.record,
    required this.amount,
    required this.timestamp,
  });

  final PaymentRecord record;
  final String amount;
  final String timestamp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.transactionId,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    amount,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _StatusBadge(status: record.status),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            _MetaChip(label: 'Merchant', value: record.merchantId),
            _MetaChip(label: 'Customer', value: record.customerId),
            _MetaChip(label: 'Method', value: record.paymentMethod),
            _MetaChip(label: 'Updated', value: timestamp),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Tap for details',
              style: TextStyle(
                color: Color(0xFF475569),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ],
    );
  }
}

class _PaymentDetailOverlay extends StatelessWidget {
  const _PaymentDetailOverlay({
    required this.record,
    required this.formattedAmount,
  });

  final PaymentRecord record;
  final String formattedAmount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final created = record.createdAt != null
        ? DateFormat.yMMMd().add_jm().format(record.createdAt!)
        : 'Unknown';
    final updated = record.updatedAt != null
        ? DateFormat.yMMMd().add_jm().format(record.updatedAt!)
        : 'Pending';

    Widget metaLine(String label, String value) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFFBAE6FD),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xCC0F172A),
                        Color(0x990B1120),
                      ],
                    ),
                    border: Border.all(color: const Color(0x44FFFFFF)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 46,
                        offset: const Offset(0, 28),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      record.transactionId,
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _StatusBadge(status: record.status),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                                tooltip: 'Close',
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          Text(
                            formattedAmount,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Payment method · ${record.paymentMethod.toUpperCase()}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFFCBD5F5),
                            ),
                          ),
                          if (record.reason != null && record.reason!.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0x3322564B),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0x4434D399)),
                              ),
                              child: Text(
                                record.reason!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFFCCFBEF),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 24,
                            runSpacing: 16,
                            children: [
                              metaLine('Merchant', record.merchantId),
                              metaLine('Customer', record.customerId),
                              metaLine('Transaction created', created),
                              metaLine('Last updated', updated),
                            ],
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF60A5FA),
                                side: const BorderSide(color: Color(0xFF60A5FA)),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                              label: const Text('Back to history'),
                            ),
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
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();
    Color background;
    Color borderColor;
    Color foreground;

    switch (normalized) {
      case 'CONFIRMED':
      case 'SUCCESS':
      case 'COMPLETED':
        background = const Color(0x3310B981);
        borderColor = const Color(0x6610B981);
        foreground = const Color(0xFF6EE7B7);
        break;
      case 'DECLINED':
      case 'FAILED':
        background = const Color(0x33F87171);
        borderColor = const Color(0x66F87171);
        foreground = const Color(0xFFFCA5A5);
        break;
      case 'RETRY':
      case 'PENDING':
      default:
        background = const Color(0x3338BDF8);
        borderColor = const Color(0x6638BDF8);
        foreground = const Color(0xFF93C5FD);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        normalized,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFCBD5F5).withOpacity(0.4)),
      ),
      child: Text(
        '$label · $value',
        style: const TextStyle(
          color: Color(0xFF475569),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _LedgerTextField extends StatelessWidget {
  const _LedgerTextField({
    required this.controller,
    required this.label,
    this.hintText,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.helperText,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final String? helperText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
      cursorColor: const Color(0xFF38BDF8),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        helperStyle: const TextStyle(color: Color(0xFF64748B)),
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
      textCapitalization: textCapitalization,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: TextInputAction.next,
    );
  }
}
