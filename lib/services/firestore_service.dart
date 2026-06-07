import 'dart:io' as io;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_profile.dart';
import '../models/advisor.dart';
import '../models/legal_case.dart';
import '../models/forum_question.dart';
import '../models/analysis_history.dart';
import '../models/alimony_record.dart';
import '../models/channel.dart';
import '../models/user_connection.dart';
import '../models/legal_knowledge.dart';
import '../models/blog_post.dart';
import '../models/app_notification.dart';
import '../models/transaction.dart';
import '../models/forum_comment.dart';
import '../models/case_message.dart';
import '../models/child_profile.dart';
import '../utils/constants.dart';
import 'package:rxdart/rxdart.dart';
import 'sheets_export_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final SheetsExportService _sheets = SheetsExportService();

  SheetsExportService get sheets => _sheets;

  // --- User Profile ---

  Future<void> createUserProfile(UserProfile user) async {
    await _db
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .set(user.toMap());
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    var doc = await _db.collection(AppConstants.usersCollection).doc(uid).get();
    if (doc.exists) {
      return UserProfile.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  Stream<UserProfile?> streamUserProfile(String uid) {
    return _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserProfile.fromMap(doc.data()!, doc.id) : null);
  }

  Future<List<UserProfile>> searchUserProfiles(String query) async {
    if (query.isEmpty) return [];
    
    final snap = await _db.collection(AppConstants.usersCollection)
        .where('email', isGreaterThanOrEqualTo: query)
        .where('email', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(10)
        .get();
        
    return snap.docs.map((doc) => UserProfile.fromMap(doc.data(), doc.id)).toList();
  }

  Future<void> updateWalletBalance(String userId, double amount) async {
    await _db.collection(AppConstants.usersCollection).doc(userId).update({
      'walletBalance': FieldValue.increment(amount),
    });
  }

  Future<void> processWalletTransaction(AppTransaction transaction) async {
    final userRef = _db.collection(AppConstants.usersCollection).doc(transaction.userId);
    final txRef = _db.collection(AppConstants.transactionsCollection).doc();

    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw Exception("User not found");

      double currentBalance = (userSnap.data()?['walletBalance'] ?? 0.0).toDouble();
      double newBalance = transaction.type == TransactionType.credit 
          ? currentBalance + transaction.amount 
          : currentBalance - transaction.amount;

      if (newBalance < 0 && transaction.type == TransactionType.debit) {
        throw Exception("Insufficient wallet balance");
      }

      tx.update(userRef, {'walletBalance': newBalance});
      tx.set(txRef, transaction.toMap());
    });

    // Log to Google Sheets
    _sheets.logTransaction(
      userId: transaction.userId,
      email: '', // You can fetch email if needed, or pass it in the transaction
      amount: transaction.amount,
      type: transaction.type.name.toUpperCase(),
    );
  }

  Stream<List<AppTransaction>> streamUserTransactions(String userId) {
    return _db.collection(AppConstants.transactionsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => AppTransaction.fromMap(doc.data(), doc.id)).toList());
  }

  // --- Notifications ---

  Future<void> sendNotification(AppNotification notification) async {
    await _db.collection(AppConstants.notificationsCollection).add(notification.toMap());
  }

  Stream<List<AppNotification>> streamUserNotifications(String userId) {
    return _db.collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => AppNotification.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _db.collection(AppConstants.notificationsCollection).doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllNotificationsAsRead(String userId) async {
    final snap = await _db.collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    
    final batch = _db.batch();
    for (var doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<String> uploadProfilePicture(String userId, io.File file, {Uint8List? bytes}) async {
    // Compress to max 600x600 at 75% quality before uploading
    Uint8List uploadBytes;
    if (kIsWeb && bytes != null) {
      // Web: compress in-memory bytes
      uploadBytes = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 600,
        minHeight: 600,
        quality: 75,
        format: CompressFormat.jpeg,
      );
    } else {
      // Mobile: compress file
      final compressed = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 600,
        minHeight: 600,
        quality: 75,
        format: CompressFormat.jpeg,
      );
      uploadBytes = compressed ?? await file.readAsBytes();
    }

    final ref = _storage
        .ref()
        .child('users')
        .child(userId)
        .child('profile_pic.jpg'); // Fixed name — overwrites old pic, no accumulation

    final metadata = SettableMetadata(contentType: 'image/jpeg');
    final snapshot = await ref.putData(uploadBytes, metadata);
    final downloadUrl = await snapshot.ref.getDownloadURL();

    await _db.collection(AppConstants.usersCollection).doc(userId).set({
      'photoUrl': downloadUrl,
    }, SetOptions(merge: true));

    return downloadUrl;
  }

  // --- Advisor ---

  Future<void> registerAdvisor(Advisor advisor) async {
    await _db
        .collection(AppConstants.advisorsCollection)
        .doc(advisor.id)
        .set(advisor.toMap());
    
    // Also update UserProfile to mark as advisor (if applicable)
    await _db.collection(AppConstants.usersCollection).doc(advisor.id).update({
      'isVerifiedAdvisor': false, // Verification pending
      'isAdvisor': true,
    });
  }

  Future<void> registerAdvisorFromOnboarding(Map<String, dynamic> advisorData) async {
    final uid = advisorData['uid'] as String;
    
    // Store in advisors_onboarding collection for admin review (Firestore backup)
    await _db
        .collection('advisors_onboarding')
        .doc(uid)
        .set({
          ...advisorData,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    
    // Mark user as pending advisor
    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'isAdvisor': true,
      'isPendingAdvisor': true,
      'advisorApplicationStatus': 'submitted',
    });

    // Send data to MongoDB backend
    try {
      const String backendUrl = 'https://lexami-backend-d3t5.onrender.com/api/advisors/onboarding/submit';
      
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(advisorData),
      );

      if (response.statusCode != 201) {
        print('WARNING: Backend submission failed with status ${response.statusCode}. Data saved to Firestore only.');
      }
    } catch (e) {
      print('WARNING: Could not reach backend server: $e. Data saved to Firestore only.');
      // Data is already saved in Firestore, so we don't throw an error
    }
  }

  Future<String> uploadAdvisorDocument(String advisorId, String type, io.File file, {Uint8List? bytes}) async {
    String fileName = '${DateTime.now().millisecondsSinceEpoch}_${kIsWeb ? "doc" : file.path.split('/').last}';
    Reference ref = _storage.ref().child('advisors').child(advisorId).child(type).child(fileName);
    
    UploadTask task;
    if (kIsWeb && bytes != null) {
      task = ref.putData(bytes);
    } else {
      task = ref.putFile(file);
    }
    
    TaskSnapshot snapshot = await task;
    return await snapshot.ref.getDownloadURL();
  }

  Future<String> uploadAdvisorDocumentBytes(String advisorId, String type, Uint8List bytes) async {
    // Convert bytes to Base64 for MongoDB storage
    String base64String = base64Encode(bytes);
    return base64String;
  }

  Future<void> updateAdvisorStatus(String advisorId, String status, bool isVerified, String adminId, String adminName) async {
    await _db.collection(AppConstants.advisorsCollection).doc(advisorId).update({
      'verificationStatus': status,
      'isVerified': isVerified,
      'reviewedBy': adminId,
      'reviewerName': adminName,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
    
    // Log to Google Sheets
    _sheets.logAdminAction(
      adminName: adminName,
      action: status.toUpperCase(),
      targetId: advisorId,
      details: 'Advisor verification status updated to $status (isVerified: $isVerified)',
    );
    
    if (isVerified) {
      await _db.collection(AppConstants.usersCollection).doc(advisorId).update({
        'isVerifiedAdvisor': true,
      });

      // Send Notification
      await sendNotification(AppNotification(
        id: '',
        userId: advisorId,
        title: 'Account Approved! 🎉',
        body: 'Congratulations! Your advisor profile is now live and visible to users. You can now post blogs and engage with the community.',
        createdAt: DateTime.now(),
        type: 'approval',
      ));
    }
  }

  Future<Stream<List<Advisor>>> streamPendingAdvisors({String? status}) async {
    Query query = _db.collection(AppConstants.advisorsCollection);
    
    if (status != null) {
      query = query.where('verificationStatus', isEqualTo: status);
    } else {
      query = query.where('verificationStatus', whereIn: ['pending', 'under_review']);
    }

    return query.snapshots()
        .map((snap) => snap.docs.map((doc) => Advisor.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  Future<void> takeAdvisorReview(String advisorId, String adminId, String adminName) async {
    await _db.collection(AppConstants.advisorsCollection).doc(advisorId).update({
      'verificationStatus': 'under_review',
      'reviewedBy': adminId,
      'reviewerName': adminName,
    });
  }

  Future<List<Advisor>> searchAdvisors({String? category, String? specialization, String? name}) async {
    Query query = _db.collection(AppConstants.advisorsCollection).where('isVerified', isEqualTo: true);

    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }
    if (specialization != null && specialization.isNotEmpty) {
      query = query.where('specialization', isEqualTo: specialization);
    }
    
    QuerySnapshot snapshot = await query.get();
    return snapshot.docs
        .map((doc) => Advisor.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Stream<List<Advisor>> getAdvisorsStream({
    String? category,
    String? state,
    String? district,
    String? city,
    double? minRating,
    double? minExperience,
    int? minCasesWon,
    double? maxPrice,
    String? specialization,
  }) {
    Query query = _db.collection(AppConstants.advisorsCollection)
        .where('isVerified', isEqualTo: true);

    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }
    if (state != null && state.isNotEmpty) {
      query = query.where('state', isEqualTo: state);
    }
    
    // We fetch and then filter client-side for complex inequalities to avoid index explosions
    return query.snapshots().map((snapshot) {
      var list = snapshot.docs
          .map((doc) => Advisor.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      
      if (minRating != null) {
        list = list.where((a) => a.rating >= minRating).toList();
      }
      if (minExperience != null) {
        list = list.where((a) => a.experience >= minExperience).toList();
      }
      if (minCasesWon != null) {
        list = list.where((a) => a.casesWon >= minCasesWon).toList();
      }
      if (maxPrice != null) {
        list = list.where((a) => a.pricePerMin <= maxPrice).toList();
      }
      if (specialization != null && specialization.isNotEmpty) {
        list = list.where((a) => a.specialization == specialization).toList();
      }
      if (city != null && city.isNotEmpty) {
        list = list.where((a) => a.city == city).toList();
      }
      
      return list;
    });
  }

  // --- Legal Cases ---

  Future<void> addCase(LegalCase c) async {
    await _db.collection(AppConstants.casesCollection).add(c.toMap());
  }

  Future<void> addHearing(String caseId, Map<String, dynamic> hearing) async {
    await _db.collection(AppConstants.casesCollection).doc(caseId).update({
      'hearings': FieldValue.arrayUnion([hearing]),
    });
  }

  Future<void> addDocument(String caseId, Map<String, dynamic> document) async {
    await _db.collection(AppConstants.casesCollection).doc(caseId).update({
      'documents': FieldValue.arrayUnion([document]),
    });
  }

  Future<void> addCaseUpdate(String caseId, CaseTimelineEntry entry) async {
    await _db.collection(AppConstants.casesCollection).doc(caseId).update({
      'timeline': FieldValue.arrayUnion([entry.toMap()]),
    });
  }

  Future<void> updateCaseBudget(String caseId, double budget) async {
    await _db.collection(AppConstants.casesCollection).doc(caseId).update({
      'totalBudget': budget,
    });
  }

  Future<void> addCaseExpense(String caseId, CaseExpense expense) async {
    await _db.collection(AppConstants.casesCollection).doc(caseId).update({
      'expenses': FieldValue.arrayUnion([expense.toMap()]),
    });
  }

  Future<void> addWitnessStatement(String caseId, WitnessStatement witness) async {
    await _db.collection(AppConstants.casesCollection).doc(caseId).update({
      'witnesses': FieldValue.arrayUnion([witness.toMap()]),
    });
  }

  Future<void> updateWitnessAnalysis(String caseId, String witnessId, String analysis) async {
    final docRef = _db.collection(AppConstants.casesCollection).doc(caseId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final witnesses = List<Map<String, dynamic>>.from(doc.data()?['witnesses'] ?? []);
    final updatedWitnesses = witnesses.map((w) {
      if (w['id'] == witnessId) {
        return {...w, 'aiAnalysis': analysis};
      }
      return w;
    }).toList();

    await docRef.update({'witnesses': updatedWitnesses});
  }

  Future<void> updateAdminStatus(String userId, bool isAdmin) async {
    await _db.collection(AppConstants.usersCollection).doc(userId).update({
      'isAdmin': isAdmin,
    });
  }

  Stream<List<LegalCase>> streamUserCases(String userId) {
    return _db
        .collection(AppConstants.casesCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final cases = snapshot.docs
            .map((doc) => LegalCase.fromMap(doc.data(), doc.id))
            .toList();
          // Sort client-side to avoid composite index requirement
          cases.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return cases;
        });
  }

  // --- Forum / Community ---

  Future<void> addForumQuestion(ForumQuestion question) async {
    await _db.collection(AppConstants.forumCollection).add(question.toMap());
  }

  Stream<List<ForumQuestion>> streamForumQuestions({String? tag}) {
    // Fetch all questions ordered by date
    Query query = _db.collection(AppConstants.forumCollection).orderBy('createdAt', descending: true);
    
    return query.snapshots().map((snapshot) {
      final allQuestions = snapshot.docs
          .map((doc) => ForumQuestion.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Filter client-side to avoid Index requirements
      if (tag != null && tag != 'All Questions') {
        return allQuestions.where((q) => q.tags.contains(tag)).toList();
      }
      return allQuestions;
    });
  }

  Future<void> likeForumQuestion(String questionId, String userId) async {
    final ref = _db.collection(AppConstants.forumCollection).doc(questionId);
    final snap = await ref.get();
    if (!snap.exists) return;

    final List<dynamic> likedBy = (snap.data() as Map<String, dynamic>)['likedBy'] ?? [];
    if (likedBy.contains(userId)) {
      await ref.update({
        'likesCount': FieldValue.increment(-1),
        'likedBy': FieldValue.arrayRemove([userId]),
      });
    } else {
      await ref.update({
        'likesCount': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([userId]),
      });
    }
  }

  Future<void> addForumComment(ForumComment comment) async {
    final commentsRef = _db
        .collection(AppConstants.forumCollection)
        .doc(comment.postId)
        .collection('comments');

    // Use auto-generated Firestore ID when none provided
    if (comment.id.isEmpty) {
      await commentsRef.add(comment.toMap());
    } else {
      await commentsRef.doc(comment.id).set(comment.toMap());
    }

    await _db.collection(AppConstants.forumCollection).doc(comment.postId).update({
      'commentsCount': FieldValue.increment(1),
    });
  }

  Stream<List<ForumComment>> streamForumComments(String postId) {
    return _db
        .collection(AppConstants.forumCollection)
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ForumComment.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> repostForumQuestion(String originalPostId, String userId, String authorName, {String? thoughts}) async {
    final ref = _db.collection(AppConstants.forumCollection).doc(originalPostId);
    final snap = await ref.get();
    if (!snap.exists) return;

    final originalQuestion = ForumQuestion.fromMap(snap.data() as Map<String, dynamic>, originalPostId);
    
    if (originalQuestion.repostedBy.contains(userId)) return;

    await ref.update({
      'repostsCount': FieldValue.increment(1),
      'repostedBy': FieldValue.arrayUnion([userId]),
    });

    // Create a new post that is a repost
    await _db.collection(AppConstants.forumCollection).add({
      ...originalQuestion.toMap(),
      'userId': userId,
      'authorName': authorName,
      'createdAt': FieldValue.serverTimestamp(),
      'likesCount': 0,
      'likedBy': [],
      'repostsCount': 0,
      'repostedBy': [],
      'commentsCount': 0,
      'isRepost': true,
      'originalAuthorName': originalQuestion.authorName,
      'repostThoughts': thoughts,
      'originalPostId': originalPostId,
    });
  }

  // --- Analysis History ---

  Future<void> saveAnalysis(AnalysisHistory history) async {
    await _db.collection(AppConstants.historyCollection).add(history.toMap());
  }

  Stream<List<AnalysisHistory>> streamAnalysisHistory(String userId) {
    return _db
        .collection(AppConstants.historyCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final history = snapshot.docs
            .map((doc) => AnalysisHistory.fromMap(doc.data(), doc.id))
            .toList();
          history.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return history;
        });
  }

  // --- Alimony Tracker ---

  Future<void> addAlimonyRecord(AlimonyRecord record) async {
    await _db.collection(AppConstants.alimonyCollection).add(record.toMap());
  }

  Stream<List<AlimonyRecord>> streamAlimonyRecords(String userId) {
    return _db
        .collection(AppConstants.alimonyCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AlimonyRecord.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<List<AlimonyRecord>> getAlimonyRecordsOnce(String userId) async {
    final snapshot = await _db
        .collection(AppConstants.alimonyCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => AlimonyRecord.fromMap(doc.id, doc.data()))
        .toList();
  }

  // --- Evidence Vault ---

  Future<void> saveEvidence(String userId, Map<String, dynamic> evidence) async {
    await _db.collection(AppConstants.vaultCollection).add({
      ...evidence,
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> streamEvidence(String userId, {String? category}) {
    Query query = _db.collection(AppConstants.vaultCollection)
        .where('userId', isEqualTo: userId);

    if (category != null && category != 'All') {
      query = query.where('category', isEqualTo: category);
    }

    return query.snapshots().map((snap) {
      final docs = snap.docs.map((doc) => {
        ...doc.data() as Map<String, dynamic>,
        'id': doc.id,
      }).toList();
      docs.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      return docs;
    });
  }

  Future<void> deleteEvidence(String evidenceId, String? storageUrl) async {
    await _db.collection(AppConstants.vaultCollection).doc(evidenceId).delete();
    if (storageUrl != null && storageUrl.isNotEmpty) {
      try {
        await FirebaseStorage.instance.refFromURL(storageUrl).delete();
      } catch (e) {
        print('Error deleting storage file: $e');
      }
    }
  }

  Future<String> uploadVaultFile(String userId, String category, io.File file, {Uint8List? bytes}) async {
    String fileName = '${DateTime.now().millisecondsSinceEpoch}_${kIsWeb ? "vault_file" : file.path.split('/').last}';
    String path = 'users/$userId/vault/$category/$fileName';
    Reference ref = _storage.ref().child(path);
    
    UploadTask task;
    if (kIsWeb && bytes != null) {
      task = ref.putData(bytes);
    } else {
      task = ref.putFile(file);
    }
    
    TaskSnapshot snapshot = await task;
    return await snapshot.ref.getDownloadURL();
  }

  Future<Map<String, String>> uploadVaultBytes(String userId, String category, String fileName, Uint8List bytes) async {
    if (bytes.isEmpty) throw Exception('File is empty — nothing to upload.');

    String ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    String mimeType;
    switch (ext) {
      case 'jpg': case 'jpeg': mimeType = 'image/jpeg'; break;
      case 'png': mimeType = 'image/png'; break;
      case 'pdf': mimeType = 'application/pdf'; break;
      case 'mp4': mimeType = 'video/mp4'; break;
      case 'mp3': mimeType = 'audio/mpeg'; break;
      case 'm4a': mimeType = 'audio/mp4'; break;
      default: mimeType = 'application/octet-stream';
    }

    String fullPath = 'users/$userId/vault/$category/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    Reference ref = _storage.ref().child(fullPath);
    UploadTask task = ref.putData(bytes, SettableMetadata(contentType: mimeType));
    TaskSnapshot snapshot = await task;

    if (snapshot.state != TaskState.success) {
      throw Exception('Upload did not complete successfully (state: ${snapshot.state}).');
    }

    String downloadUrl = await snapshot.ref.getDownloadURL();
    String bucket = snapshot.ref.bucket;
    return {
      'url': downloadUrl,
      'path': 'gs://$bucket/$fullPath'
    };
  }

  // --- Community: Blogs ---

  Future<void> addBlogPost(BlogPost post) async {
    await _db.collection(AppConstants.blogsCollection).add(post.toMap());
  }

  Stream<List<BlogPost>> streamApprovedBlogs() {
    return _db
        .collection(AppConstants.blogsCollection)
        .where('isApproved', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => BlogPost.fromMap(doc.data(), doc.id)).toList());
  }

  // --- Community: Channels ---

  Future<void> createChannel(Channel channel) async {
    await _db.collection(AppConstants.channelsCollection).doc(channel.id).set(channel.toMap());
  }

  Future<String> uploadChannelProfilePicture(String channelId, io.File file, {Uint8List? bytes}) async {
    String fileName = 'channel_profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
    Reference ref = _storage.ref().child('channels').child(channelId).child('profile').child(fileName);
    
    UploadTask task;
    if (kIsWeb && bytes != null) {
      task = ref.putData(bytes);
    } else {
      task = ref.putFile(file);
    }
    
    TaskSnapshot snapshot = await task;
    String downloadUrl = await snapshot.ref.getDownloadURL();
    
    await _db.collection(AppConstants.channelsCollection).doc(channelId).update({
      'profileImageUrl': downloadUrl,
    });
    
    return downloadUrl;
  }

  Stream<List<Channel>> streamChannels() {
    return _db
        .collection(AppConstants.channelsCollection)
        .orderBy('followersCount', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Channel.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> followChannel(String userId, String channelId) async {
    await _db.collection(AppConstants.usersCollection).doc(userId).update({
      'followedChannels': FieldValue.arrayUnion([channelId]),
    });
    await _db.collection(AppConstants.channelsCollection).doc(channelId).update({
      'followersCount': FieldValue.increment(1),
    });
  }

  Future<String> uploadChannelPostMedia(String channelId, String postId, io.File file, {Uint8List? bytes, Function(double)? onProgress}) async {
    String extension = kIsWeb ? 'jpg' : file.path.split('.').last;
    String fileName = '${postId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    Reference ref = _storage.ref().child('channels').child(channelId).child('posts').child(fileName);
    
    UploadTask task;
    if (kIsWeb && bytes != null) {
      task = ref.putData(bytes);
    } else {
      task = ref.putFile(file);
    }
    
    if (onProgress != null) {
      task.snapshotEvents.listen((event) {
        double progress = event.bytesTransferred / event.totalBytes;
        onProgress(progress);
      });
    }

    TaskSnapshot snapshot = await task;
    return await snapshot.ref.getDownloadURL();
  }

  // --- Community: Channel Posts (New) ---

  Future<void> createChannelPost(ChannelPost post) async {
    await _db
        .collection(AppConstants.channelsCollection)
        .doc(post.channelId)
        .collection(AppConstants.channelPostsCollection)
        .doc(post.id)
        .set(post.toMap());
  }

  Stream<List<ChannelPost>> streamChannelPosts(String channelId) {
    return _db
        .collection(AppConstants.channelsCollection)
        .doc(channelId)
        .collection(AppConstants.channelPostsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ChannelPost.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> likeChannelPost(String channelId, String postId, String userId) async {
    final postRef = _db
        .collection(AppConstants.channelsCollection)
        .doc(channelId)
        .collection(AppConstants.channelPostsCollection)
        .doc(postId);

    final postSnap = await postRef.get();
    if (!postSnap.exists) return;

    final List<dynamic> likedBy = postSnap.data()?['likedBy'] ?? [];
    if (likedBy.contains(userId)) {
      // Unlike
      await postRef.update({
        'likesCount': FieldValue.increment(-1),
        'likedBy': FieldValue.arrayRemove([userId]),
      });
    } else {
      // Like
      await postRef.update({
        'likesCount': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([userId]),
      });
    }
  }

  Future<void> repostChannelPost(String originalChannelId, String originalPostId, String userId, String userChannelId, String userChannelName, String? userChannelImage, {String? thoughts}) async {
    // Get the original post
    final originalPostRef = _db
        .collection(AppConstants.channelsCollection)
        .doc(originalChannelId)
        .collection(AppConstants.channelPostsCollection)
        .doc(originalPostId);

    final originalPostSnap = await originalPostRef.get();
    if (!originalPostSnap.exists) return;

    final originalPost = ChannelPost.fromMap(originalPostSnap.data()!, originalPostId);
    
    // Check if already reposted
    final List<dynamic> repostedBy = originalPostSnap.data()?['repostedBy'] ?? [];
    if (repostedBy.contains(userId)) {
      // Already reposted, don't allow duplicate
      return;
    }

    // Update original post repost count
    await originalPostRef.update({
      'repostsCount': FieldValue.increment(1),
      'repostedBy': FieldValue.arrayUnion([userId]),
    });

    // Create repost in user's channel
    final repostId = DateTime.now().millisecondsSinceEpoch.toString();
    final repost = ChannelPost(
      id: repostId,
      channelId: userChannelId,
      authorId: userId,
      authorName: userChannelName,
      authorImage: userChannelImage,
      content: originalPost.content,
      mediaUrl: originalPost.mediaUrl,
      thumbnailUrl: originalPost.thumbnailUrl,
      isRepost: true,
      originalPostId: originalPostId,
      originalAuthorName: originalPost.authorName,
      repostThoughts: thoughts,
      createdAt: DateTime.now(),
    );

    await createChannelPost(repost);
  }

  Future<void> undoRepost(String originalChannelId, String originalPostId, String userId, String userChannelId) async {
    // Update original post repost count
    final originalPostRef = _db
        .collection(AppConstants.channelsCollection)
        .doc(originalChannelId)
        .collection(AppConstants.channelPostsCollection)
        .doc(originalPostId);

    await originalPostRef.update({
      'repostsCount': FieldValue.increment(-1),
      'repostedBy': FieldValue.arrayRemove([userId]),
    });

    // Find and delete the repost from user's channel
    final repostsSnap = await _db
        .collection(AppConstants.channelsCollection)
        .doc(userChannelId)
        .collection(AppConstants.channelPostsCollection)
        .where('isRepost', isEqualTo: true)
        .where('originalPostId', isEqualTo: originalPostId)
        .where('authorId', isEqualTo: userId)
        .get();

    for (var doc in repostsSnap.docs) {
      await doc.reference.delete();
    }
  }


  // --- Community: Channel Comments ---

  Future<void> addChannelComment(String channelId, ChannelComment comment) async {
    // Add comment to subcollection
    await _db
        .collection(AppConstants.channelsCollection)
        .doc(channelId)
        .collection(AppConstants.channelPostsCollection)
        .doc(comment.postId)
        .collection(AppConstants.channelCommentsCollection)
        .add(comment.toMap());
        
    // Increment comment count on post
    await _db
        .collection(AppConstants.channelsCollection)
        .doc(channelId)
        .collection(AppConstants.channelPostsCollection)
        .doc(comment.postId)
        .update({'commentsCount': FieldValue.increment(1)});
  }

  Stream<List<ChannelComment>> streamChannelComments(String channelId, String postId) {
    return _db
        .collection(AppConstants.channelsCollection)
        .doc(channelId)
        .collection(AppConstants.channelPostsCollection)
        .doc(postId)
        .collection(AppConstants.channelCommentsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ChannelComment.fromMap(doc.data(), doc.id)).toList());
  }

  Future<Channel?> getChannelByOwner(String ownerId) async {
    final snap = await _db.collection(AppConstants.channelsCollection).where('ownerId', isEqualTo: ownerId).limit(1).get();
    if (snap.docs.isNotEmpty) {
      return Channel.fromMap(snap.docs.first.data(), snap.docs.first.id);
    }
    return null;
  }

  Future<bool> checkChannelHandle(String handle) async {
    final query = await _db
        .collection(AppConstants.channelsCollection)
        .where('handle', isEqualTo: handle)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }


  // --- Community: Connections ---

  Future<void> sendFriendRequest(String fromId, String toId) async {
    // Check if a request from toId to fromId already exists (reverse request)
    final reverseRequest = await _db.collection(AppConstants.connectionsCollection)
        .where('senderId', isEqualTo: toId)
        .where('receiverId', isEqualTo: fromId)
        .where('status', isEqualTo: ConnectionStatus.pending.name)
        .get();

    if (reverseRequest.docs.isNotEmpty) {
      // Automatically accept the existing request
      await updateConnectionStatus(reverseRequest.docs.first.id, ConnectionStatus.accepted);
      return;
    }

    // Check if any connection already exists (including accepted or already pending)
    final existing = await _db.collection(AppConstants.connectionsCollection)
        .where('senderId', isEqualTo: fromId)
        .where('receiverId', isEqualTo: toId)
        .get();
    
    if (existing.docs.isEmpty) {
      await _db.collection(AppConstants.connectionsCollection).add({
        'senderId': fromId,
        'receiverId': toId,
        'status': ConnectionStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send Notification to recipient
      final senderProfile = await getUserProfile(fromId);
      await sendNotification(AppNotification(
        id: '',
        userId: toId,
        title: 'New Connection Request',
        body: '${senderProfile?.fullName ?? 'Someone'} wants to connect with you.',
        createdAt: DateTime.now(),
        type: 'message',
      ));
    }
  }

  Stream<ConnectionStatus?> streamConnectionStatus(String currentId, String otherId) {
    final s1 = _db.collection(AppConstants.connectionsCollection)
        .where('senderId', isEqualTo: currentId)
        .where('receiverId', isEqualTo: otherId)
        .snapshots();
    
    final s2 = _db.collection(AppConstants.connectionsCollection)
        .where('senderId', isEqualTo: otherId)
        .where('receiverId', isEqualTo: currentId)
        .snapshots();

    return CombineLatestStream.combine2(s1, s2, (QuerySnapshot q1, QuerySnapshot q2) {
      if (q1.docs.isNotEmpty) {
        final data = q1.docs.first.data() as Map<String, dynamic>;
        return ConnectionStatus.values.firstWhere((e) => e.name == data['status']);
      }
      if (q2.docs.isNotEmpty) {
        final data = q2.docs.first.data() as Map<String, dynamic>;
        return ConnectionStatus.values.firstWhere((e) => e.name == data['status']);
      }
      return null;
    });
  }

  Future<void> updateConnectionStatus(String connectionId, ConnectionStatus status) async {
    await _db.collection(AppConstants.connectionsCollection).doc(connectionId).update({
      'status': status.name,
    });

    if (status == ConnectionStatus.accepted) {
      final doc = await _db.collection(AppConstants.connectionsCollection).doc(connectionId).get();
      final data = doc.data();
      if (data != null) {
        final senderId = data['senderId'];
        final receiverId = data['receiverId'];
        
        final receiverProfile = await getUserProfile(receiverId);
        
        await sendNotification(AppNotification(
          id: '',
          userId: senderId,
          title: 'Request Accepted',
          body: '${receiverProfile?.fullName ?? 'Someone'} accepted your connection request.',
          createdAt: DateTime.now(),
          type: 'message',
        ));
      }
    }
  }

  Stream<List<UserConnection>> streamIncomingRequests(String userId) {
    return _db.collection(AppConstants.connectionsCollection)
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: ConnectionStatus.pending.name)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => UserConnection.fromMap(doc.data(), doc.id)).toList());
  }

  Stream<List<UserConnection>> streamFriends(String userId) {
    // We combine streams for friends where user is sender OR receiver
    final s1 = _db.collection(AppConstants.connectionsCollection)
        .where('senderId', isEqualTo: userId)
        .where('status', isEqualTo: ConnectionStatus.accepted.name)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => UserConnection.fromMap(doc.data(), doc.id)).toList());
    
    final s2 = _db.collection(AppConstants.connectionsCollection)
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: ConnectionStatus.accepted.name)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => UserConnection.fromMap(doc.data(), doc.id)).toList());

    return CombineLatestStream.combine2(s1, s2, (List<UserConnection> l1, List<UserConnection> l2) {
      return [...l1, ...l2];
    });
  }

  // Helper for suggestions
  Future<List<UserProfile>> getFriendSuggestions(String userId) async {
    // Get all users who aren't the current user and aren't already connected
    // For demo, we'll just fetch 5 random users who aren't the current user
    final snap = await _db.collection(AppConstants.usersCollection)
        .where(FieldPath.documentId, isNotEqualTo: userId)
        .limit(10)
        .get();
    
    return snap.docs.map((doc) => UserProfile.fromMap(doc.data(), doc.id)).toList();
  }

  // --- Legal RAG: Knowledge Retrieval ---

  Future<List<LegalStatute>> retrieveRelevantStatutes(List<String> keywords) async {
    if (keywords.isEmpty) return [];
    final snap = await _db.collection(AppConstants.statutesCollection).get();
    return snap.docs
        .map((doc) => LegalStatute.fromMap(doc.data(), doc.id))
        .where((s) => s.keywords.any((k) => keywords.contains(k.toLowerCase())))
        .toList();
  }

  Future<List<LandmarkJudgment>> retrieveRelevantJudgments(List<String> keywords) async {
    if (keywords.isEmpty) return [];
    final snap = await _db.collection(AppConstants.judgmentsCollection).get();
    return snap.docs
        .map((doc) => LandmarkJudgment.fromMap(doc.data(), doc.id))
        .where((j) => j.applicableSections.any((s) => keywords.any((k) => s.toLowerCase().contains(k.toLowerCase()))))
        .toList();
  }

  Future<List<LegalStatute>> getStatutes() async {
    final snap = await _db.collection(AppConstants.statutesCollection).get();
    return snap.docs.map((doc) => LegalStatute.fromMap(doc.data(), doc.id)).toList();
  }

  Future<List<LandmarkJudgment>> getJudgments() async {
    final snap = await _db.collection(AppConstants.judgmentsCollection).get();
    return snap.docs.map((doc) => LandmarkJudgment.fromMap(doc.data(), doc.id)).toList();
  }

  Future<List<BlogPost>> retrieveRelevantBlogs(List<String> keywords) async {
    if (keywords.isEmpty) return [];
    final snap = await _db.collection(AppConstants.blogsCollection).where('isApproved', isEqualTo: true).get();
    return snap.docs
        .map((doc) => BlogPost.fromMap(doc.data(), doc.id))
        .where((b) => keywords.any((k) => b.title.toLowerCase().contains(k.toLowerCase()) || b.content.toLowerCase().contains(k.toLowerCase())))
        .toList();
  }

  Future<List<ForumQuestion>> retrieveRelevantForumQuestions(List<String> keywords) async {
    if (keywords.isEmpty) return [];
    final snap = await _db.collection(AppConstants.forumCollection).get();
    return snap.docs
        .map((doc) => ForumQuestion.fromMap(doc.data(), doc.id))
        .where((q) => keywords.any((k) => q.title.toLowerCase().contains(k.toLowerCase()) || q.tags.any((t) => t.toLowerCase().contains(k.toLowerCase()))))
        .toList();
  }

  Future<Map<String, dynamic>> getUnifiedRAGContext(List<String> keywords) async {
    final results = await Future.wait([
      retrieveRelevantStatutes(keywords),
      retrieveRelevantJudgments(keywords),
      retrieveRelevantBlogs(keywords),
      retrieveRelevantForumQuestions(keywords),
    ]);

    return {
      'statutes': results[0] as List<LegalStatute>,
      'judgments': results[1] as List<LandmarkJudgment>,
      'blogs': results[2] as List<BlogPost>,
      'forum': results[3] as List<ForumQuestion>,
    };
  }

  Future<String> getCommunityContext(String query) async {
    // Legacy support for older screens if any
    final snap = await _db.collection(AppConstants.blogsCollection).where('isApproved', isEqualTo: true).limit(3).get();
    return snap.docs.map((d) => "Blog: ${d['title']}").join("\n");
  }

  Future<String> uploadForumMedia(String postId, io.File file, {Uint8List? bytes, Function(double)? onProgress}) async {
    String extension = kIsWeb ? 'jpg' : file.path.split('.').last;
    final ref = _storage.ref().child('forum_media/$postId/${DateTime.now().millisecondsSinceEpoch}.$extension');
    
    UploadTask task;
    if (kIsWeb && bytes != null) {
      task = ref.putData(bytes);
    } else {
      task = ref.putFile(file);
    }
    
    if (onProgress != null) {
      task.snapshotEvents.listen((event) {
        double progress = event.bytesTransferred / event.totalBytes;
        onProgress(progress);
      });
    }

    await task;
    return await ref.getDownloadURL();
  }

  // --- AI Requests (Async Pattern) ---

  Future<String> queueAiRequest({required String userId, required String prompt, required String type}) async {
    final docRef = await _db.collection(AppConstants.aiRequestsCollection).add({
      'userId': userId,
      'prompt': prompt,
      'type': type,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<String> queueTts({required String text, required String languageCode}) async {
    // The extension is configured to listen to 'analysis_history' (as per summary).
    // It likely looks for a field to convert. Let's assume 'text' or 'result'.
    // And 'languageCode' might be needed if extension supports dynamic language selection per doc,
    // or it uses the global config. The summary said "Hindi language (hi-IN)" was configured globally?
    // If globally 'hi-IN', it might ignore 'en'. 
    // However, usually TTS extensions allow overriding language in the document fields.
    
    final docRef = await _db.collection(AppConstants.historyCollection).add({
      'userId': 'temp_tts_request', // Or current user
      'caseType': 'TTS_Request', // Mark as TTS so we can filter if needed
      'summary': 'Audio Request',
      'result': text, // The text to speak. The extension likely reads this.
      'text': text, // Just in case it looks for 'text'
      'language': languageCode, // Try to override language
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'PENDING',
    });
    return docRef.id;
  }
  
  Stream<DocumentSnapshot> streamTtsResult(String docId) {
    return _db.collection(AppConstants.historyCollection).doc(docId).snapshots();
  }

  Stream<DocumentSnapshot> streamAiRequest(String requestId) {
    return _db.collection(AppConstants.aiRequestsCollection).doc(requestId).snapshots();
  }

  // --- Multi-Language Translation ---

  /// Requests translation of a text or a map of texts.
  /// The extension listens to [AppConstants.translationsCollection].
  Future<String> requestTranslation(dynamic input) async {
    final docRef = await _db.collection(AppConstants.translationsCollection).add({
      'input': input,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Streams the translation result for a specific request.
  Stream<DocumentSnapshot> streamTranslation(String translationId) {
    return _db.collection(AppConstants.translationsCollection).doc(translationId).snapshots();
  }

  // --- Document Vault ---

  Future<String> uploadToCloudVault({
    required String userId,
    required String fileName,
    required Uint8List bytes,
    required String category,
    Map<String, dynamic>? metadata,
  }) async {
    final ref = _storage.ref().child('vault/$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName');
    final uploadTask = ref.putData(bytes);
    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    await _db.collection(AppConstants.vaultCollection).add({
      'userId': userId,
      'fileName': fileName,
      'fileUrl': downloadUrl,
      'category': category,
      'metadata': metadata,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return downloadUrl;
  }

  // Helper to get text if we know the storage path
  Stream<DocumentSnapshot?> streamOcrResult(String storagePath) {
    // The extracted_texts collection often uses the storage path specifically or stores it in 'file'
    // Common configuration is path matching. 
    // Let's assume the extension writes to a document where field 'file' == storagePath
    return _db.collection('extracted_texts')
        .where('file', isEqualTo: gsPath(storagePath)) // Helper to ensure gs:// prefix if needed
        .snapshots()
        .map((snap) => snap.docs.isNotEmpty ? snap.docs.first : null);
  }
  
  String gsPath(String path) {
    if (path.startsWith('gs://')) return path;
    // We might need the bucket name here. For now, try partial match or just path if extension is configured to store relative path.
    // The extension usually stores the full gs:// path in the 'file' field.
    // Let's assume we need to format it or the extension is configured to use the file path as ID.
    // Actually, typical extension config saves with document ID = auto, and field 'file' = "gs://bucket/path/to/file".
    return path; // We will handle gs:// prefix in UI or assume path is relative and query differently if needed.
  }



  Future<void> createProBonoRequest({
    required String userId,
    required String draftId, // Cloud Vault ID or similar
    required String docType,
    required String summary,
  }) async {
    await _db.collection(AppConstants.proBonoCollection).add({
      'userId': userId,
      'draftId': draftId,
      'docType': docType,
      'summary': summary,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // --- Case Multi-party Chat ---

  Stream<List<CaseMessage>> streamCaseMessages(String caseId) {
    return _db
        .collection(AppConstants.casesCollection)
        .doc(caseId)
        .collection(AppConstants.caseChatsCollection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => CaseMessage.fromMap(doc.id, doc.data())).toList());
  }

  Future<void> sendCaseMessage(String caseId, CaseMessage message) async {
    await _db
        .collection(AppConstants.casesCollection)
        .doc(caseId)
        .collection(AppConstants.caseChatsCollection)
        .add(message.toMap());
  }

  // --- Child Custody & Co-Parenting ---

  Future<void> saveChildProfile(String userId, CaseChildProfile profile) async {
    await _db
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.childProfilesCollection)
        .doc(profile.id.isEmpty ? null : profile.id)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  Stream<List<CaseChildProfile>> streamChildProfiles(String userId) {
    return _db
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.childProfilesCollection)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => CaseChildProfile.fromMap({...doc.data(), 'id': doc.id})).toList());
  }

  // --- Visitation Events ---

  Future<String> addVisitationEvent(String userId, Map<String, dynamic> event) async {
    final ref = await _db
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection('visitation_events')
        .add({...event, 'createdAt': FieldValue.serverTimestamp()});
    return ref.id;
  }

  Future<void> deleteVisitationEvent(String userId, String eventId) async {
    await _db
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection('visitation_events')
        .doc(eventId)
        .delete();
  }

  Stream<List<Map<String, dynamic>>> streamVisitationEvents(String userId) {
    return _db
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection('visitation_events')
        .orderBy('date')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id}).toList());
  }

  // --- Co-Parent Chat ---

  /// Returns or creates a co-parent chat room keyed by sorted UIDs.
  Future<String> getOrCreateCoParentRoom(String myUid, String partnerUid) async {
    final roomId = ([myUid, partnerUid]..sort()).join('_');
    final ref = _db.collection('coparent_chats').doc(roomId);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'participants': [myUid, partnerUid],
        'createdAt': FieldValue.serverTimestamp(),
        'aiModeration': true,
      });
    }
    return roomId;
  }

  /// Finds an existing co-parent room for the given user (if any).
  Future<String?> getExistingCoParentRoom(String myUid) async {
    final snap = await _db
        .collection('coparent_chats')
        .where('participants', arrayContains: myUid)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty ? snap.docs.first.id : null;
  }

  Future<void> sendCoParentMessage(String roomId, Map<String, dynamic> message) async {
    await _db
        .collection('coparent_chats')
        .doc(roomId)
        .collection('messages')
        .add({...message, 'timestamp': FieldValue.serverTimestamp()});
  }

  Stream<List<Map<String, dynamic>>> streamCoParentMessages(String roomId) {
    return _db
        .collection('coparent_chats')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id}).toList());
  }
}
