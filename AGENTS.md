# AGENTS.md

## Repository defaults
- 언어: Swift, SwiftUI + AppKit
- 타겟: macOS 26+
- 데이터 저장: `UserDefaults` + 앱 지원 폴더 JSON (`layout.json`)
- 보안 우선: 경로 검증, 시스템 보호 경로(`/System`, `/Library`) 삭제 금지

## Working rules
- 기능 참조는 `_reference/`만 참고하고 코드 직접 복사 금지
- 비밀정보(API 키, 토큰, 인증서) 저장소 커밋 금지
- 비파괴 원칙: 사용자 데이터/시스템 파일 삭제 동작은 항상 확인 절차 유지

## Verification
- 변경 후 `xcodegen generate`
- 변경 후 `xcodebuild -scheme LaunchMenu -configuration Debug build`
- 변경 후 `xcodebuild -scheme LaunchMenu -configuration Debug test`
- 문자열 파일은 `plutil -lint LaunchMenu/Localization/*/Localizable.strings`
