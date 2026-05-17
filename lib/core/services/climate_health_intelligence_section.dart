import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'gemini_ai_service.dart';

final geminiServiceProvider = Provider((ref) => GeminiAIService());

/// A provider that fetches health worker data and generates a climate health insight.
final climateHealthInsightProvider =
    FutureProvider<ClimateHealthInsight>((ref) async {
  final aiService = ref.watch(geminiServiceProvider);

  // Fetch latest field reports submitted by health workers
  final snapshot = await FirebaseFirestore.instance
      .collection('environmental_indicators')
      .orderBy('timestamp', descending: true)
      .limit(10)
      .get();

  final indicators = snapshot.docs.map((doc) => doc.data()).toList();

  if (indicators.isEmpty) {
    throw Exception("No field reports available for analysis.");
  }

  return aiService.getClimateHealthInsight(
    indicators: indicators,
    country: "Nigeria", // This could be made dynamic via a settings provider
  );
});

class ClimateHealthIntelligenceSection extends ConsumerWidget {
  const ClimateHealthIntelligenceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color getRiskColor(String level) {
      switch (level.toLowerCase()) {
        case 'critical':
          return Colors.red.shade800;
        case 'high':
          return Colors.orange.shade800;
        case 'medium':
          return Colors.blue.shade800;
        case 'low':
          return Colors.green.shade800;
        default:
          return Colors.grey;
      }
    }

    final insightAsync = ref.watch(climateHealthInsightProvider);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined,
                    color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Climate Health Intelligence',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () => ref.invalidate(climateHealthInsightProvider),
                  tooltip: 'Refresh Intelligence',
                ),
              ],
            ),
            const SizedBox(height: 12),
            insightAsync.when(
              data: (insight) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: getRiskColor(insight.riskLevel).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: getRiskColor(insight.riskLevel)),
                    ),
                    child: Text(
                      'RISK LEVEL: ${insight.riskLevel.toUpperCase()}',
                      style: TextStyle(
                        color: getRiskColor(insight.riskLevel),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  MarkdownBody(
                    data: insight.summary,
                    selectable: true,
                  ),
                  if (insight.actionItems.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Actionable Readiness Checklist:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...insight.actionItems.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  size: 16, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Text(
                'Unable to load climate insights. Field surveillance is active.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
