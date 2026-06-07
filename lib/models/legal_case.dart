import 'package:cloud_firestore/cloud_firestore.dart';

class CaseTimelineEntry {
  final String id;
  final DateTime date;
  final String description;
  final List<Map<String, dynamic>> documents; // name, url, etc.
  final DateTime? nextHearingDate;
  final DateTime? documentDeadline;
  final String? notes;

  CaseTimelineEntry({
    required this.id,
    required this.date,
    required this.description,
    this.documents = const [],
    this.nextHearingDate,
    this.documentDeadline,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': Timestamp.fromDate(date),
      'description': description,
      'documents': documents,
      'nextHearingDate': nextHearingDate != null ? Timestamp.fromDate(nextHearingDate!) : null,
      'documentDeadline': documentDeadline != null ? Timestamp.fromDate(documentDeadline!) : null,
      'notes': notes,
    };
  }

  factory CaseTimelineEntry.fromMap(Map<String, dynamic> map) {
    return CaseTimelineEntry(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: map['description'] ?? '',
      documents: List<Map<String, dynamic>>.from(map['documents'] ?? []),
      nextHearingDate: (map['nextHearingDate'] as Timestamp?)?.toDate(),
      documentDeadline: (map['documentDeadline'] as Timestamp?)?.toDate(),
      notes: map['notes'],
    );
  }
}

class CaseExpense {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String category; // 'Advocate Fee', 'Court Fee', 'Travel', 'Other'

  CaseExpense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'category': category,
    };
  }

  factory CaseExpense.fromMap(Map<String, dynamic> map) {
    return CaseExpense(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category: map['category'] ?? 'Other',
    );
  }
}

class WitnessStatement {
  final String id;
  final String name;
  final String relation; // 'Plaintiff Witness', 'Defendant Witness', 'Neutral'
  final String statement;
  final DateTime date;
  final String? aiAnalysis;

  WitnessStatement({
    required this.id,
    required this.name,
    required this.relation,
    required this.statement,
    required this.date,
    this.aiAnalysis,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'relation': relation,
      'statement': statement,
      'date': Timestamp.fromDate(date),
      'aiAnalysis': aiAnalysis,
    };
  }

  factory WitnessStatement.fromMap(Map<String, dynamic> map) {
    return WitnessStatement(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      relation: map['relation'] ?? '',
      statement: map['statement'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      aiAnalysis: map['aiAnalysis'],
    );
  }
}

class LegalCase {
  final String id;
  final String userId;
  final String title;
  final String type;
  final String status; // 'Active', 'Disposed', 'Pending'
  final DateTime createdAt;
  final List<CaseTimelineEntry> timeline;
  final double totalBudget;
  final List<CaseExpense> expenses;
  final List<WitnessStatement> witnesses;

  double get totalSpent => expenses.fold(0.0, (sum, e) => sum + e.amount);

  // Helpers for backward compatibility or aggregation
  List<Map<String, dynamic>> get allDocuments => timeline.expand((e) => e.documents).toList();
  // Get the latest description/status from the last timeline entry
  String get latestDescription => timeline.isNotEmpty ? timeline.first.description : '';

  LegalCase({
    required this.id,
    required this.userId,
    required this.title,
    required this.type,
    required this.status,
    required this.createdAt,
    this.timeline = const [],
    this.totalBudget = 0.0,
    this.expenses = const [],
    this.witnesses = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'type': type,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'timeline': timeline.map((e) => e.toMap()).toList(),
      'totalBudget': totalBudget,
      'expenses': expenses.map((e) => e.toMap()).toList(),
      'witnesses': witnesses.map((e) => e.toMap()).toList(),
    };
  }

  factory LegalCase.fromMap(Map<String, dynamic> map, String id) {
    var timelineList = <CaseTimelineEntry>[];
    if (map['timeline'] != null) {
      timelineList = List<CaseTimelineEntry>.from(
        (map['timeline'] as List).map((x) => CaseTimelineEntry.fromMap(x))
      );
      // Sort timeline by date descending (newest first)
      timelineList.sort((a, b) => b.date.compareTo(a.date));
    }

    var expenseList = <CaseExpense>[];
    if (map['expenses'] != null) {
      expenseList = List<CaseExpense>.from(
        (map['expenses'] as List).map((x) => CaseExpense.fromMap(x))
      );
    }

    var witnessList = <WitnessStatement>[];
    if (map['witnesses'] != null) {
      witnessList = List<WitnessStatement>.from(
        (map['witnesses'] as List).map((x) => WitnessStatement.fromMap(x))
      );
    }

    // Migration for interaction with old data structure if needed
    // If 'description' exists at top level but no timeline, create one
    if (timelineList.isEmpty && map['description'] != null) {
        timelineList.add(CaseTimelineEntry(
          id: 'initial', 
          date: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          description: map['description'] ?? '',
          documents: List<Map<String, dynamic>>.from(map['documents'] ?? []),
          nextHearingDate: (map['nextHearing'] as Timestamp?)?.toDate()
        ));
    }

    return LegalCase(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      type: map['type'] ?? '',
      status: map['status'] ?? 'Active',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      timeline: timelineList,
      totalBudget: (map['totalBudget'] ?? 0.0).toDouble(),
      expenses: expenseList,
      witnesses: witnessList,
    );
  }
}
