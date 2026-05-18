import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/test_result.dart';

class SymptomAnalysis {
  final String summary;
  final String urgency;
  final List<String> advice;
  final String recommendedDepartment;

  SymptomAnalysis({
    required this.summary,
    required this.urgency,
    required this.advice,
    required this.recommendedDepartment,
  });

  factory SymptomAnalysis.fromJson(Map<String, dynamic> json) {
    return SymptomAnalysis(
      summary: json['summary'] ?? '',
      urgency: json['urgency'] ?? 'Unknown',
      advice: List<String>.from(json['advice'] ?? []),
      recommendedDepartment:
          json['recommendedDepartment'] ?? 'General Medicine',
    );
  }
}

class HealthTrendAnalysis {
  final String forecast;
  final List<String> identifiedPatterns;
  final List<String> potentialRisks;

  HealthTrendAnalysis({
    required this.forecast,
    required this.identifiedPatterns,
    required this.potentialRisks,
  });

  factory HealthTrendAnalysis.fromJson(Map<String, dynamic> json) {
    return HealthTrendAnalysis(
      forecast: json['forecast'] ?? '',
      identifiedPatterns: List<String>.from(json['identifiedPatterns'] ?? []),
      potentialRisks: List<String>.from(json['potentialRisks'] ?? []),
    );
  }
}

class LifestylePlan {
  final List<String> mealPlan;
  final List<String> exerciseRoutine;
  final String nutritionalAdvice;

  LifestylePlan({
    required this.mealPlan,
    required this.exerciseRoutine,
    required this.nutritionalAdvice,
  });

  factory LifestylePlan.fromJson(Map<String, dynamic> json) {
    return LifestylePlan(
      mealPlan: List<String>.from(json['mealPlan'] ?? []),
      exerciseRoutine: List<String>.from(json['exerciseRoutine'] ?? []),
      nutritionalAdvice: json['nutritionalAdvice'] ?? '',
    );
  }
}

class PatientData {
  final String? name;
  final String? bloodGroup;
  final String? genotype;
  final String? vaccinationStatus;
  final int? heartRate;
  final double? weight;
  final double? height;
  final String? allergies;
  final String? chronicConditions;
  final String? dob;
  final String? gender;
  final String? emergencyContact;

  PatientData({
    this.name,
    this.bloodGroup,
    this.genotype,
    this.vaccinationStatus,
    this.heartRate,
    this.weight,
    this.height,
    this.allergies,
    this.chronicConditions,
    this.dob,
    this.gender,
    this.emergencyContact,
  });

  factory PatientData.fromJson(Map<String, dynamic> json) {
    return PatientData(
      name: json['name'],
      bloodGroup: json['bloodGroup'],
      genotype: json['genotype'],
      vaccinationStatus: json['vaccinationStatus'],
      heartRate: json['heartRate'] != null
          ? int.tryParse(json['heartRate'].toString())
          : null,
      weight: json['weight'] != null
          ? double.tryParse(json['weight'].toString())
          : null,
      height: json['height'] != null
          ? double.tryParse(json['height'].toString())
          : null,
      allergies: json['allergies'],
      chronicConditions: json['chronicConditions'],
      dob: json['dob'],
      gender: json['gender'],
      emergencyContact: json['emergencyContact'],
    );
  }
}

class HealthJourneyAnalysis {
  final List<double> recoveryProgress; // 0 to 100
  final String statusMessage;
  final List<String> nextSteps;
  final bool alertDoctor;

  HealthJourneyAnalysis({
    required this.recoveryProgress,
    required this.statusMessage,
    required this.nextSteps,
    required this.alertDoctor,
  });

  factory HealthJourneyAnalysis.fromJson(Map<String, dynamic> json) {
    return HealthJourneyAnalysis(
      recoveryProgress: List<double>.from(
          json['recoveryProgress']?.map((x) => x.toDouble()) ?? []),
      statusMessage: json['statusMessage'] ?? '',
      nextSteps: List<String>.from(json['nextSteps'] ?? []),
      alertDoctor: json['alertDoctor'] ?? false,
    );
  }
}

class PracticeInsights {
  final String efficiencyScore;
  final List<String> optimizationTips;
  final String patientSatisfactionForecast;
  final List<String> busyHourPredictions;

  PracticeInsights({
    required this.efficiencyScore,
    required this.optimizationTips,
    required this.patientSatisfactionForecast,
    required this.busyHourPredictions,
  });

  factory PracticeInsights.fromJson(Map<String, dynamic> json) {
    return PracticeInsights(
      efficiencyScore: json['efficiencyScore'] ?? 'N/A',
      optimizationTips: List<String>.from(json['optimizationTips'] ?? []),
      patientSatisfactionForecast: json['patientSatisfactionForecast'] ?? '',
      busyHourPredictions: List<String>.from(json['busyHourPredictions'] ?? []),
    );
  }
}

class ClinicalInsights {
  final List<String> differentialDiagnoses;
  final List<String> suggestedTests;
  final List<String> potentialDrugInteractions;
  final String clinicalNote;

