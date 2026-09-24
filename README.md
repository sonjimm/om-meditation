# 옴 v2.2 — Android 빌드 준비판

핵심 변경
- `1_안드로이드_프로젝트_준비.bat`: Flutter Android scaffold 생성 → pub get → analyze → debug APK 빌드
- `2_릴리즈_APK_만들기.bat`: 정적 분석 통과 후 release APK 빌드
- 실기기 시험표 추가
- 네이티브 Foreground Service 템플릿을 무조건 덮어쓰지 않도록 안전하게 분리

권장 실행 순서
1. ZIP 압축 해제
2. `1_안드로이드_프로젝트_준비.bat`
3. 성공하면 debug APK를 휴대폰에 설치해 기본 명상 기능 시험
4. 오류가 있으면 명령창의 오류 내용을 그대로 제공
5. Foreground Service 병합/검증 후 `2_릴리즈_APK_만들기.bat`

현재 ChatGPT 작업 환경에는 Flutter SDK가 없어서 APK 자체를 여기서 컴파일했다고 주장하지 않습니다.
