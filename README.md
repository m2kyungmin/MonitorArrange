# MonitorArrange

외장 모니터를 움직일 때마다 디스플레이 정렬을 자동으로 바꿔주는 macOS 메뉴바 앱입니다.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)

## 작동 원리

맥북 화면 가장자리에서 마우스를 **밀어내면**, 해당 방향으로 외장 모니터 배치가 자동 변경됩니다.

예를 들어 외장 모니터를 맥북 왼쪽에 놓았다면, 맥북 화면 왼쪽 가장자리로 마우스를 밀면 됩니다. 시스템 설정의 디스플레이 정렬이 자동으로 바뀝니다.

단순히 커서가 가장자리에 있는 것이 아니라, 마우스 **델타(이동량)**가 가장자리 방향으로 계속 발생하는지 감지하므로 메뉴바 클릭 등에 의한 오작동이 방지됩니다.

## 기능

- **자동 엣지 감지** — 화면 가장자리에서 마우스를 밀면 외장 모니터 배치 자동 변경 (상/하/좌/우)
- **수동 전환** — 메뉴바에서 클릭으로 즉시 변경
- **되돌리기** — 오작동 시 이전 위치로 복원
- **가장자리 표시(글로우)** — 외장 모니터가 붙어있는 방향을 맥북·외장 양쪽 맞닿는 가장자리에 은은하게 표시. 위치 변경 시 깜빡임 / 커서 근접 시 / 항상 표시 중 선택, 색상·투명도 조절 가능
- **메뉴바 아이콘** — 현재 외장 모니터 위치를 방향 아이콘으로 표시
- **감지 시간 조절** — 0.1초 ~ 2.0초 (기본 0.1초)
- **로그인 시 자동 실행**
- **위치 변경 알림**

## 설치

### 요구 사항

- macOS 14.0 이상
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (프로젝트 생성용)

### 빌드

```bash
# XcodeGen으로 Xcode 프로젝트 생성
xcodegen generate

# 빌드
xcodebuild -project MonitorArrange.xcodeproj -scheme MonitorArrange -configuration Release build

# 응용 프로그램에 복사
cp -R ~/Library/Developer/Xcode/DerivedData/MonitorArrange-*/Build/Products/Release/MonitorArrange.app /Applications/
```

> **코드 서명** — 프로젝트는 automatic 서명을 사용합니다. Xcode로 열면 본인 Apple 계정/팀이 자동 선택되어 그대로 빌드됩니다. CLI로 빌드할 땐 본인 팀 ID를 넘기세요:
> ```bash
> xcodebuild ... -allowProvisioningUpdates DEVELOPMENT_TEAM=<YOUR_TEAM_ID> build
> ```
> Apple 계정이 없으면 Xcode의 Signing & Capabilities에서 **"Sign to Run Locally"**(ad-hoc)로 바꿔 빌드할 수 있습니다. 단, ad-hoc은 재빌드 때마다 손쉬운 사용 권한을 다시 부여해야 합니다.
>
> 이 앱은 배포용 공증(notarization)이 되어 있지 않으므로, 다른 곳에서 받은 `.app`을 처음 열 땐 **우클릭 → 열기**로 Gatekeeper 경고를 통과해야 합니다.

### 권한 설정

앱 실행 후 **시스템 설정 > 개인 정보 보호 및 보안 > 손쉬운 사용**에서 MonitorArrange를 허용해야 합니다. 마우스 이벤트(엣지 감지·커서 근접 표시)를 감지하기 위해 필요합니다.

## 사용법

1. 외장 모니터를 물리적으로 이동합니다
2. 맥북 화면 가장자리로 마우스를 밀어냅니다
3. 설정한 시간만큼 밀면 모니터 배치가 자동 변경됩니다

메뉴바의 🖥️ 아이콘을 클릭하면 현재 배치 확인 및 수동 전환이 가능합니다.

## 프로젝트 구조

```
MonitorArrange/
├── App/
│   ├── MonitorArrangeApp.swift   # 앱 진입점 (MenuBarExtra)
│   └── AppState.swift            # 앱 상태 관리 및 이벤트 연결
├── Core/
│   ├── DisplayManager.swift          # CoreGraphics 디스플레이 재배치
│   ├── DisplayPosition.swift         # 위치 열거형 (상/하/좌/우)
│   ├── EdgeDetector.swift            # CGEventTap 기반 엣지 감지
│   └── EdgeIndicatorController.swift # 가장자리 글로우 오버레이(맥북·외장)
├── Views/
│   ├── MenuBarView.swift         # 메뉴바 드롭다운 UI
│   └── SettingsView.swift        # 설정 창
└── Resources/
    ├── Assets.xcassets/          # 앱 아이콘
    ├── Info.plist
    └── MonitorArrange.entitlements
```

## License

MIT