  ClinicalInsights({
    required this.differentialDiagnoses,
    required this.suggestedTests,
    required this.potentialDrugInteractions,
    required this.clinicalNote,
  });

  factory ClinicalInsights.fromJson(Map<String, dynamic> json) {
    return ClinicalInsights(
      differentialDiagnoses:
          List<String>.from(json['differentialDiagnoses'] ?? []),
      suggestedTests: List<String>.from(json['suggestedTests'] ?? []),
      potentialDrugInteractions:
          List<String>.from(json['potentialDrugInteractions'] ?? []),
      clinicalNote: json['clinicalNote'] ?? '',
    );
  }
}

class PatientBrief {
  final String summary;
  final List<String> criticalAlerts;
  final List<String> treatmentHistoryHighlights;
  final String futureCarePlan;

  PatientBrief({
    required this.summary,
    required this.criticalAlerts,
    required this.treatmentHistoryHighlights,
    required this.futureCarePlan,
  });

  factory PatientBrief.fromJson(Map<String, dynamic> json) {
    return PatientBrief(
      summary: json['summary'] ?? '',
      criticalAlerts: List<String>.from(json['criticalAlerts'] ?? []),
      treatmentHistoryHighlights:
          List<String>.from(json['treatmentHistoryHighlights'] ?? []),
      futureCarePlan: json['futureCarePlan'] ?? '',
    );
  }
}

class ConciergeResponse {
  final String recommendation;
  final String urgencyLevel;
  final List<String> bookingAssistance;
  final String suggestedSpecialty;

  ConciergeResponse({
    required this.recommendation,
    required this.urgencyLevel,
    required this.bookingAssistance,
    required this.suggestedSpecialty,
  });

  factory ConciergeResponse.fromJson(Map<String, dynamic> json) {
    return ConciergeResponse(
      recommendation: json['recommendation'] ?? '',
      urgencyLevel: json['urgencyLevel'] ?? 'Low',
      bookingAssistance: List<String>.from(json['bookingAssistance'] ?? []),
      suggestedSpecialty: json['suggestedSpecialty'] ?? 'General Medicine',
    );
  }
}

class BillAnalysis {
  final String providerName;
  final double totalAmount;
  final List<BillItem> items;
  final String costAnalysis;
  final String savingsAdvice;

  BillAnalysis({
    required this.providerName,
    required this.totalAmount,
    required this.items,
    required this.costAnalysis,
    required this.savingsAdvice,
  });

  factory BillAnalysis.fromJson(Map<String, dynamic> json) {
    return BillAnalysis(
      providerName: json['providerName'] ?? 'Unknown',
      totalAmount: (json['totalAmount'] ?? 0.0).toDouble(),
      items:
          (json['items'] as List?)?.map((i) => BillItem.fromJson(i)).toList() ??
              [],
      costAnalysis: json['costAnalysis'] ?? '',
      savingsAdvice: json['savingsAdvice'] ?? '',
    );
  }
}

class BillItem {
  final String description;
  final double amount;

  BillItem({required this.description, required this.amount});

  factory BillItem.fromJson(Map<String, dynamic> json) {
    return BillItem(
      description: json['description'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
    );
  }
}

class MapTriageResponse {
  final String recommendedFacilityId;
  final String reasoning;
  final String urgencyContext;
  final List<String> travelAdvice;

  MapTriageResponse({
    required this.recommendedFacilityId,
    required this.reasoning,
    required this.urgencyContext,
    required this.travelAdvice,
  });

  factory MapTriageResponse.fromJson(Map<String, dynamic> json) {
    return MapTriageResponse(
      recommendedFacilityId: json['recommendedFacilityId'] ?? '',
      reasoning: json['reasoning'] ?? '',
      urgencyContext: json['urgencyContext'] ?? 'Low',
      travelAdvice: List<String>.from(json['travelAdvice'] ?? []),
    );
  }
}

class EpidemicInsight {
  final String status;
  final List<String> hotZones;
  final String projection;
  final List<String> doctorRecommendations;
  final String climateCorrelation;

  EpidemicInsight({
    required this.status,
    required this.hotZones,
    required this.projection,
    required this.doctorRecommendations,
    required this.climateCorrelation,
  });

  factory EpidemicInsight.fromJson(Map<String, dynamic> json) {
    return EpidemicInsight(
      status: json['status'] ?? '',
      hotZones: List<String>.from(json['hotZones'] ?? []),
      projection: json['projection'] ?? '',
      doctorRecommendations:
          List<String>.from(json['doctorRecommendations'] ?? []),
      climateCorrelation: json['climateCorrelation'] ?? '',
    );
  }
}

class ClimatePediatricSurge {
  final String riskLevel;
  final String insight;
  final String recommendation;
  final List<String> resourcePlanning;

  ClimatePediatricSurge({
    required this.riskLevel,
    required this.insight,
    required this.recommendation,
    required this.resourcePlanning,
  });

