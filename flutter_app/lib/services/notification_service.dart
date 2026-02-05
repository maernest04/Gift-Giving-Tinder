import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Handles push notifications for partner events (new interests, requests, etc.)
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String? _fcmToken;
  StreamSubscription<DocumentSnapshot>? _partnerSubscription;
  StreamSubscription<QuerySnapshot>? _requestSubscription;

  /// Initialize notifications and set up listeners
  Future<void> initialize() async {
    // Request permission (iOS)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get FCM token and save to user document
      _fcmToken = await _messaging.getToken();
      await _saveFcmToken();
      
      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _saveFcmToken();
      });
      
      // Set up listeners for partner events
      _setupPartnerListeners();
    }
  }

  /// Save FCM token to current user's document
  Future<void> _saveFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _fcmToken == null) return;
    
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': _fcmToken,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  /// Set up listeners for partner-related events
  void _setupPartnerListeners() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Listen for partner preference changes (new interests)
    _firestore.collection('users').doc(user.uid).snapshots().listen((snapshot) {
      if (!snapshot.exists) return;
      final data = snapshot.data()!;
      final partnerId = data['partnerId'] as String?;
      
      if (partnerId != null) {
        // Cancel old subscription if partner changed
        _partnerSubscription?.cancel();
        
        // Listen to partner's preferences for new interests
        _partnerSubscription = _firestore
            .collection('userPreferences')
            .doc(partnerId)
            .snapshots()
            .listen((prefSnapshot) {
          if (prefSnapshot.exists) {
            final prefData = prefSnapshot.data()!;
            final updatedAt = prefData['updatedAt'] as Timestamp?;
            final lastChecked = data['lastPartnerInterestsCheck'] as Timestamp?;
            
            // If partner updated preferences after our last check, notify
            if (updatedAt != null && 
                (lastChecked == null || updatedAt.compareTo(lastChecked) > 0)) {
              _notifyPartnerNewInterests();
              
              // Update last check timestamp
              _firestore.collection('users').doc(user.uid).update({
                'lastPartnerInterestsCheck': FieldValue.serverTimestamp(),
              });
            }
          }
        });
      } else {
        _partnerSubscription?.cancel();
      }
    });

    // Listen for incoming partner requests
    _requestSubscription?.cancel();
    _requestSubscription = _firestore
        .collection('partner_requests')
        .where('toUid', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        _notifyPartnerRequest();
      }
    });
  }

  /// Send notification: partner added new interests
  Future<void> _notifyPartnerNewInterests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Get partner name
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final partnerId = userDoc.data()?['partnerId'] as String?;
    if (partnerId == null) return;
    
    final partnerDoc = await _firestore.collection('users').doc(partnerId).get();
    final partnerName = partnerDoc.data()?['name'] as String? ?? 'Your partner';
    
    // In a real app, you'd send a push notification via FCM Admin SDK or Cloud Functions
    // For now, we'll use local notifications or a simple in-app notification system
    debugPrint('📬 Notification: $partnerName has added new interests!');
    
    // TODO: Implement actual push notification via Cloud Functions or FCM Admin SDK
    // This requires backend code to send notifications to the partner's FCM token
  }

  /// Send notification: partner request received
  Future<void> _notifyPartnerRequest() async {
    debugPrint('📬 Notification: You have a partner request!');
    // TODO: Implement actual push notification
  }

  /// Send notification: partner request accepted
  Future<void> notifyRequestAccepted(String partnerName) async {
    debugPrint('📬 Notification: Your invite was accepted by $partnerName!');
    // TODO: Implement actual push notification
  }

  /// Send notification: partner request declined
  Future<void> notifyRequestDeclined() async {
    debugPrint('📬 Notification: Your partner request was declined.');
    // TODO: Implement actual push notification
  }

  /// Send notification: partner removed you
  Future<void> notifyPartnerRemoved() async {
    debugPrint('📬 Notification: Your partner has removed the link.');
    // TODO: Implement actual push notification
  }

  /// Clean up listeners
  void dispose() {
    _partnerSubscription?.cancel();
    _requestSubscription?.cancel();
  }
}

final notificationService = NotificationService();
