import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/transaction.dart';
import '../models/user_profile.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double _selectedAmount = 500;
  bool _isProcessing = false;
  late Razorpay _razorpay;

  final List<double> _amounts = [100, 500, 1000, 2000, 5000];

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final firestore = Provider.of<FirestoreService>(context, listen: false);

    if (auth.currentUserId != null) {
      final transaction = AppTransaction(
        id: response.paymentId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        userId: auth.currentUserId!,
        amount: _selectedAmount,
        type: TransactionType.credit,
        category: TransactionCategory.wallet_recharge,
        timestamp: DateTime.now(),
        description: 'Wallet Recharge via Razorpay',
      );
      
      await firestore.processWalletTransaction(transaction);
      setState(() => _isProcessing = false);
      _showSuccessSheet();
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => _isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Failed: ${response.message}')));
  }

  void _handleRecharge() {
    setState(() => _isProcessing = true);
    var options = {
      'key': 'rzp_test_Rxpb0Qus5SVk7z', 
      'amount': (_selectedAmount * 100).toInt(),
      'name': 'LexAni',
      'description': 'Wallet Recharge',
      'timeout': 300,
      'prefill': {'contact': '', 'email': ''},
    };
    try {
      _razorpay.open(options);
    } catch (e) {
      setState(() => _isProcessing = false);
    }
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.checkCircle, color: Colors.green, size: 64),
            const SizedBox(height: 24),
            Text('₹${_selectedAmount.toInt()} Added!', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade900, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                child: const Text('DONE'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final firestore = Provider.of<FirestoreService>(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: const Text('My Wallet', style: TextStyle(fontWeight: FontWeight.bold)), elevation: 0),
      body: _isProcessing 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBalanceCard(auth.currentUserId!, firestore),
                const SizedBox(height: 32),
                const Text('RECHARGE WALLET', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _amounts.map((a) => _buildAmountChip(a)).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleRecharge,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade900, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                    child: const Text('RECHARGE NOW', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 40),
                const Text('RECENT TRANSACTIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                const SizedBox(height: 16),
                _buildTransactionList(auth.currentUserId!, firestore),
              ],
            ),
          ),
    );
  }

  Widget _buildBalanceCard(String uid, FirestoreService firestore) {
    return StreamBuilder<UserProfile?>(
      stream: firestore.streamUserProfile(uid),
      builder: (context, snapshot) {
        final balance = snapshot.data?.walletBalance ?? 0.0;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.blueGrey.shade800, Colors.blueGrey.shade900]),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Current Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Text('₹${balance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }
    );
  }

  Widget _buildAmountChip(double amount) {
    bool isSelected = _selectedAmount == amount;
    return GestureDetector(
      onTap: () => setState(() => _selectedAmount = amount),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amber : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.amber : Colors.grey.shade300),
        ),
        child: Text('₹${amount.toInt()}', style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.black : Colors.blueGrey)),
      ),
    );
  }

  Widget _buildTransactionList(String uid, FirestoreService firestore) {
    return StreamBuilder<List<AppTransaction>>(
      stream: firestore.streamUserTransactions(uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final transactions = snapshot.data!;
        if (transactions.isEmpty) return const Center(child: Text('No transactions yet.', style: TextStyle(color: Colors.grey)));

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: transactions.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final tx = transactions[index];
            final isCredit = tx.type == TransactionType.credit;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: isCredit ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(isCredit ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight, color: isCredit ? Colors.green : Colors.red, size: 16),
              ),
              title: Text(tx.category.name.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(tx.timestamp.toString().split('.')[0], style: const TextStyle(fontSize: 11)),
              trailing: Text('${isCredit ? "+" : "-"}₹${tx.amount}', style: TextStyle(fontWeight: FontWeight.bold, color: isCredit ? Colors.green : Colors.red, fontSize: 16)),
            );
          },
        );
      },
    );
  }
}
