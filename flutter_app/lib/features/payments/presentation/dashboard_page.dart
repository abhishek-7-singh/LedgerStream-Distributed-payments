import 'dart:async';

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const _GradientBackground(),
          const _AmbientGlowOverlay(),
          Positioned.fill(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 1024;
                    final horizontalPadding = isWide ? 48.0 : 24.0;

                    final formSection = SizedBox(
                      width: isWide ? 360 : double.infinity,
                      child: _PaymentFormCard(
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
                      ),
                    );

                    final paymentsSection = _PaymentsListCard(
                      payments: paymentsAsync,
                      statusFilter: statusFilter,
                      onSelectStatus: (value) =>
                          ref.read(statusFilterProvider.notifier).state = value,
                      onRefresh: () => ref.invalidate(paymentsListProvider),
                    );

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _HeaderSection(),
                              const SizedBox(height: 32),
                              if (isWide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    formSection,
                                    const SizedBox(width: 28),
                                    Expanded(child: paymentsSection),
                                  ],
                                )
                              else
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    formSection,
                                    const SizedBox(height: 28),
                                    paymentsSection,
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    final numberFormatters = <String, NumberFormat>{};

    NumberFormat formatterFor(String currency) {
      return numberFormatters.putIfAbsent(
        currency,
        () => NumberFormat.currency(locale: 'en_US', name: currency),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: collection.items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final record = collection.items[index];
        final formatter = formatterFor(record.amount.currency);
        final amount = formatter.format(record.amount.valueMinor / 100);
        final updatedAt = record.updatedAt != null
            ? DateFormat.yMMMd().add_jm().format(record.updatedAt!)
            : 'Unknown';

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            splashColor: const Color(0xFF38BDF8).withOpacity(0.12),
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.14),
                    blurRadius: 36,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Row(
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
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            _MetaChip(label: 'Merchant', value: record.merchantId),
                            _MetaChip(label: 'Customer', value: record.customerId),
                            _MetaChip(label: 'Updated', value: updatedAt),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    amount,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
