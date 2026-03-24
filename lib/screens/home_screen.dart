import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/call_record.dart';
import '../providers.dart';
import 'new_call_screen.dart';
import 'detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callsAsync = ref.watch(callRecordsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '통화 기록',
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            onPressed: () {
              // TODO: 검색 화면
            },
          ),
        ],
      ),
      body: callsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (calls) {
          if (calls.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            itemCount: calls.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              return _CallListItem(
                record: calls[index],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DetailScreen(callId: calls[index].id),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NewCallScreen()),
        ),
        backgroundColor: Colors.black,
        icon: const Icon(Icons.phone, color: Colors.white),
        label: const Text(
          '새 통화',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _CallListItem extends StatelessWidget {
  final CallRecord record;
  final VoidCallback onTap;

  const _CallListItem({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('M월 d일 HH:mm');

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: Colors.grey.shade200,
        child: Text(
          record.recipientName?.isNotEmpty == true
              ? record.recipientName![0]
              : '?',
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      title: Text(
        record.recipientName ?? '이름 없음',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        '${dateFormat.format(record.createdAt)}  ·  ${record.formattedDuration}',
        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
      ),
      trailing: record.status == CallStatus.completed
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFCCCC)),
              ),
              child: const Text(
                '🔴 녹음',
                style: TextStyle(fontSize: 11, color: Color(0xFFCC4444)),
              ),
            )
          : record.status == CallStatus.pending
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.phone_missed, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '통화 기록이 없습니다',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '새 통화 버튼을 눌러 시작하세요',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
