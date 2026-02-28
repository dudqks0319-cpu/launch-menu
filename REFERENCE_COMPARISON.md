# Launch Menu vs LaunchNext (Reference)

## 분석 기준
- 참고 코드: `_reference/LaunchNext`
- 원칙: GPL 코드 비복제, 기능/구조만 참고

## 현재 Launch Menu 구현 상태

### 완료된 핵심 기능
- 전체화면 오버레이 패널 + 블러 + ESC 닫기
- 메뉴바 토글 + 글로벌 핫키(Command+L)
- 앱 스캔(`/Applications`, `/System/Applications`, `~/Applications`)
- 앱 아이콘 캐시(NSCache)
- 검색(한글 초성 + 퍼지 매칭)
- 스마트 탭(전체/최근/자주/새로설치)
- 앱 실행 + 최근/자주 실행 이력 저장
- 페이지/스크롤 모드 전환
- 설정(UserDefaults 기반)

### 미완료/고도화 필요
- 드래그 재정렬 및 폴더 자동 생성
- Dock 드래그 고정
- 런치패드 DB 1:1 가져오기
- 핫코너/트랙패드 제스처
- 위젯(WidgetKit 실제 extension)
- 앱 완전 삭제/백업-복원 UX
- 다국어 15개+ 리소스

## LaunchNext 대비 경쟁력 평가

### 우위 가능 지점
- 보안 기본선 강화(실행 경로 검증, 경로 노출 최소화)
- 한글 초성 검색 내장
- 간결한 아키텍처(서비스/스토어 분리)
- 내부 타깃/브랜딩 일관성(`LaunchMenu`)

### 현재 열위 지점
- 성숙한 드래그/폴더/페이지 캐스케이드 UX는 LaunchNext가 앞섬
- 설정/백업/업데이트/성능 모드의 깊이는 LaunchNext가 앞섬

## 경쟁력 확보를 위한 다음 우선순위
1. 드래그 재배치 + 폴더 생성(사용자 체감 1순위)
2. Launchpad DB Import(전환 장벽 제거)
3. Dock 드래그 고정(차별화 핵심)
4. 위젯 + 핫코너(프로 기능 고도화)
5. 백업/복원 및 다국어(상용 배포 준비)
