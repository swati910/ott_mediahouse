import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_house/app/core/utils/currency_formatter.dart';
import 'package:media_house/app/provider/themeProvider.dart';
import 'package:media_house/app/provider/wallet_provider.dart';
import 'package:media_house/data/models/response/production_house_wallet.dart';
import 'package:media_house/domain/entities/mediaHouse.dart';
import 'package:provider/provider.dart';

class WithdrawDialog extends StatefulWidget {
  const WithdrawDialog({
    super.key,
    required this.availableBalance,
    required this.mediaHouse,
  });

  final double availableBalance;
  final MediaHouse? mediaHouse;

  static Future<bool?> show(
    BuildContext context, {
    required double availableBalance,
    required MediaHouse? mediaHouse,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WithdrawDialog(
        availableBalance: availableBalance,
        mediaHouse: mediaHouse,
      ),
    );
  }

  @override
  State<WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends State<WithdrawDialog> {
  final _amountController = TextEditingController();
  final _remarksController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _inlineError;
  bool _isSubmitted = false;
  WalletWithdrawResult? _successResult;

  @override
  void dispose() {
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  String _maskAccountNumber(String? number) {
    if (number == null || number.trim().isEmpty) return 'Not Available';
    final cleaned = number.trim();
    if (cleaned.length <= 4) return '•••• $cleaned';
    final visible = cleaned.substring(cleaned.length - 4);
    return '•••• •••• $visible';
  }

  void _setPercentage(double fraction) {
    final amount = widget.availableBalance * fraction;
    // Two decimal places
    final formatted = amount.toStringAsFixed(2);
    _amountController.text = formatted;
    _validateInline(formatted);
  }

  void _validateInline(String val) {
    final text = val.trim();
    if (text.isEmpty) {
      setState(() => _inlineError = null);
      return;
    }
    final parsed = double.tryParse(text);
    if (parsed == null || parsed <= 0) {
      setState(() => _inlineError = 'Withdrawal amount must be greater than zero.');
    } else if (parsed > widget.availableBalance) {
      setState(() => _inlineError = 'Insufficient wallet balance.');
    } else {
      setState(() => _inlineError = null);
    }
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitted) return;

    final text = _amountController.text.trim();
    if (text.isEmpty) {
      setState(() => _inlineError = 'Please enter withdrawal amount.');
      return;
    }

    final amount = double.tryParse(text);
    if (amount == null || amount <= 0) {
      setState(() => _inlineError = 'Withdrawal amount must be greater than zero.');
      return;
    }

    if (amount > widget.availableBalance) {
      setState(() => _inlineError = 'Insufficient wallet balance.');
      return;
    }

    final media = widget.mediaHouse;
    final productionHouseId = media?.id ?? context.read<WalletProvider>().productionHouseId;

    if (productionHouseId == null || productionHouseId <= 0) {
      setState(() => _inlineError = 'Production house identification is missing.');
      return;
    }

    final hasBank = media?.bankAccountNumber != null &&
        media!.bankAccountNumber!.trim().isNotEmpty;

    if (!hasBank) {
      setState(() => _inlineError =
          'Bank account details are missing on your profile. Please update your profile before withdrawing.');
      return;
    }

    setState(() {
      _inlineError = null;
      _isSubmitted = true;
    });

    final request = WalletWithdrawRequest(
      productionHouseId: productionHouseId,
      amount: amount,
      bankAccountNumber: media.bankAccountNumber,
      bankIfsc: media.bankIfscNumber,
      bankName: media.bankName?.toString(),
      accountHolderName: media.accountHolderName?.toString() ??
          media.mediaHouseName?.toString(),
      remarks: _remarksController.text.trim().isNotEmpty
          ? _remarksController.text.trim()
          : 'Production house wallet withdrawal',
    );

    final provider = context.read<WalletProvider>();
    final success = await provider.withdraw(request);

    if (!mounted) return;

    if (success) {
      setState(() {
        _successResult = provider.lastWithdrawResult ??
            WalletWithdrawResult(
              withdrawalId: 'WTH-${DateTime.now().millisecondsSinceEpoch}',
              transactionId: 'TXN-${DateTime.now().millisecondsSinceEpoch}',
              amount: amount,
              status: 'PROCESSING',
              message: 'Withdrawal request submitted successfully.',
            );
      });
    } else {
      setState(() {
        _isSubmitted = false;
        _inlineError = provider.withdrawError ??
            'Withdrawal failed. Please check your details and retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().getTheme;
    final provider = context.watch<WalletProvider>();
    final isBusy = provider.isWithdrawing || _isSubmitted && _successResult == null;

    return Dialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _successResult != null
              ? _buildSuccessView(theme)
              : _buildFormView(theme, isBusy),
        ),
      ),
    );
  }

  Widget _buildFormView(ThemeData theme, bool isBusy) {
    final media = widget.mediaHouse;
    final hasBank = media?.bankAccountNumber != null &&
        media!.bankAccountNumber!.trim().isNotEmpty;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.account_balance_outlined,
                  color: theme.primaryColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Withdraw Amount',
                      style: TextStyle(
                        color: theme.canvasColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Transfer funds from wallet to registered bank',
                      style: TextStyle(
                        color: theme.canvasColor.withValues(alpha: .6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: isBusy ? null : () => Navigator.of(context).pop(false),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Available balance banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withValues(alpha: .3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Balance',
                      style: TextStyle(
                        color: theme.canvasColor.withValues(alpha: .65),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatCurrency(widget.availableBalance),
                      style: TextStyle(
                        color: theme.canvasColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        'Withdrawable',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Enter Amount Input
          Text(
            'Enter Withdrawal Amount',
            style: TextStyle(
              color: theme.canvasColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            enabled: !isBusy && widget.availableBalance > 0,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            onChanged: _validateInline,
            style: TextStyle(
              color: theme.canvasColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '₹',
                  style: TextStyle(
                    color: theme.canvasColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              hintText: '0.00',
              hintStyle: TextStyle(color: theme.canvasColor.withValues(alpha: .3)),
              filled: true,
              fillColor: theme.scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
              ),
              errorText: _inlineError,
            ),
          ),
          const SizedBox(height: 10),

          // Quick Percentage Chips
          if (widget.availableBalance > 0 && !isBusy)
            Wrap(
              spacing: 8,
              children: [
                _chip('25%', () => _setPercentage(0.25), theme),
                _chip('50%', () => _setPercentage(0.50), theme),
                _chip('75%', () => _setPercentage(0.75), theme),
                _chip('100% (Max)', () => _setPercentage(1.00), theme, isMax: true),
              ],
            ),
          const SizedBox(height: 18),

          // Bank Details Preview Card
          Text(
            'Bank Account Details',
            style: TextStyle(
              color: theme.canvasColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasBank
                    ? theme.dividerColor.withValues(alpha: .4)
                    : Colors.orange.withValues(alpha: .6),
              ),
            ),
            child: hasBank
                ? Column(
                    children: [
                      _bankRow(
                        'Account Holder',
                        media.accountHolderName?.toString() ??
                            media.mediaHouseName?.toString() ??
                            'N/A',
                        theme,
                      ),
                      const Divider(height: 14),
                      _bankRow(
                        'Bank Name',
                        media.bankName?.toString() ?? 'Registered Bank',
                        theme,
                      ),
                      const Divider(height: 14),
                      _bankRow(
                        'Account Number',
                        _maskAccountNumber(media.bankAccountNumber),
                        theme,
                        isAccount: true,
                      ),
                      const Divider(height: 14),
                      _bankRow(
                        'IFSC Code',
                        media.bankIfscNumber?.toString() ?? 'N/A',
                        theme,
                      ),
                      const Divider(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Status',
                            style: TextStyle(
                              color: theme.canvasColor.withValues(alpha: .6),
                              fontSize: 12,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: .15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Verified for Payout',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.orange, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No bank account linked. Please configure bank details in Profile.',
                          style: TextStyle(
                            color: theme.canvasColor.withValues(alpha: .8),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 22),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: isBusy ? null : () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: (!hasBank ||
                        widget.availableBalance <= 0 ||
                        isBusy ||
                        _inlineError != null)
                    ? null
                    : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: isBusy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Withdraw Amount',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(ThemeData theme) {
    final result = _successResult!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: .15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: Colors.green,
            size: 48,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Withdrawal Submitted',
          style: TextStyle(
            color: theme.canvasColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          result.message.isNotEmpty
              ? result.message
              : 'Your withdrawal request is being processed by the payout gateway.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.canvasColor.withValues(alpha: .65),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor.withValues(alpha: .3)),
          ),
          child: Column(
            children: [
              _bankRow('Withdrawal Amount', formatCurrency(result.amount), theme,
                  isBold: true),
              const Divider(height: 16),
              _bankRow('Transaction ID', result.transactionId, theme),
              const Divider(height: 16),
              _bankRow('Withdrawal ID', result.withdrawalId, theme),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Status',
                    style: TextStyle(
                      color: theme.canvasColor.withValues(alpha: .6),
                      fontSize: 12,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      result.status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, VoidCallback onTap, ThemeData theme,
      {bool isMax = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isMax
              ? theme.primaryColor.withValues(alpha: .15)
              : theme.scaffoldBackgroundColor,
          border: Border.all(
            color: isMax
                ? theme.primaryColor
                : theme.dividerColor.withValues(alpha: .4),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isMax ? theme.primaryColor : theme.canvasColor,
            fontSize: 11,
            fontWeight: isMax ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _bankRow(String label, String value, ThemeData theme,
      {bool isBold = false, bool isAccount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.canvasColor.withValues(alpha: .6),
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: theme.canvasColor,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: isBold ? 14 : 12,
            letterSpacing: isAccount ? 1.0 : 0,
          ),
        ),
      ],
    );
  }
}
