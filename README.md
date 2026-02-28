# Launch Menu

macOS 26 Tahoe용 런치패드 대체 앱 프로토타입입니다.

## 현재 구현
- 메뉴바 상주 + 전체화면 오버레이
- Command+L 단축키 토글
- 앱 스캔 및 아이콘 캐시
- 검색(한글 초성 + 퍼지)
- 스마트 탭(전체/최근/자주/새로설치)
- 페이지/스크롤 모드
- 지글 모드 + 드래그 정렬 + 폴더 생성/열기
- 런치패드 DB 가져오기
- Dock 추가, 핫 코너
- 다국어(15개 locale 스캐폴드, 실번역은 한국어/영어 우선)
- 백업/복원, 앱 삭제(서드파티만)
- 설정 저장(UserDefaults)

## 빌드
```bash
cd LaunchMenu
xcodegen generate
xcodebuild -project LaunchMenu.xcodeproj -scheme LaunchMenu -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO
```

## 핵심 파일 경로
- 앱 메인 상태: `LaunchMenu/App/LaunchMenuStore.swift`
- 루트 UI: `LaunchMenu/Views/Overlay/RootContentView.swift`
- 폴더 아이콘 뷰: `LaunchMenu/Views/Folder/FolderIconView.swift`
- 다국어 헬퍼: `LaunchMenu/Localization/L10n.swift`

## 실행 검증(최근)
- Build/Test: 성공 (`xcodebuild ... build/test`)
- 메모리 샘플(RSS): 5초 `96.91MB`, 10초 `79.39MB`

## 참고
- 구현 비교: `REFERENCE_COMPARISON.md`
- 보안 점검: `SECURITY_REVIEW.md`
- 참고 레포(읽기 전용): `_reference/LaunchNext`
