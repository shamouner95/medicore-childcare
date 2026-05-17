import 'dart:convert';
import 'package:hospital_app/core/services/gemini_ai_service.dart';

/// A modular service for medical triage logic, supporting UNICEF's Open Source requirements.
/// This handles the logic for matching symptoms to hospital capabilities.
class TriageService {
  final GeminiAIService _aiService;

  TriageService(this._aiService);

  /// Performs an AI-driven triage to recommend the best facility.
  /// Modularized to allow for different AI backends or rule-based logic in the future.
  Future<MapTriageResponse> performSmartTriage({
    required String symptoms,
    required List<Map<String, dynamic>> facilities,
    List<Map<String, dynamic>>? indicators,
    required String country,
  }) async {
    // We delegate the heavy lifting to Gemini, but this wrapper allows for
    // additional pre-processing or local fallback logic (UNICEF Area 3: Readiness).
    if (symptoms.isEmpty) {
      return MapTriageResponse(
        recommendedFacilityId: facilities.isNotEmpty ? facilities.first['id'] : 'unknown',
        reasoning: "Please provide your symptoms so I can guide you to the most appropriate care facility.",
        urgencyContext: "Information Needed",
        travelAdvice: ["Enter symptoms for personalized guidance."],
      );
    }

    try {
      return await _aiService.getSmartTriage(
        symptoms: symptoms,
        facilities: facilities,
        indicators: indicators,
        country: country,
      );
    } catch (e) {
      // Offline/Error Fallback: Rule-based triage (UNICEF Area 4)
      return _performLocalTriage(symptoms, facilities, indicators);
    }
  }

  /// Rule-based triage for offline or low-connectivity scenarios.
  MapTriageResponse _performLocalTriage(
    String symptoms, 
    List<Map<String, dynamic>> facilities,
    List<Map<String, dynamic>>? indicators,
  ) {
    final score = calculateLocalRiskScore(symptoms);
    final isEmergency = score >= 3;
    
    // Simple logic: pick the first facility, but improve reasoning based on local indicators
    final recommended = facilities.isNotEmpty ? facilities.first : {'id': 'unknown', 'name': 'Nearest Health Center'};
    
    String reasoning = "Offline mode active. Based on your symptoms, we recommend ${recommended['name']}.";
    List<String> advice = ["Proceed to the nearest facility immediately if symptoms worsen."];

    if (indicators != null && indicators.isNotEmpty) {
      final relevantIndicator = indicators.first;
      reasoning += " Note: Field reports indicate a ${relevantIndicator['type']} in your region.";
      advice.add("Safety: Be aware of ${relevantIndicator['type']} risks during travel.");
    }

    return MapTriageResponse(
      recommendedFacilityId: recommended['id'],
      reasoning: reasoning,
      urgencyContext: isEmergency ? "High (Offline Analysis)" : "Standard (Offline Analysis)",
      travelAdvice: advice,
    );
  }

  /// Calculates a simple risk score locally without AI for low-connectivity environments.
  /// (UNICEF Area 4: Service Continuity).
  int calculateLocalRiskScore(String symptoms) {
    int score = 0;
    final criticalKeywords = ['breathing', 'chest pain', 'unconscious', 'bleeding', 'severe'];
    final moderateKeywords = ['fever', 'cough', 'vomiting', 'pain', 'diarrhea'];

    for (var word in criticalKeywords) {
      if (symptoms.toLowerCase().contains(word)) score += 3;
    }
    for (var word in moderateKeywords) {
      if (symptoms.toLowerCase().contains(word)) score += 1;
    }
    
    return score;
  }
}
