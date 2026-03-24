import 'dart:async';
import 'package:daily_flutter/daily_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

class ActiveCallScreen extends ConsumerStatefulWidget {
  final String roomName;
  final String roomUrl;
  final String callId;
  final String recipientName;
  final bool autoRecord;

  const ActiveCallScreen({
    super.key,
    required this.roomName,
    required this.roomUrl,
    required this.callId,
    required this.recipientName,
    required this.autoRecord,
  });

  @override
  ConsumerState<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends ConsumerState<ActiveCallScreen> {
  CallClient? _client;
  bool _isMuted = false;
  bool _isRecording = false;
  bool _isConnected = false;
  int _durationSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initCall();
  }

  Future<void> _initCall() async {
    try {
      final client = await CallClient.create();
      _client = client;

      client.events.listen(_onCallEvent);

      final callService = ref.read(callServiceProvider);
      final token = await callService.createMeetingToken(widget.roomName);

      await client.join(
        url: Uri.parse(widget.roomUrl),
        token: token,
        clientSettings: const ClientSettingsUpdate.set(
          inputs: InputSettingsUpdate.set(
            microphone: MicrophoneInputSettingsUpdate.set(
              isEnabled: BoolUpdate.set(true),
            ),
            camera: CameraInputSettingsUpdate.set(
              isEnabled: BoolUpdate.set(false),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('통화 연결 실패: $e')),
        );
      }
    }
  }

  void _onCallEvent(Event event) {
    if (!mounted) return;
    switch (event) {
      case ParticipantJoinedEvent(:final participant):
        if (!participant.info.isLocal && !_isConnected) {
          setState(() {
            _isConnected = true;
            if (widget.autoRecord) _isRecording = true;
          });
          _startTimer();
        }
      case ParticipantLeftEvent(:final participant):
        if (!participant.info.isLocal) {
          _endCall();
        }
      default:
        break;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _durationSeconds++);
    });
  }

  Future<void> _toggleMute() async {
    final client = _client;
    if (client == null) return;
    await client.updateInputs(
      inputs: InputSettingsUpdate.set(
        microphone: MicrophoneInputSettingsUpdate.set(
          isEnabled: BoolUpdate.set(!_isMuted),
        ),
      ),
    );
    if (mounted) setState(() => _isMuted = !_isMuted);
  }

  Future<void> _endCall() async {
    _timer?.cancel();
    final navigator = Navigator.of(context);
    final client = _client;
    if (client != null) {
      await client.leave();
      await client.dispose();
      _client = null;
    }

    if (mounted) {
      final recordingService = ref.read(recordingServiceProvider);
      await recordingService.completeCallRecord(
        callId: widget.callId,
        durationSeconds: _durationSeconds,
      );
      navigator.popUntil((route) => route.isFirst);
    }
  }

  String get _formattedDuration {
    final m = _durationSeconds ~/ 60;
    final s = _durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _client?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: const Color(0xFF2A2A2A),
              child: const Text(
                '📢 이 통화는 녹음됩니다 (양측 고지 완료)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF888888), fontSize: 12),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: const Color(0xFF333333),
                    child: Text(
                      widget.recipientName.isNotEmpty
                          ? widget.recipientName[0]
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.recipientName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isConnected ? '통화 연결됨' : '연결 대기 중...',
                    style: const TextStyle(
                      color: Color(0xFF999999),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isRecording)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCC4444),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '녹음 중',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    _formattedDuration,
                    style: const TextStyle(
                      color: Color(0xFFCCCCCC),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: const Color(0xFF1A1A1A),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    label: _isMuted ? '해제' : '음소거',
                    onTap: _toggleMute,
                  ),
                  _ControlButton(
                    icon: Icons.call_end,
                    label: '종료',
                    backgroundColor: const Color(0xFFCC4444),
                    onTap: _endCall,
                  ),
                  _ControlButton(
                    icon: Icons.volume_up,
                    label: '스피커',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? backgroundColor;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: backgroundColor ?? const Color(0xFF333333),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF888888), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
