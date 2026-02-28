# LaunchMenu Execution Checklist

## 진행 상태
- [x] 핫키 변경: Command+L
- [x] Step 1-1 지글 모드 + 편집 진입/종료
- [x] Step 1-2 드래그 앤 드롭 정렬
- [x] Step 1-3 배치 순서 영속 저장(layout.json)
- [x] Step 2 폴더 생성/폴더 아이콘/폴더 확장 뷰
- [x] Step 3 페이지 점 인디케이터 + 스와이프 전환
- [x] Step 4 기존 런치패드 DB 가져오기
- [x] Step 5 컨텍스트 메뉴 + Dock 추가
- [x] Step 6 핫 코너
- [x] Step 7 테마/아이콘 크기/UI 마무리
- [x] Step 8 자동 분류/백업/앱삭제/다국어
- [ ] Step 9 코드사이닝/공증/DMG/배포

## 메모
- Step 8 완료: 자동 분류/백업/앱삭제/다국어(15개 locale 스캐폴드 + en/ko 우선 번역) 적용
- 보안 보완 완료: Dock 명령 실행 인자 분리, 백업 파일 크기 제한, 삭제 대상 범위 강화
- 최종 검증 완료: xcodegen generate, xcodebuild build/test 모두 성공
- Step 9-1 진행: 파일 경로 정리(FolderIconView 분리, L10n 경로 확인), 실기동 메모리 샘플 측정(5초 96.91MB / 10초 79.39MB)
- Step 9 진행 현황: 보안검사 + git push 완료, 코드사이닝/공증/DMG는 Apple Developer 계정/배포 자격 정보가 필요

## 리뷰 반영 (2026-02-28)
- [x] FolderIconView 독립 파일 경로 정리
- [x] AGENTS.md 저장소 반영
- [x] 영어 오타 수정: `error.backup.file.too.large` -> `%dMB`
- [x] Dock 중복 추가 방지 로직 추가
- [x] 런치 열기 핫키 커스텀 추가 (`Command+L` / `Option+Space` / `F4`)
- [x] 설정 UI에 핫키 선택 메뉴 추가
- [x] 안내 문구를 선택 핫키 기반 동적 표시로 변경
- [x] 다국어 문구 상태 반영 (15개 locale 스캐폴드, en/ko 우선)
