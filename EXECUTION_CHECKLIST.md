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
- Step 8 완료: 자동 분류/백업/앱삭제/다국어(15개 Localizable.strings + 문자열 치환) 적용
- 보안 보완 완료: Dock 명령 실행 인자 분리, 백업 파일 크기 제한, 삭제 대상 범위 강화
- 최종 검증 완료: xcodegen generate, xcodebuild build/test 모두 성공
- Step 9 진행 현황: 보안검사 + git push는 완료 예정, 코드사이닝/공증/DMG는 Apple Developer 계정/배포 자격 정보가 필요
