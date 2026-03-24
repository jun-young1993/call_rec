# Recallly

거래처·클라이언트와의 구두 약속 분쟁에 대비하기 위한 **VoIP 통화 녹음 앱**입니다.

> **핵심 아이디어**: 발신자만 앱을 설치합니다. 수신자는 링크만 클릭하면 앱 없이 브라우저로 통화에 참여합니다. 통화는 서버에서 자동으로 클라우드 녹음됩니다.

---

## 왜 만들었나요?

- iOS는 일반 전화 통화를 법적으로 녹음할 수 없습니다.
- 기존 녹음 솔루션은 대부분 기업·콜센터 전용으로 개인 사용자가 쓰기 어렵습니다.
- 구두 계약, 업무 지시, 대금 협의 등을 녹음해 두면 분쟁 시 결정적 증거가 됩니다.

---

## 전체 동작 흐름

```
┌──────────────────────────────────────────────────────────────────┐
│                       Recallly 아키텍처                           │
└──────────────────────────────────────────────────────────────────┘

  [발신자 앱 (Flutter)]                    [수신자 브라우저 (join.html)]
         │                                          │
         │ 1. Daily.co 방 생성 (API 호출)            │
         │    → Firestore에 통화 기록 저장            │
         │    → rooms/{roomName} 역조회 저장          │
         │                                          │
         │ 2. 링크 공유 ────────────────────────────▶│ 3. 동의 화면 표시
         │    (room, callId, roomUrl 포함)           │    (녹음 고지)
         │                                          │
         ▼                                          ▼
  [Daily.co 방 입장]  ◀──────────── 마이크 권한 승인 후 입장
         │
         │ 서버사이드 클라우드 녹음 진행 중...
         │
   통화 종료
         │ 4. completeCallRecord() 호출
         │    Firestore: duration 저장, status=pending
         │
         ▼
  [Daily.co 서버 녹음 처리 완료]
         │
         │ 5. recording.ready 웹훅 전송
         ▼
  [Firebase Cloud Function]
         │ 6. HMAC-SHA256 서명 검증
         │ 7. rooms/{roomName} → userId, callId 조회
         │ 8. 녹음 파일 다운로드
         │ 9. Firebase Storage 업로드
         │    경로: recordings/{userId}/{callId}/recording.mp4
         │ 10. SHA-256 해시 계산 (무결성 증명)
         │ 11. Firestore 업데이트:
         │     storagePath, fileHash 저장
         │     (status는 통화 종료 시 이미 저장됨)
         ▼
  [DetailScreen 실시간 갱신]
         │ Firestore 스트림이 storagePath 감지
         │ → FirebaseStorage.getDownloadURL() 호출
         ▼
  [녹음 재생 가능 + SHA-256 해시 표시]
```

---

## 기술 스택

| 영역 | 기술 | 역할 |
|------|------|------|
| 앱 | Flutter (Dart 3.4+) | iOS/Android 크로스플랫폼 앱 |
| 상태 관리 | flutter_riverpod | 전역 상태 / 스트림 관리 |
| VoIP | daily_flutter 0.37 | WebRTC 기반 통화 (Daily.co SDK) |
| 인증 | Firebase Auth (익명) | 사용자 식별 (앱 설치 없이 즉시 사용) |
| DB | Cloud Firestore | 통화 기록 실시간 저장·조회 |
| 저장소 | Firebase Storage | 녹음 MP4 파일 영구 보관 |
| 백엔드 | Firebase Cloud Functions v2 | Daily.co 웹훅 처리 |
| 수신자 웹 | 순수 HTML/JS + Daily.co Web SDK | 브라우저 통화 참여 페이지 |
| 호스팅 | Firebase Hosting | join.html 배포 |

---

## 프로젝트 구조

```
call_rec/
├── lib/
│   ├── main.dart                  # 앱 진입점 + Firebase 초기화 + 에러 처리
│   ├── providers.dart             # Riverpod 전역 Provider 정의
│   ├── models/
│   │   └── call_record.dart       # 통화 기록 데이터 모델 (Firestore ↔ Dart)
│   ├── services/
│   │   ├── auth_service.dart      # Firebase 익명 로그인
│   │   ├── call_service.dart      # Daily.co API (방 생성, 토큰 발급)
│   │   └── recording_service.dart # Firestore CRUD + 스트림
│   └── screens/
│       ├── home_screen.dart       # 통화 기록 목록
│       ├── new_call_screen.dart   # 새 통화 생성 + 링크 공유
│       ├── active_call_screen.dart# 통화 중 화면 (Daily.co 연결)
│       └── detail_screen.dart     # 통화 상세 + 녹음 재생 + SHA-256
│
├── functions/
│   ├── index.js                   # Firebase Cloud Function (웹훅 처리)
│   ├── index.test.js              # Jest 단위 테스트 (서명 검증, 웹훅 흐름)
│   └── package.json               # Node 20, firebase-admin, jest
│
├── public/
│   └── join.html                  # 수신자 브라우저 통화 참여 페이지
│
├── firestore.rules                # Firestore 보안 규칙 (본인 데이터만 접근)
├── storage.rules                  # Storage 보안 규칙 (본인 녹음만 다운로드)
├── firebase.json                  # Firebase Hosting + Functions + 규칙 설정
└── TODOS.md                       # 남은 작업 목록 (P1/P2/P3)
```

