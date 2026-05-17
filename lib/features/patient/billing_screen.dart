import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/services/gemini_ai_service.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final GeminiAIService _aiService = GeminiAIService();
  bool _isAnalyzing = false;

  Future<void> _analyzeBill() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image == null) return;

    setState(() => _isAnalyzing = true);

    try {
      final bytes = await image.readAsBytes();
      final analysis = await _aiService.analyzeMedicalBill(bytes);
      
      // Persist analysis to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('bill_analyses')
            .add({
          'providerName': analysis.providerName,
          'totalAmount': analysis.totalAmount,
          'items': analysis.items.map((i) => {'description': i.description, 'amount': i.amount}).toList(),
          'costAnalysis': analysis.costAnalysis,
          'savingsAdvice': analysis.savingsAdvice,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        _showAnalysisDialog(analysis);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing bill: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _showAnalysisDialog(BillAnalysis analysis) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textDeep;

    showDialog(
      context: context,
      builder: (context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AppColors.primary, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'AI Bill Analysis',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: textColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    analysis.providerName,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...analysis.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(item.description, style: GoogleFonts.plusJakartaSans(color: textColor))),
                        Text('\$${item.amount.toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: textColor)),
                      ],
                    ),
                  )),
                  Divider(height: 32, color: textColor.withValues(alpha: 0.1)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Amount', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: textColor)),
                      Text('\$${analysis.totalAmount.toStringAsFixed(2)}', 
                        style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildAnalysisSection('Cost Analysis', analysis.costAnalysis, textColor),
                  const SizedBox(height: 16),
                  _buildAnalysisSection('Savings Advice', analysis.savingsAdvice, textColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisSection(String title, String content, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.5, color: textColor.withValues(alpha: 0.7)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: Stack(
        children: [
          // Background Orbs
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.05),
              ),
            ).animate().scale(duration: 2.seconds),
          ),
          
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(context, isDark),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBalanceCard(isDark),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Transactions',
                            style: GoogleFonts.playfairDisplay(
                              color: isDark ? Colors.white : AppColors.textDeep,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_isAnalyzing)
                            const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)
                          else
                            TextButton.icon(
                              onPressed: _analyzeBill,
                              icon: const Icon(Icons.auto_awesome, size: 18),
                              label: const Text('Analyze Bill'),
                              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTransactionList(isDark),
                      const SizedBox(height: 32),
                      Text(
                        'Saved Bill Analyses',
                        style: GoogleFonts.playfairDisplay(
                          color: isDark ? Colors.white : AppColors.textDeep,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSavedAnalyses(isDark),
                      const SizedBox(height: 32),
                      _buildPremiumActions(isDark),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      elevation: 0,
      centerTitle: false,
      leading: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.textDeep, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Text(
          'Financial Hub',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.textDeep,
            letterSpacing: -0.5,
          ),
        ),
        background: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.08),
                      isDark ? AppColors.backgroundDark : AppColors.background,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -30,
              top: -10,
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: 180,
                color: AppColors.primary.withValues(alpha: 0.03),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(bool isDark) {
    return GlassCard(
      borderRadius: 36,
      padding: const EdgeInsets.all(32),
      gradient: AppColors.organicGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'CURRENT BALANCE',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Icon(Icons.nfc_rounded, color: Colors.white54, size: 24),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '\$245.50',
            style: GoogleFonts.playfairDisplay(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              _buildPayButton(),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Due Date',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Oct 27, 2023',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOutBack);
  }

  Widget _buildPayButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        'Settle Now',
        style: GoogleFonts.plusJakartaSans(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildTransactionList(bool isDark) {
    final transactions = [
      {'title': 'General Consultation', 'date': 'Oct 24, 2023', 'amount': '-\$120.00', 'status': 'Completed', 'icon': Icons.medical_services_rounded},
      {'title': 'Laboratory Tests', 'date': 'Oct 22, 2023', 'amount': '-\$85.50', 'status': 'Pending', 'icon': Icons.science_rounded},
      {'title': 'Pharmacy - Meds', 'date': 'Oct 15, 2023', 'amount': '-\$40.00', 'status': 'Completed', 'icon': Icons.medication_rounded},
    ];

    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        final isCompleted = tx['status'] == 'Completed';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
                  ),
                  child: Icon(tx['icon'] as IconData, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx['title'] as String,
                        style: GoogleFonts.playfairDisplay(
                          color: isDark ? Colors.white : AppColors.textDeep,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        tx['date'] as String,
                        style: GoogleFonts.plusJakartaSans(
                          color: isDark ? Colors.white38 : Colors.black45,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      tx['amount'] as String,
                      style: GoogleFonts.plusJakartaSans(
                        color: isDark ? Colors.white : AppColors.textDeep,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCompleted ? AppColors.success.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tx['status'] as String,
                        style: GoogleFonts.plusJakartaSans(
                          color: isCompleted ? AppColors.success : AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1, curve: Curves.easeOutQuad);
      },
    );
  }

  Widget _buildSavedAnalyses(bool isDark) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('bill_analyses')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No saved analyses yet.',
              style: GoogleFonts.plusJakartaSans(color: Colors.white54),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final analysis = BillAnalysis(
              providerName: data['providerName'] ?? 'Unknown',
              totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
              items: (data['items'] as List?)?.map((i) => BillItem(description: i['description'], amount: i['amount'].toDouble())).toList() ?? [],
              costAnalysis: data['costAnalysis'] ?? '',
              savingsAdvice: data['savingsAdvice'] ?? '',
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => _showAnalysisDialog(analysis),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              analysis.providerName,
                              style: GoogleFonts.playfairDisplay(
                                color: isDark ? Colors.white : AppColors.textDeep,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '\$${analysis.totalAmount.toStringAsFixed(2)}',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: isDark ? Colors.white24 : Colors.black26),
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

  Widget _buildPremiumActions(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildActionTile(Icons.receipt_long_rounded, 'Insurance', isDark),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionTile(Icons.credit_card_rounded, 'Methods', isDark),
        ),
      ],
    );
  }

  Widget _buildActionTile(IconData icon, String label, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isDark ? Colors.white70 : AppColors.textDeep, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: isDark ? Colors.white : AppColors.textDeep,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
