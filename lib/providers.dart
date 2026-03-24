import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/auth_service.dart';
import 'services/call_service.dart';
import 'services/recording_service.dart';
import 'models/call_record.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final callServiceProvider = Provider<CallService>((ref) => CallService());
final recordingServiceProvider = Provider<RecordingService>((ref) => RecordingService());

final callRecordsProvider = StreamProvider<List<CallRecord>>((ref) {
  final recordingService = ref.watch(recordingServiceProvider);
  return recordingService.watchCallRecords();
});

final callRecordProvider =
    StreamProvider.family<CallRecord?, String>((ref, callId) {
  final recordingService = ref.watch(recordingServiceProvider);
  return recordingService.watchCallRecord(callId);
});
