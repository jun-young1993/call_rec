import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/call_record.dart';

class RecordingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId => _auth.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _callsRef =>
      _firestore.collection('users').doc(_userId).collection('calls');

  /// 통화 기록 생성 (통화 시작 시)
  /// rooms/{roomName} 에도 역조회 엔트리를 저장해 webhook 매핑에 사용
  Future<String> createCallRecord({
    required String roomUrl,
    required String roomName,
    String? recipientName,
  }) async {
    final doc = await _callsRef.add(CallRecord(
      id: '',
      createdAt: DateTime.now(),
      duration: 0,
      recipientName: recipientName,
      roomUrl: roomUrl,
      roomName: roomName,
      status: CallStatus.pending,
    ).toFirestore());

    // webhook이 callId를 찾을 수 있도록 rooms 컬렉션에 역조회 엔트리 저장
    await _firestore.collection('rooms').doc(roomName).set({
      'userId': _userId,
      'callId': doc.id,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  /// 통화 종료 시 duration만 저장 (recordingUrl/fileHash는 webhook이 처리)
  Future<void> completeCallRecord({
    required String callId,
    required int durationSeconds,
  }) async {
    await _callsRef.doc(callId).update({
      'duration': durationSeconds,
      'status': CallStatus.completed.name,
    });
  }

  /// 통화 기록 실패 처리
  Future<void> failCallRecord(String callId) async {
    await _callsRef.doc(callId).update({
      'status': CallStatus.failed.name,
    });
  }

  /// 통화 목록 스트림
  Stream<List<CallRecord>> watchCallRecords() {
    return _callsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => CallRecord.fromFirestore(doc)).toList());
  }

  /// 개별 통화 기록 실시간 스트림 (webhook 완료 시 자동 갱신)
  Stream<CallRecord?> watchCallRecord(String callId) {
    return _callsRef.doc(callId).snapshots().map(
          (doc) => doc.exists ? CallRecord.fromFirestore(doc) : null,
        );
  }

  /// 개별 통화 기록 조회
  Future<CallRecord?> getCallRecord(String callId) async {
    final doc = await _callsRef.doc(callId).get();
    if (!doc.exists) return null;
    return CallRecord.fromFirestore(doc);
  }

  /// 통화 기록 삭제
  Future<void> deleteCallRecord(String callId) async {
    await _callsRef.doc(callId).delete();
  }
}