---

## 화면 설명

### 1. 홈 화면 (`home_screen.dart`)
통화 기록 목록을 보여줍니다. Firestore 스트림으로 실시간 업데이트됩니다.
- 녹음 완료: `🔴 녹음` 뱃지 표시
- 처리 중: 로딩 스피너 표시

### 2. 새 통화 화면 (`new_call_screen.dart`)
Daily.co 방을 생성하고 참여 링크를 공유합니다.
- 링크 형식: `https://your-project.web.app/join.html?room=rc-xxx&callId=yyy&roomUrl=https://...`
- 상대방은 링크를 클릭하면 브라우저에서 바로 통화 참여 (앱 설치 불필요)

### 3. 통화 중 화면 (`active_call_screen.dart`)
Daily.co WebRTC로 실제 통화를 진행합니다.
- 상대방 입장 감지 → 타이머 시작
- 음소거 버튼 지원
- 통화 종료 시 Firestore에 통화 시간 저장

### 4. 통화 상세 화면 (`detail_screen.dart`)
Firestore 스트림으로 실시간 업데이트됩니다. 웹훅이 녹음을 처리하면 UI가 자동 갱신됩니다.
- `storagePath` 감지 → Firebase Storage에서 다운로드 URL 자동 획득
- 슬라이더로 재생 위치 조절
- SHA-256 해시로 파일 무결성 증명

---

## 수신자 웹페이지 (`public/join.html`)

수신자가 링크를 클릭하면 다음 화면이 차례로 표시됩니다.

```
1. 동의 화면
   ┌────────────────────────────┐
   │ Recallly                   │
   │                            │
   │ 🔴 녹음 고지               │
   │ 이 통화는 자동으로 녹음 및  │
   │ 저장됩니다...               │
   │                            │
   │ [동의하고 통화 참여]        │
   │ [거부 (통화 취소)]         │
   └────────────────────────────┘

2. 마이크 권한 요청 (브라우저)

3. 통화 중 화면
   ┌────────────────────────────┐
   │ 🔴 녹음 중                 │
   │        📞                  │
   │   Recallly 통화            │
   │     통화 연결됨            │
   │       01:23                │
   │ [🎤 음소거] [📵 종료]      │
   └────────────────────────────┘
```

---

## 데이터 모델

### Firestore 구조

```
users/
  {userId}/
    calls/
      {callId}/
        createdAt: Timestamp      # 통화 시작 시각
        duration: int             # 통화 시간 (초) — 통화 종료 시 저장
        recipientName: string?    # 상대방 이름 (선택)
        roomUrl: string           # Daily.co 방 WebRTC URL
        roomName: string          # Daily.co 방 이름 (웹훅 역조회용)
        storagePath: string?      # Firebase Storage 경로 (웹훅 완료 후 저장)
        fileHash: string?         # SHA-256 해시 (무결성 증명)
        status: 'pending' | 'completed' | 'failed'

rooms/
  {roomName}/
    userId: string                # 웹훅에서 callId를 찾기 위한 역조회 인덱스
    callId: string
    createdAt: Timestamp
```

### Firebase Storage 구조

```
recordings/
  {userId}/
    {callId}/
      recording.mp4               # 통화 녹음 파일
```

---

## Cloud Function 동작 원리 (`functions/index.js`)

Daily.co가 녹음을 완료하면 웹훅으로 알림을 보냅니다. Firebase Cloud Function이 이를 처리합니다.

```javascript
// 처리 순서:
// 1. HMAC-SHA256 서명 검증 (Daily.co 위장 방지)
// 2. rooms/{roomName} 조회 → userId, callId 획득
// 3. Daily.co에서 MP4 다운로드
// 4. SHA-256 해시 계산
// 5. Firebase Storage 업로드: recordings/{userId}/{callId}/recording.mp4
// 6. Firestore 업데이트: storagePath, fileHash 저장
//    (앱이 storagePath를 감지하면 자동으로 getDownloadURL() 호출)
```

