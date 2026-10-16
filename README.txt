ScreenshotRouter 테스트 사용법

[지원 환경]
- Apple Silicon(M1 이상) Mac
- macOS 14 이상

[설치]
1. 터미널에서 `git clone https://github.com/info-sum/comfyScreen.git`를 실행합니다.
2. `cd comfyScreen`으로 이동한 뒤 `./Install\ ScreenshotRouter.command`를 실행합니다.
3. 설치가 끝나면 ScreenshotRouter가 자동으로 실행됩니다.

Git을 설치하지 않으려면 아래 명령을 터미널에 붙여넣습니다.
`curl -fsSL https://raw.githubusercontent.com/info-sum/comfyScreen/main/scripts/install.sh | sh`

macOS가 실행을 차단하는 경우
1. 설치 파일 또는 앱을 한 번 실행합니다.
2. 시스템 설정 > 개인정보 보호 및 보안으로 이동합니다.
3. 아래쪽의 "확인 없이 열기"를 누르고 다시 실행합니다.

[처음 설정]
1. 스크린샷을 감지할 폴더와 저장할 폴더를 선택합니다.
2. 화면 기록과 손쉬운 사용 권한을 요청하면 모두 허용합니다.
3. 권한을 변경한 뒤에는 앱을 완전히 종료하고 다시 실행합니다.

[사용 방법]
1. 메뉴 막대의 ScreenshotRouter 아이콘에서 "영역 캡처"를 선택하거나,
   macOS 단축키 Command + Shift + 4로 화면을 캡처합니다.
2. ScreenshotRouter 창이 나타나면 원하는 저장 폴더를 선택합니다.
3. 폴더 오른쪽에 표시된 Command + 숫자 단축키로도 바로 저장할 수 있습니다.
4. 저장 파일은 "스크린샷_날짜_시간.png" 형식으로 만들어집니다.
5. 캡처 이미지는 클립보드에도 복사됩니다. 이미지 입력이 가능한 앱에는 PNG 이미지가,
   터미널 같은 텍스트 입력란에는 이미지 파일 경로가 붙여넣어집니다.

[메뉴 막대]
- 영역 캡처: 새 캡처 시작
- 설정: 감지 폴더, 저장 폴더와 권한 확인
- 종료: ScreenshotRouter 종료

[완전 삭제]
1. 메뉴 막대에서 ScreenshotRouter를 종료합니다.
2. "Uninstall ScreenshotRouter.command"를 더블 클릭합니다.
3. 안내가 나오면 y를 입력하고 Return 키를 누릅니다.

설치된 앱, 앱 설정, 화면 기록·손쉬운 사용 권한이 함께 삭제됩니다.
ScreenshotRouter로 저장한 스크린샷은 삭제되지 않습니다.

[문제가 생기면 알려주세요]
- 사용 중인 Mac 모델과 macOS 버전
- 문제가 발생하기 직전에 한 동작
- 화면에 나온 메시지 또는 스크린샷
- 저장하려던 폴더와 사용한 Command + 숫자

주의: 현재 버전은 지인 테스트용이므로 처음 실행할 때 macOS 보안 경고가 나타날 수 있습니다.
