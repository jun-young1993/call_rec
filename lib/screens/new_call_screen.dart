import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../providers.dart';
import 'active_call_screen.dart';

class NewCallScreen extends ConsumerStatefulWidget {
  const NewCallScreen({super.key});

  @override
  ConsumerState<NewCallScreen> createState() => _NewCallScreenState();
}

class _NewCallScreenState extends ConsumerState<NewCallScreen> {
  final _nameController = TextEditingController();
  bool _autoRecord = true;
  bool _isCreating = false;
  String? _generatedLink;
  String? _roomName;
  String? _roomUrl;
  String? _callId;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createAndShareLink() async {
    if (_isCreating) return;
    setState(() => _isCreating = true);

    try {
      final callService = ref.read(callServiceProvider);
      final recordingService = ref.read(recordingServiceProvider);

      final room = await callService.createRoom();
      final callId = await recordingService.createCallRecord(
        roomUrl: room.roomUrl,
        roomName: room.roomName,
        recipientName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
      );

      // TODO: Firebase Hosting 배포 후 실제 도메인으로 교체
      // roomUrl을 URL-encode해서 join.html이 직접 Daily.co에 접속할 수 있게 전달
      final encodedRoomUrl = Uri.encodeComponent(room.roomUrl);
      final joinLink =
          'https://your-project.web.app/join.html?room=${room.roomName}&callId=$callId&roomUrl=$encodedRoomUrl';

      setState(() {
        _generatedLink = joinLink;
        _roomName = room.roomName;
        _roomUrl = room.roomUrl;
        _callId = callId;
      });

      await Share.share(
        '📞 Recallly 통화 참여 링크\n\n아래 링크를 클릭하면 설치 없이 바로 통화할 수 있습니다:\n$joinLink\n\n이 통화는 녹음됩니다.',
        subject: 'Recallly 통화 참여',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('링크 생성 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _startCall() {
    if (_roomName == null || _roomUrl == null || _callId == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveCallScreen(
          roomName: _roomName!,
          roomUrl: _roomUrl!,
          callId: _callId!,
          recipientName: _nameController.text.trim().isEmpty
              ? '상대방'
              : _nameController.text.trim(),
          autoRecord: _autoRecord,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '새 통화',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '상대방은 링크만 클릭하면 됩니다\n앱 설치 불필요',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // 상대방 이름
            const Text(
              '상대방 이름 (선택)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: '예: 김클라이언트',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 자동 녹음 토글
            _ToggleRow(
              icon: Icons.fiber_manual_record,
              iconColor: Colors.red,
              title: '자동 녹음',
              subtitle: '통화 시작 즉시 녹음',
              value: _autoRecord,
              onChanged: (v) => setState(() => _autoRecord = v),
            ),
            const Divider(height: 1),

            const SizedBox(height: 24),

            // 생성된 링크 표시
            if (_generatedLink != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.link, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        const Text(
                          '참여 링크 (자동 생성)',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: _generatedLink!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('링크가 복사되었습니다')),
                            );
                          },
                          child: const Icon(Icons.copy, size: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _generatedLink!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4477CC),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '상대방이 링크를 클릭하면 자동 연결됩니다',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 통화 시작 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startCall,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.phone, color: Colors.white),
                  label: const Text(
                    '통화 화면으로 이동',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _createAndShareLink,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('링크 다시 공유'),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isCreating ? null : _createAndShareLink,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: _isCreating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.share, color: Colors.white),
                  label: Text(
                    _isCreating ? '링크 생성 중...' : '링크 공유 후 통화 대기',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            Center(
              child: Text(
                '상대방이 링크를 클릭하면 자동으로 연결됩니다',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.black,
          ),
        ],
      ),
    );
  }
}
