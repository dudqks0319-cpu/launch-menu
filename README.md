# Launch Menu

macOS 26 Tahoe용 런치패드 대체 앱 프로토타입입니다.

## 현재 구현
- 메뉴바 상주 + 전체화면 오버레이
- Option+Space / F4 단축키 토글
- 앱 스캔 및 아이콘 캐시
- 검색(한글 초성 + 퍼지)
- 스마트 탭(전체/최근/자주/새로설치)
- 페이지/스크롤 모드
- 설정 저장(UserDefaults)

## 빌드
```bash
cd LaunchMenu
xcodegen generate
xcodebuild -project LaunchMenu.xcodeproj -scheme LaunchMenu -configuration Debug -sdk macosx build CODE_SIGNING_ALLOWED=NO
```

## 참고
- 구현 비교: `REFERENCE_COMPARISON.md`
- 보안 점검: `SECURITY_REVIEW.md`
- 참고 레포(읽기 전용): `_reference/LaunchNext`
