import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/call_record.dart';
import '../providers.dart';

class DetailScreen extends ConsumerStatefulWidget {
  final String callId;

  const DetailScreen({super.key, required this.callId});

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  final _audioPlayer = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // storagePath → getDownloadURL 결과를 캐시
  String? _resolvedPlaybackUrl;
  bool _isResolvingUrl = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });
    _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
  }

  /// Firebase Storage storagePath → 재생 가능한 다운로드 URL 해석
  Future<void> _resolveStorageUrl(String storagePath) async {
    if (_isResolvingUrl || _resolvedPlaybackUrl != null) return;
    setState(() => _isResolvingUrl = true);
    try {
      final url = await FirebaseStorage.instance.ref(storagePath).getDownloadURL();
      if (mounted) setState(() => _resolvedPlaybackUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('녹음 파일 URL을 가져올 수 없습니다')),
        );
      }
    } finally {
      if (mounted) setState(() => _isResolvingUrl = false);
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(String? recordingUrl) async {
    if (recordingUrl == null) return;

    if (_playerState == PlayerState.playing) {
      await _audioPlayer.pause();
    } else {
      try {
        await _audioPlayer.play(UrlSource(recordingUrl));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('녹음 파일을 재생할 수 없습니다. 잠시 후 다시 시도해주세요.')),
          );
        }
      }
    }
  }

  Future<void> _deleteRecord(BuildContext context) async {
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('이 통화 기록을 삭제하시겠습니까?\n녹음 파일도 함께 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(recordingServiceProvider).deleteCallRecord(widget.callId);
      navigator.pop();
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');
    final asyncRecord = ref.watch(callRecordProvider(widget.callId));

    return asyncRecord.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(title: const Text('통화 상세')),
        body: const Center(child: Text('불러오기 실패')),
      ),
      data: (record) {
        if (record == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('통화 상세')),
            body: const Center(child: Text('기록을 찾을 수 없습니다')),
          );
        }

        // storagePath가 있으면 다운로드 URL을 비동기로 해석 (최초 1회)
        final playbackUrl = _resolvedPlaybackUrl ?? record.recordingUrl;
        if (playbackUrl == null && record.storagePath != null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _resolveStorageUrl(record.storagePath!),
          );
        }

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
              '통화 상세',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteRecord(context),
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.recipientName ?? '이름 없음',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${dateFormat.format(record.createdAt)}  ·  ${record.formattedDuration}',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // 오디오 플레이어
              if (playbackUrl != null) ...[
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // 프로그레스 바
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                        ),
                        child: Slider(
                          value: _duration.inSeconds > 0
                              ? _position.inSeconds / _duration.inSeconds
                              : 0,
                          onChanged: (v) {
                            final pos = Duration(
                              seconds: (v * _duration.inSeconds).round(),
                            );
                            _audioPlayer.seek(pos);
                          },
                          activeColor: Colors.black,
                          inactiveColor: Colors.grey.shade200,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_position),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            Text(
                              _formatDuration(_duration),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _togglePlay(playbackUrl),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          icon: Icon(
                            _playerState == PlayerState.playing
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.white,
                          ),
                          label: Text(
                            _playerState == PlayerState.playing ? '일시정지' : '재생',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          record.status == CallStatus.failed
                              ? Icons.error_outline
                              : Icons.hourglass_empty,
                          color: Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          record.status == CallStatus.failed
                              ? '녹음 저장 실패'
                              : '녹음 처리 중... (수 분 소요)',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // 증거 관리 섹션
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  '🗂 증거 관리',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              if (record.fileHash != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                            SizedBox(width: 6),
                            Text(
                              '파일 무결성 (SHA-256)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          record.fileHash!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