**왜 signed URL을 쓰지 않나요?**
Firebase Cloud Functions v2는 서비스 계정 키 없이 signed URL을 생성할 수 없습니다. 대신 `storagePath`를 Firestore에 저장하고, 클라이언트가 Firebase Storage SDK의 `getDownloadURL()`을 직접 호출합니다. Storage 규칙이 본인 파일만 접근하도록 제한합니다.

---

## 보안 설계

### Firestore 규칙
본인의 통화 기록만 읽기/쓰기 가능합니다.
```javascript
match /users/{userId}/calls/{callId} {
  allow read, write: if request.auth.uid == userId;
}
```

### Storage 규칙
본인의 녹음 파일만 다운로드 가능합니다. 쓰기는 Cloud Function(Admin SDK)만 허용합니다.
```javascript
match /recordings/{userId}/{callId}/{allPaths=**} {
  allow read: if request.auth.uid == userId;
  allow write: if false;
}
```

---

## 처음 실행하기 전에

### 1. Firebase 프로젝트 설정 (필수)

```bash
# Firebase CLI 설치
npm install -g firebase-tools
firebase login

# 프로젝트 ID를 .firebaserc에 입력
# .firebaserc: "default": "YOUR_FIREBASE_PROJECT_ID"
```

Firebase Console에서:
- Android: `google-services.json` → `android/app/`
- iOS: `GoogleService-Info.plist` → `ios/Runner/`
- Authentication → 익명 로그인 활성화
- Firestore → 데이터베이스 생성

```bash
# 규칙 및 Functions 배포
firebase deploy
```

### 2. Daily.co 설정 (필수)

1. [dashboard.daily.co](https://dashboard.daily.co) → Developers → API Keys → 키 발급
2. Webhooks → URL: `https://us-central1-{project}.cloudfunctions.net/dailyRecordingWebhook`
3. Secret 설정:
   ```bash
   firebase functions:secrets:set DAILY_WEBHOOK_SECRET
   firebase functions:secrets:set DAILY_API_KEY
   ```

### 3. join.html URL 업데이트

`lib/screens/new_call_screen.dart`에서 Firebase Hosting 실제 URL로 교체:
```dart
// 변경 전
'https://your-project.web.app/join.html?...'
// 변경 후
'https://{실제-프로젝트-ID}.web.app/join.html?...'
```

### 4. 앱 빌드

```bash
flutter pub get
flutter run --dart-define=DAILY_API_KEY=your_daily_api_key
```

---

## 테스트

### Cloud Function 단위 테스트

```bash
cd functions
npm install
npm test
```

테스트 항목:
- HMAC 서명 검증 (정상 / 위조)
- `recording.ready` 이벤트 happy path
- 방을 찾을 수 없는 경우 (200 반환으로 재전송 방지)
- 다른 이벤트 타입 무시

---

## 남은 작업 (`TODOS.md` 참조)

| 우선순위 | 항목 | 이유 |
|----------|------|------|
| P1 | 전화번호 인증 | 법적 분쟁 시 "누가 녹음했는가" 신원 증명 |
| P1 | Firebase 프로젝트 실제 설정 | 앱 실행에 필수 |
| P1 | Daily.co 실제 설정 | 녹음에 필수 |
| P2 | 스피커 버튼 구현 | `CallClient.setAudioDevice()` |
| P2 | 마이크 권한 명시적 요청 | `permission_handler` 이미 추가됨 |
| P2 | Firebase Crashlytics | 운영 환경 모니터링 |
| P3 | PDF 내보내기 | 법적 증거 패키지 |
| P3 | AI 전사 (Whisper) | 분쟁 내용 텍스트 검색 |

---

## 주요 설계 결정

**왜 VoIP인가?**
iOS에서 일반 전화 통화를 앱으로 가로채 녹음하는 것은 불가능합니다. Daily.co VoIP를 사용하면 서버사이드 클라우드 녹음이 가능하고, 수신자는 앱 설치 없이 브라우저로 참여할 수 있습니다.

**왜 익명 인증인가?**
MVP 단계에서 마찰을 최소화합니다. 전화번호 인증은 P1 TODO로 관리됩니다. SHA-256 해시와 Daily.co 서버 타임스탬프가 녹음의 진본성을 증명하는 역할을 합니다.

**왜 Firestore 스트림인가?**
녹음은 통화 종료 후 수 분이 지나야 처리됩니다. `FutureBuilder` 대신 `StreamProvider`를 사용해 DetailScreen이 웹훅 완료를 실시간으로 감지하고 자동 업데이트됩니다.