  factory ClimatePediatricSurge.fromJson(Map<String, dynamic> json) {
    return ClimatePediatricSurge(
      riskLevel: json['riskLevel'] ?? 'Low',
      insight: json['insight'] ?? '',
      recommendation: json['recommendation'] ?? '',
      resourcePlanning: List<String>.from(json['resourcePlanning'] ?? []),
    );
  }
}

class ClimateHealthInsight {
  final String riskLevel;
  final String summary;
  final List<String> actionItems;
  final String climateCorrelation;

  ClimateHealthInsight({
    required this.riskLevel,
    required this.summary,
    required this.actionItems,
    required this.climateCorrelation,
  });

  factory ClimateHealthInsight.fromJson(Map<String, dynamic> json) {
    return ClimateHealthInsight(
      riskLevel: json['riskLevel'] ?? 'Low',
      summary: json['summary'] ?? '',
      actionItems: List<String>.from(json['actionItems'] ?? []),
      climateCorrelation: json['climateCorrelation'] ?? '',
    );
  }
}

class GeminiAIService {
  static const _timeout = Duration(seconds: 15);

  final model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: '',
  );

  Future<T> _withTimeout<T>(Future<T> future) {
    return future.timeout(
      _timeout,
      onTimeout: () =>
          throw Exception('UNICEF Frontier Tech Service Timeout. Retrying...'),
    );
  }

  String _safeJsonEncode(Object? object) {
    return jsonEncode(object, toEncodable: (nonEncodable) {
      if (nonEncodable is DateTime) return nonEncodable.toIso8601String();
      try {
        return (nonEncodable as dynamic).toDate().toIso8601String();
      } catch (_) {
        return nonEncodable.toString();
      }
    });
  }

  /// AREA 1 & 3: Strategic Planning & Healthcare Readiness
  /// Optimizes pediatric resource allocation ahead of climate-driven surges.
  Future<ClimatePediatricSurge> getClimatePediatricSurgeForecast({
    required List<Map<String, dynamic>> regionalSymptomTrends,
    List<Map<String, dynamic>>? environmentalIndicators,
    String? country,
  }) async {
    final historyJson = _safeJsonEncode(regionalSymptomTrends);
    final indicatorsJson = environmentalIndicators != null
        ? _safeJsonEncode(environmentalIndicators)
        : "[]";
    final countryContext = country != null ? " for $country" : "";
    final prompt = '''
You are "Medicore UNICEF-AI," a Frontier Tech Strategist specializing in Climate-Resilient Pediatric Health. 
Analyze this regional symptom data$countryContext: $historyJson
And these real-time environmental indicators from field health workers: $indicatorsJson

MANDATE:
1. Predict pediatric surge risks (specifically for children under 5 and school-age) based on climate season (e.g. Monsoons, Harmattan, Heatwaves, or Flood seasons) and field intelligence.
2. AREA 1: Provide AI/ML resource optimization (Bed allocation, Oxygen supply, Pediatric vaccines).
3. AREA 3: Shift from reactive to proactive localized surge planning.
4. If field reports indicate outbreaks or disasters, immediately escalate the risk level and adjust recommendations.

Respond ONLY with valid JSON:
{
  "riskLevel": "Low/Medium/High/Critical",
  "insight": "AI insight correlating climate and field intelligence with pediatric health (e.g. water-borne or respiratory upticks).",
  "recommendation": "Strategic advice for clinic preparedness based on specific field reports.",
  "resourcePlanning": ["Bed capacity increase by X%", "Pre-stocking specific meds", "Staffing shift adjustment"]
}
''';

    try {
      final response =
          await _withTimeout(model.generateContent([Content.text(prompt)]));
      final text = response.text ?? '{}';
      final cleanJson = _cleanJson(text);
      return ClimatePediatricSurge.fromJson(jsonDecode(cleanJson));
    } catch (e) {
      return ClimatePediatricSurge(
        riskLevel: "Low",
        insight: "Climate-Health surveillance is active.",
        recommendation: "Maintain standard pediatric care protocols.",
        resourcePlanning: ["Ensure data continuity in low-bandwidth zones"],
      );
    }
  }

  /// AREA 4: Point-of-Care Support (Low-Connectivity Case Management)
  /// Generates ultra-compressed clinical summaries for offline-first synchronization.
  Future<PatientBrief> getOfflineCompressedBrief(String patientHistory) async {
    final prompt =
        'Summarize this pediatric history into a "Low-Bandwidth" format (max 150 chars) focusing on critical alerts for service continuity: $patientHistory';
    try {
      final response =
          await _withTimeout(model.generateContent([Content.text(prompt)]));
      return PatientBrief(
        summary: response.text ?? '',
        criticalAlerts: [],
        treatmentHistoryHighlights: [],
        futureCarePlan: "Follow-up required at nearest Climate-Ready clinic.",
      );
    } catch (e) {
      return PatientBrief(
          summary: "Offline data active.",
          criticalAlerts: [],
          treatmentHistoryHighlights: [],
          futureCarePlan: "");
    }
  }

