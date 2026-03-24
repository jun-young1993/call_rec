# Recallly TODOS

## P1 (MVP 출시 전 필수)

- [ ] **전화번호 인증 추가** — Firebase Phone Auth로 마이그레이션
  - Why: 법적 분쟁 시 "누가 녹음했는가" 증명 필요. 익명 인증은 신원 연결 불가.
  - Where to start: `lib/services/auth_service.dart`, Firebase Console → Authentication → Phone
  - Effort: M (~4h)

- [ ] **Firebase 프로젝트 설정** (유저 액션)
  - [ ] `google-services.json` → `android/app/`
  - [ ] `GoogleService-Info.plist` → `ios/Runner/`
  - [ ] `.firebaserc` 프로젝트 ID 업데이트
  - [ ] `firebase deploy` (Hosting + Functions + Firestore rules + Storage rules)

- [ ] **Daily.co 설정** (유저 액션)
  - [ ] `dashboard.daily.co` → Developers → API Keys → 키 발급
  - [ ] Webhooks → URL: `https://us-central1-{project}.cloudfunctions.net/dailyRecordingWebhook`
  - [ ] Secret 설정 → `firebase functions:secrets:set DAILY_WEBHOOK_SECRET`
  - [ ] `flutter run --dart-define=DAILY_API_KEY=your_key`

- [ ] **join.html URL 업데이트** — `new_call_screen.dart`의 `joinLink` 변수를 실제 Firebase Hosting URL로 교체

## P2 (출시 후 첫 개선)

- [ ] **스피커 버튼 구현** — `active_call_screen.dart`의 빈 onTap을 `CallClient.setAudioDevice()`로 교체
  - Effort: S (~1h)

- [ ] **통화 목록 페이지네이션** — `recording_service.dart::watchCallRecords()`에 `.limit(20)` + 무한 스크롤
  - Effort: M (~2h)

- [ ] **Firebase Crashlytics** — `firebase_crashlytics` 패키지 추가, 앱 크래시 모니터링
  - Effort: S (~1h)

- [ ] **마이크 권한 명시적 요청** — `permission_handler` 패키지가 이미 추가됨, 실제 요청 로직 추가
  - Where: `active_call_screen.dart::_initCall()` 시작 부분
  - Effort: S (~1h)

## P3 (향후 기능)

- [ ] **통화 기록 내보내기 (PDF)** — 날짜, 상대방, 통화 시간, SHA-256 해시 포함한 법적 증거 패키지
- [ ] **AI 전사 (Whisper API 또는 Clova)** — 분쟁 내용 텍스트 검색
- [ ] **통화 기록 검색** — 상대방 이름, 날짜 범위 필터
- [ ] **오프라인 녹음 백업** — 네트워크 불안정 시 로컬 저장 후 동기화
- [ ] **CallKit 통합 (iOS)** — 수신 알림, 통화 화면 전환

---

_Last updated: 2026-03-24 (CEO Review 완료 후)_
