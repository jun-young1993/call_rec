import 'package:cloud_firestore/cloud_firestore.dart';

enum CallStatus { pending, completed, failed }

class CallRecord {
  final String id;
  final DateTime createdAt;
  final int duration; // seconds
  final String? recipientName;
  final String roomUrl;
  final String roomName; // Daily.co short room name (webhook 매핑용)
  final String? recordingUrl;
  final String? storagePath; // Firebase Storage 경로 (webhook 완료 후 설정)
  final String? fileHash;
  final CallStatus status;

  const CallRecord({
    required this.id,
    required this.createdAt,
    required this.duration,
    this.recipientName,
    required this.roomUrl,
    required this.roomName,
    this.recordingUrl,
    this.storagePath,
    this.fileHash,
    required this.status,
  });

  factory CallRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CallRecord(
      id: doc.id,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      duration: data['duration'] ?? 0,
      recipientName: data['recipientName'],
      roomUrl: data['roomUrl'] ?? '',
      roomName: data['roomName'] ?? '',
      recordingUrl: data['recordingUrl'],
      storagePath: data['storagePath'],
      fileHash: data['fileHash'],
      status: CallStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'pending'),
        orElse: () => CallStatus.pending,
      ),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'createdAt': Timestamp.fromDate(createdAt),
        'duration': duration,
        if (recipientName != null) 'recipientName': recipientName,
        'roomUrl': roomUrl,
        'roomName': roomName,
        if (recordingUrl != null) 'recordingUrl': recordingUrl,
        if (storagePath != null) 'storagePath': storagePath,
        if (fileHash != null) 'fileHash': fileHash,
        'status': status.name,
      };

  CallRecord copyWith({
    int? duration,
    String? recordingUrl,
    String? storagePath,
    String? fileHash,
    CallStatus? status,
  }) =>
      CallRecord(
        id: id,
        createdAt: createdAt,
        duration: duration ?? this.duration,
        recipientName: recipientName,
        roomUrl: roomUrl,
        roomName: roomName,
        recordingUrl: recordingUrl ?? this.recordingUrl,
        storagePath: storagePath ?? this.storagePath,
        fileHash: fileHash ?? this.fileHash,
        status: status ?? this.status,
      );

  String get formattedDuration {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '$minutes분 ${seconds.toString().padLeft(2, '0')}초';
  }
}
