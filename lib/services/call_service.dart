import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// Daily.co API 연동 서비스
/// API Key는 환경 변수 또는 앱 설정에서 주입
class CallService {
  // TODO: Firebase Remote Config 또는 앱 설정에서 로드
  static const String _dailyApiKey = String.fromEnvironment(
    'DAILY_API_KEY',
    defaultValue: '',
  );
  static const String _dailyBaseUrl = 'https://api.daily.co/v1';

  final _uuid = const Uuid();

  /// API Key 설정 여부 확인
  static bool get isConfigured => _dailyApiKey.isNotEmpty;

  /// Daily.co room 생성 + 참여 링크 반환
  Future<({String roomName, String roomUrl})> createRoom() async {
    if (_dailyApiKey.isEmpty) {
      throw Exception('Daily.co API Key가 설정되지 않았습니다. --dart-define=DAILY_API_KEY=xxx 로 빌드하세요.');
    }
    final roomName = 'rc-${_uuid.v4().substring(0, 8)}';

    final response = await http.post(
      Uri.parse('$_dailyBaseUrl/rooms'),
      headers: {
        'Authorization': 'Bearer $_dailyApiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': roomName,
        'properties': {
          'enable_recording': 'cloud',
          'enable_chat': false,
          'enable_screenshare': false,
          'exp': DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch ~/ 1000,
          'max_participants': 2,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create room: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      roomName: data['name'] as String,
      roomUrl: data['url'] as String,
    );
  }

  /// 특정 room의 녹음 파일 URL 조회
  Future<String?> getRecordingUrl(String roomName) async {
    final response = await http.get(
      Uri.parse('$_dailyBaseUrl/recordings?room_name=$roomName&limit=1'),
      headers: {'Authorization': 'Bearer $_dailyApiKey'},
    );

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final recordings = data['data'] as List<dynamic>? ?? [];
    if (recordings.isEmpty) return null;

    final recordingId = recordings.first['id'] as String;

    // 다운로드 링크 요청
    final linkResponse = await http.get(
      Uri.parse('$_dailyBaseUrl/recordings/$recordingId/access-link'),
      headers: {'Authorization': 'Bearer $_dailyApiKey'},
    );

    if (linkResponse.statusCode != 200) return null;
    final linkData = jsonDecode(linkResponse.body) as Map<String, dynamic>;
    return linkData['download_link'] as String?;
  }

  /// 참여 토큰 생성 (호스트용)
  Future<String> createMeetingToken(String roomName) async {
    final response = await http.post(
      Uri.parse('$_dailyBaseUrl/meeting-tokens'),
      headers: {
        'Authorization': 'Bearer $_dailyApiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'properties': {
          'room_name': roomName,
          'is_owner': true,
          'start_cloud_recording': true,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create meeting token: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['token'] as String;
  }
}