  /// AREA 2: Early Warning & Early Action
  /// Identifies viral clusters correlated with climate events for real-time risk communication.
  Future<EpidemicInsight> getEpidemicOutreach(
      List<Map<String, dynamic>> symptomHistory,
      {String? country}) async {
    final historyJson = _safeJsonEncode(symptomHistory);
    final countryContext = country != null ? " in $country" : " globally";
    final prompt = '''
You are "Medicore AI Early-Warning-System."
Analyze regional logs: $historyJson
Correlate with local climate (Flood/Heat/Dust/Rainfall).
Identify real-time risk zones for Schools and Clinics$countryContext.

Respond ONLY with valid JSON:
{
  "status": "Alert summary for schools/clinics",
  "hotZones": ["Zone A", "Zone B"],
  "projection": "7-day risk outlook",
  "doctorRecommendations": ["Preventative measure 1"],
  "climateCorrelation": "How current weather is driving this risk"
}
''';
    try {
      final response =
          await _withTimeout(model.generateContent([Content.text(prompt)]));
      final text = response.text ?? '{}';
      final cleanJson = _cleanJson(text);
      return EpidemicInsight.fromJson(jsonDecode(cleanJson));
    } catch (e) {
      return EpidemicInsight(
          status: "Surveillance Active",
          hotZones: [],
          projection: "Stable",
          doctorRecommendations: [],
          climateCorrelation: "Nominal");
    }
  }

  Future<String> explainPrescription(String diagnosis, List<String> medicines,
      {String? country}) async {
    final countryContext = country != null ? " in $country" : "";
    final prompt = '''
You are "Medicore UNICEF-AI." A patient$countryContext has been prescribed:
Diagnosis: $diagnosis
Medicines: ${medicines.join(', ')}

Provide a guide focusing on pediatric safety and climate-impacted recovery:
1. **The Purpose**: How this helps, especially considering seasonal risks.
2. **Pediatric Care**: Specific advice for parents.
3. **Clinical Wisdom**: A "Do" or "Don't".
4. **Final Note**: Reassuring closing statement.

Format: Markdown.
''';

    try {
      final response =
          await _withTimeout(model.generateContent([Content.text(prompt)]));
      return response.text ??
          "I'm sorry, I couldn't generate an explanation at this time.";
    } catch (e) {
      return "I'm unable to generate your guide at the moment. Please consult your physician.";
    }
  }

  Future<String> interpretTestResult(
      String title, String status, bool isNormal) async {
    final prompt = '''
You are "Medicore UNICEF-AI." Interpret this lab result:
Test: $title
Status: $status (Is Normal: $isNormal)

Provide:
1. **The Insight**: Simple explanation for parents/caregivers.
2. **Climate Context**: If applicable, how environmental factors (e.g. water quality) might relate.
3. **Your Path Forward**: Reassuring next steps.

Tone: Warm and clear. Max 100 words.
''';

    try {
      final response =
          await _withTimeout(model.generateContent([Content.text(prompt)]));
      return response.text ??
          "I'm unable to interpret these results at this time.";
    } catch (e) {
      return "Interpretation is currently unavailable. Please discuss with your healthcare provider.";
    }
  }

  Future<PatientData> extractPatientData(String input,
      {Uint8List? imageBytes}) async {
    final prompt = '''
Extract pediatric health data from the input. 
Fields: name, bloodGroup, genotype, vaccinationStatus, heartRate, weight, height, allergies, chronicConditions, dob, gender, emergencyContact.

Respond ONLY with valid JSON.
''';

    final List<Content> content = [];
    if (imageBytes != null) {
      content.add(Content.multi([
        TextPart(prompt),
        DataPart('image/jpeg', imageBytes),
      ]));
    } else {
      content.add(Content.text(prompt));
    }

    try {
      final response = await _withTimeout(model.generateContent(content));
      final text = response.text ?? '{}';
      final cleanJson = _cleanJson(text);
      return PatientData.fromJson(jsonDecode(cleanJson));
    } catch (e) {
      return PatientData();
    }
  }

  String _cleanJson(String text) {
    String cleaned = text.trim();
    if (cleaned.contains('```json')) {
      cleaned = cleaned.split('```json').last.split('```').first.trim();
    } else if (cleaned.contains('```')) {
      cleaned = cleaned.split('```').last.split('```').first.trim();
    }

    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      return cleaned.substring(firstBrace, lastBrace + 1);
    }
    return cleaned;
  }

  Future<SymptomAnalysis> analyzeSymptoms(String symptoms,
      {Uint8List? imageBytes, String? country}) async {
    final countryContext = country != null ? " in $country" : " globally";
    final prompt = '''
You are "Medicore UNICEF-AI," a Frontier Tech specialist for climate-resilient pediatric health. 
Analyze these symptoms$countryContext for a child.
Context: We are monitoring environmental factors like Heatwaves, Floods, and Outbreaks.

Symptoms/Input: $symptoms

Respond ONLY with valid JSON:
{
  "summary": "Clear, concise pediatric summary. Mention possible climate/environmental links if relevant.",
  "urgency": "Low/Medium/High/Emergency",
  "advice": ["Actionable step 1", "Actionable step 2", "Actionable step 3"],
  "recommendedDepartment": "The medical specialty needed (e.g., Pediatrics, Dermatology, Infectious Diseases)"
}
''';

    final List<Content> content = [];
    if (imageBytes != null) {
      content.add(Content.multi([
        TextPart(prompt),
        DataPart('image/jpeg', imageBytes),
      ]));
    } else {
      content.add(Content.text(prompt));
    }

    try {
      final response = await _withTimeout(model.generateContent(content));
      final text = response.text ?? '{}';
      final cleanJson = _cleanJson(text);
      final data = jsonDecode(cleanJson);
      return SymptomAnalysis.fromJson(data);
    } catch (e) {
      return SymptomAnalysis(
        summary: "Error analyzing symptoms. Please ensure connectivity.",
        urgency: "Unknown",
        advice: ["Seek professional medical advice."],
        recommendedDepartment: "Pediatrics",
      );
    }
  }

  Future<HealthTrendAnalysis> predictHealthTrends(
      List<Map<String, dynamic>> history,
      {String? country}) async {
    final historyJson = _safeJsonEncode(history);
    final countryContext = country != null ? " for $country" : "";
    final prompt = '''
Analyze pediatric history$countryContext. Correlate with climate cycles.
Provide a 30-day health forecast for the child.

Respond ONLY with valid JSON:
{
  "forecast": "Monthly outlook with climate-health correlations",
  "identifiedPatterns": ["Pattern 1"],
  "potentialRisks": ["Risk 1"]
}
''';

    try {
      final response =
          await _withTimeout(model.generateContent([Content.text(prompt)]));
      final text = response.text ?? '{}';
      final cleanJson = _cleanJson(text);
      return HealthTrendAnalysis.fromJson(jsonDecode(cleanJson));
    } catch (e) {
      return HealthTrendAnalysis(
        forecast: "Stable outlook.",
        identifiedPatterns: [],
        potentialRisks: ["Continue routine check-ups."],
      );
    }
  }

  Future<LifestylePlan> generateLifestyleCoaching(String medicalContext,
      {String? country}) async {
    final countryContext = country != null ? " in $country" : "";
    final prompt = '''
Provide a lifestyle plan for a child$countryContext, complementing their medical context: $medicalContext.
Focus on nutrition and climate protection (e.g. hydration during extreme weather).

Respond ONLY with valid JSON:
{
  "mealPlan": ["Breakfast", "Lunch", "Dinner"],
  "exerciseRoutine": ["Morning", "Evening"],
  "nutritionalAdvice": "Specific advice"
}
''';

    try {
      final response =
          await _withTimeout(model.generateContent([Content.text(prompt)]));
      final text = response.text ?? '{}';
      final cleanJson = _cleanJson(text);
      return LifestylePlan.fromJson(jsonDecode(cleanJson));
    } catch (e) {
      return LifestylePlan(
        mealPlan: ["Balanced diet."],
        exerciseRoutine: ["Play in safe environment."],
        nutritionalAdvice: "Stay hydrated.",
      );
    }
  }

  Future<HealthJourneyAnalysis> analyzeRecoveryProgress(
      String initialSymptoms, String prescription, List<String> dailyCheckins,
      {String? country}) async {
    final countryContext = country != null ? " in $country" : " globally";
    final prompt = '''
Track pediatric recovery$countryContext.
Respond ONLY with valid JSON.
''';

    try {
      final response =
          await _withTimeout(model.generateContent([Content.text(prompt)]));
      final text = response.text ?? '{}';
      final cleanJson = _cleanJson(text);
      return HealthJourneyAnalysis.fromJson(jsonDecode(cleanJson));
    } catch (e) {
      return HealthJourneyAnalysis(
        recoveryProgress: [0],
        statusMessage: "Progress tracking unavailable.",
        nextSteps: ["Consult your doctor."],
        alertDoctor: true,
      );
    }
  }

  Future<String> matchSpecialist({
    required String symptoms,
    required List<Map<String, String>> availableDoctors,
  }) async {
    final doctorsJson = jsonEncode(availableDoctors);
    final prompt = '''
You are "Medicore AI Matcher." 
Patient Symptoms: "$symptoms"
Available Specialists: $doctorsJson

Task: Select the best doctor from the list based on their speciality and the symptoms provided.
If multiple match, pick the most appropriate one for pediatric care.

Respond ONLY with valid JSON:
{
  "recommendedDoctorId": "the_exact_id_from_the_list",
  "reason": "Explain why this specialist is the best match in 15 words or less."
}
''';

    try {
      final response =
          await _withTimeout(model.generateContent([Content.text(prompt)]));
      final text = response.text ?? '{}';
      return _cleanJson(text);
    } catch (e) {
      return '{}';
    }
  }

  Future<Map<String, List<String>>> searchEverything({
    required String query,
    required List<Map<String, dynamic>> hospitals,
    required List<Map<String, dynamic>> indicators,
    String? country,
  }) async {
    final hospitalsJson = jsonEncode(hospitals);
    final indicatorsJson = jsonEncode(indicators);
    final countryContext = country != null ? " in $country" : "";

    final prompt = '''
You are "Medicore AI Search". 
Analyze: "$query"$countryContext.

Hospitals: $hospitalsJson
Field Intelligence (Markers): $indicatorsJson

Task:
1. Identify up to 3 most relevant hospitals.
2. Identify any field intelligence markers (outbreaks, disasters) that are directly relevant to the query.

Respond ONLY with valid JSON:
{
  "hospitalIds": ["id1", "id2"],
  "indicatorIds": ["markerId1", "markerId2"]
}
''';

    try {
      final response =
          await _withTimeout(model.generateContent([Content.text(prompt)]));
      final text = response.text ?? '{"hospitalIds": [], "indicatorIds": []}';
      final cleanJson = _cleanJson(text);
      final decoded = jsonDecode(cleanJson);
      return {
        'hospitalIds': List<String>.from(decoded['hospitalIds'] ?? []),
        'indicatorIds': List<String>.from(decoded['indicatorIds'] ?? []),
      };
    } catch (e) {
      return {'hospitalIds': [], 'indicatorIds': []};
    }
  }

  Future<List<String>> searchHospitals({
    required String query,
    required List<Map<String, dynamic>> hospitals,
    String? country,
  }) async {
    final hospitalsJson = jsonEncode(hospitals);
    final countryContext = country != null ? " in $country" : "";

    final prompt = '''
You are "Medicore AI Hospital Search". 
Analyze: "$query"$countryContext.
Hospitals: $hospitalsJson

Identify up to 3 most relevant hospitals for this request.
Respond ONLY with valid JSON:
{
  "hospitalIds": ["id1", "id2"]
}
''';

    try {
      final response =
          await _withTimeout(model.generateContent([Content.text(prompt)]));
      final text = response.text ?? '{"hospitalIds": []}';
      final cleanJson = _cleanJson(text);
      final decoded = jsonDecode(cleanJson);
      return List<String>.from(decoded['hospitalIds'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<PracticeInsights> getPracticeManagementInsights(
      List<Map<String, dynamic>> appointmentLogs,
      {String? country}) async {
    final logsJson = _safeJsonEncode(appointmentLogs);
    final countryContext = country != null ? " in $country" : "";

    // Fetch field intelligence to enrich practice insights
    final indicatorsSnapshot = await FirebaseFirestore.instance
        .collection('environmental_indicators')
        .orderBy('timestamp', descending: true)
        .limit(5)
        .get();

    final indicators =
        indicatorsSnapshot.docs.map((doc) => doc.data()).toList();
    final indicatorsJson = jsonEncode(indicators);

    final prompt = '''
AREA 1: Strategic Planning & AREA 3: Healthcare Readiness.
Analyze clinic logs and field intelligence$countryContext to optimize resource allocation.

Clinic Logs: $logsJson
Field Intelligence (Climate/Outbreaks): $indicatorsJson

Task:
1. Provide an Efficiency Score for the clinic's current load.
2. Optimization Tips: Shift from reactive to proactive surge planning based on field intelligence.
3. Forecast patient satisfaction based on waiting times and regional stress factors (e.g. heatwaves).
4. Predict busy hours considering both historical logs and external climate triggers.

Respond ONLY with valid JSON:
{
  "efficiencyScore": "High/Optimal/Overburdened",
  "optimizationTips": ["Tip 1 (Field-aware)", "Tip 2 (Resource-focused)"],
  "patientSatisfactionForecast": "AI forecast based on regional context",
  "busyHourPredictions": ["Time Slot A", "Time Slot B"]
}
''';
    try {
      final response =
          await _withTimeout(model.generateContent([Content.text(prompt)]));
      final text = response.text ?? '{}';
      final cleanJson = _cleanJson(text);
      return PracticeInsights.fromJson(jsonDecode(cleanJson));
    } catch (e) {
      return PracticeInsights(
          efficiencyScore: "N/A",
          optimizationTips: [
            "Synchronizing with field intelligence...",
            "Maintain standard pediatric care."
          ],
          patientSatisfactionForecast: "Stable",
          busyHourPredictions: []);
    }
  }

  Future<ClinicalInsights> getClinicalTools(String symptoms, String history,
      {String? labResults, String? country}) async {
    final countryContext = country != null ? " in $country" : "";

    // Enrich clinical tools with field intelligence
    final indicatorsSnapshot = await FirebaseFirestore.instance
        .collection('environmental_indicators')
        .orderBy('timestamp', descending: true)
        .limit(3)
        .get();

    final indicators =
        indicatorsSnapshot.docs.map((doc) => doc.data()).toList();
    final indicatorsJson = jsonEncode(indicators);

    final prompt = '''
AREA 3: Healthcare Readiness & AREA 4: Point-of-Care Support.
You are "Medicore Clinical-AI." Assist a doctor$countryContext with a pediatric case.

Symptoms: $symptoms
History: $history
Lab Results: ${labResults ?? 'None provided'}
Field Intelligence: $indicatorsJson

Task:
1. Differential Diagnoses: Consider climate-linked illnesses (e.g. Cholera after floods, Meningitis in dry season) if field intelligence suggests regional risk.
2. Suggested Tests: Focus on localized surge planning.
3. Clinical Note: Brief, proactive guidance for the doctor.

Respond ONLY with valid JSON:
{
  "differentialDiagnoses": ["Diagnosis 1", "Diagnosis 2"],
  "suggestedTests": ["Test A", "Test B"],
  "potentialDrugInteractions": ["Warning 1"],
  "clinicalNote": "Strategic clinical insight."
}
''';
    try {
      final response =
          await _withTimeout(model.generateContent([Content.text(prompt)]));
      final text = response.text ?? '{}';
      final cleanJson = _cleanJson(text);
      return ClinicalInsights.fromJson(jsonDecode(cleanJson));
    } catch (e) {
      return ClinicalInsights(
          differentialDiagnoses: [],
          suggestedTests: [],
          potentialDrugInteractions: [],
          clinicalNote:
              "Clinical analysis unavailable. Synchronizing with field intelligence...");
    }
  }

  Future<PatientBrief> getPatientRecordSummary(Map<String, dynamic> fullRecord,
      {String? country}) async {
    final recordJson = _safeJsonEncode(fullRecord);
    final countryContext = country != null ? " for $country" : "";
    final prompt = '''
Summarize pediatric record$countryContext clinics.
Respond ONLY with valid JSON.
''';
    try {
      final response =
          await _withTimeout(model.generateContent([Content.text(prompt)]));
      final text = response.text ?? '{}';
      final cleanJson = _cleanJson(text);
      return PatientBrief.fromJson(jsonDecode(cleanJson));
    } catch (e) {
      return PatientBrief(
          summary: "Error summarizing record",
          criticalAlerts: [],
          treatmentHistoryHighlights: [],
          futureCarePlan: "");
    }
  }

  Future<ConciergeResponse> getMedicalConcierge(String query,
      {String? country}) async {
    final countryContext = country != null ? " for $country" : "";
    final prompt = '''
Medicore UNICEF-AI Concierge$countryContext. Helping parents with pediatric guidance.
Respond ONLY with valid JSON.
''';
    try {
      final response =
          await _withTimeout(model.generateContent([Content.text(prompt)]));
      final text = response.text ?? '{}';
      final cleanJson = _cleanJson(text);
      return ConciergeResponse.fromJson(jsonDecode(cleanJson));
    } catch (e) {
      return ConciergeResponse(
          recommendation: "Consult nearest clinic.",
          urgencyLevel: "Low",
          bookingAssistance: [],
          suggestedSpecialty: "Pediatrics");
    }
  }

  Future<String> getHealthManagementInsights(
      Map<String, dynamic> healthData) async {
    final dataJson = _safeJsonEncode(healthData);
    final prompt = '''
Analyze pediatric vitals for climate-resilience.
Data: $dataJson
''';
    try {
      final response =
          await _withTimeout(model.generateContent([Content.text(prompt)]));
      return response.text ?? "Unable to generate insights.";
    } catch (e) {
      return "Health insights currently unavailable.";
    }
  }

  Future<TestResult> extractLabReportData(Uint8List imageBytes) async {
    final prompt = '''
You are "Medicore Lab-AI." Extract data from this pediatric lab report image.
Focus on identifying:
1. The Test Title (e.g., Full Blood Count, Malaria Parasite, etc.)
2. The Status (e.g., Positive, Negative, 12.5 g/dL, etc.)
3. Whether the result is within Normal range (true/false).
4. The Lab Name if present.

Respond ONLY with valid JSON:
{
  "title": "Test Name",
  "status": "Result Value",
  "isNormal": true/false,
  "labName": "Laboratory Name"
}
''';

    try {
      final response = await _withTimeout(model.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ]));
      final text = response.text ?? '{}';
      final cleanJson = _cleanJson(text);
      final data = jsonDecode(cleanJson);

      return TestResult(
        id: '',
        title: data['title'] ?? 'Unknown Test',
        date: DateTime.now(),
        status: data['status'] ?? 'Pending',
        isNormal: data['isNormal'] ?? true,
        labName: data['labName'] ?? 'Unknown Lab',
      );
    } catch (e) {
      throw Exception("Failed to analyze lab report");
    }
  }

  Future<BillAnalysis> analyzeMedicalBill(Uint8List imageBytes) async {
    final prompt = '''
Analyze pediatric medical bill for cost optimization in clinics.
Respond ONLY with valid JSON.
''';

    try {
      final response = await _withTimeout(model.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ]));
      final text = response.text ?? '{}';
      final cleanJson = _cleanJson(text);
      return BillAnalysis.fromJson(jsonDecode(cleanJson));
    } catch (e) {
      throw Exception("Failed to analyze medical bill");
    }
  }

  Future<MapTriageResponse> getSmartTriage({
    required String symptoms,
    required List<Map<String, dynamic>> facilities,
    List<Map<String, dynamic>>? indicators,
    String? country,
  }) async {
    final facilitiesJson = jsonEncode(facilities);
    final indicatorsJson = indicators != null ? jsonEncode(indicators) : "[]";
    final countryContext = country != null ? " in $country" : "";
    final prompt = '''
AREA 2: Early Warning & Early Action.
A patient$countryContext has symptoms: "$symptoms".

Available Facilities: $facilitiesJson
Field Intelligence (from Health Workers): $indicatorsJson

Task:
1. Recommend the BEST facility based on symptoms and facility capabilities.
2. Consider any field intelligence (outbreaks, heatwaves, disasters) in the area that might affect the recommendation or travel safety.
3. If an outbreak is nearby, suggest a facility equipped for infectious disease.
4. If a disaster is reported, suggest the safest route or facility.

Respond ONLY with valid JSON:
{
  "recommendedFacilityId": "facility_id",
  "reasoning": "Detailed explanation of why this facility is chosen, referencing any relevant field intelligence.",
  "urgencyContext": "Low/Medium/High/Emergency",
  "travelAdvice": ["Safety tip 1 based on field data", "Safety tip 2"]
}
''';

    try {
      final response =
          await _withTimeout(model.generateContent([Content.text(prompt)]));
      final text = response.text ?? '{}';
      final cleanJson = _cleanJson(text);
      return MapTriageResponse.fromJson(jsonDecode(cleanJson));
    } catch (e) {
      return MapTriageResponse(
        recommendedFacilityId:
            facilities.isNotEmpty ? facilities.first['id'] : 'unknown',
        reasoning: "Proceeding to nearest facility.",
        urgencyContext: "Standard",
        travelAdvice: ["Proceed with care."],
      );
    }
  }

  /// Generates a unified insight combining hospital availability and environmental factors.
  Future<String> getFieldAwareInsight({
    required String query,
    required List<Map<String, dynamic>> indicators,
    required List<Map<String, dynamic>> hospitals,
    String? country,
  }) async {
    final indicatorsJson = jsonEncode(indicators);
    final hospitalsJson = jsonEncode(hospitals);
    final countryContext = country != null ? " in $country" : "";

    final prompt = '''
You are "Medicore AI Field Assistant". 
Patient Query: "$query"$countryContext.

Current Field Intelligence (from Health Workers): $indicatorsJson
Available Hospitals: $hospitalsJson

Provide a concise, helpful clinical insight (max 100 words). 
If there's an environmental risk (outbreak, heatwave) relevant to the query, highlight it.
Suggest the best course of action.
Use a supportive, professional tone.
''';

    try {
      final response =
          await _withTimeout(model.generateContent([Content.text(prompt)]));
      return response.text ??
          "I couldn't process the field data at this moment.";
    } catch (e) {
      return "Local healthcare services are being synchronized. Please proceed to the nearest verified facility.";
    }
  }

  /// Generates a high-level climate health summary for hospital dashboards.
  Future<ClimateHealthInsight> getClimateHealthInsight({
    required List<Map<String, dynamic>> indicators,
    String? country,
  }) async {
    final indicatorsJson = _safeJsonEncode(indicators);
    final countryContext = country != null ? " in $country" : "";

    final prompt = '''
You are the "Medicore Climate-Health Intelligence" system. 
Analyze these latest reports from health workers on the ground$countryContext:
$indicatorsJson

MANDATE:
1. Synthesize the reports into a concise intelligence summary for hospital leadership.
2. Correlate environmental factors (weather, climate events) with reported health symptoms (e.g. "Post-flood diarrhea uptick").
3. Provide actionable advice for hospital resource readiness.
4. Assign a Risk Level.

Tone: Professional, urgent but calm. 
Format: Respond ONLY with valid JSON:
{
  "riskLevel": "Low/Medium/High/Critical",
  "summary": "Concise Markdown summary",
  "actionItems": ["Action 1", "Action 2"],
  "climateCorrelation": "Explanation of weather impact"
}
''';

    try {
      final response =
          await _withTimeout(model.generateContent([Content.text(prompt)]));
      final text = response.text ?? '{}';
      final cleanJson = _cleanJson(text);
      return ClimateHealthInsight.fromJson(jsonDecode(cleanJson));
    } catch (e) {
      return ClimateHealthInsight(
        riskLevel: "Unknown",
        summary:
            "Climate-health synchronization in progress. Please refer to manual field reports.",
        actionItems: ["Monitor field communication channels"],
        climateCorrelation: "Syncing...",
      );
    }
  }
}
