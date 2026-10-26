# ScreenshotRouter

ScreenshotRouter는 macOS에서 영역을 캡처한 뒤 미리 지정한 폴더로 빠르게 저장할 수 있는 메뉴 막대 앱입니다. 캡처한 이미지는 클립보드에도 함께 복사됩니다.

[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%2B-black?logo=apple&logoColor=white)](https://support.apple.com/HT211814)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![CI](https://github.com/info-sum/comfyScreen/actions/workflows/ci.yml/badge.svg)](https://github.com/info-sum/comfyScreen/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[설치](#설치) · [사용 방법](#사용-방법) · [삭제](#삭제) · [라이선스](#라이선스)

## 지원 환경

- Apple Silicon(M1 이상) Mac
- macOS 14 이상

## 설치

### Git으로 설치

Git이 설치되어 있다면 저장소를 복제한 뒤 설치 프로그램을 실행합니다.

```sh
git clone https://github.com/info-sum/comfyScreen.git
cd comfyScreen
./Install\ ScreenshotRouter.command
```

### 원클릭 설치

Git을 설치하지 않으려면 아래 명령을 터미널에 붙여넣으세요. 최신 `main` 브랜치를 내려받아 설치합니다.

```sh
curl -fsSL https://raw.githubusercontent.com/info-sum/comfyScreen/main/scripts/install.sh | sh
```

설치가 끝나면 ScreenshotRouter가 자동으로 실행됩니다.

앱은 `~/Applications/ScreenshotRouter.app`에 설치됩니다.

### macOS가 실행을 차단하는 경우

1. 설치 프로그램 또는 앱을 한 번 실행합니다.
2. **시스템 설정 > 개인정보 보호 및 보안**으로 이동합니다.
3. 화면 아래쪽의 **확인 없이 열기**를 누른 뒤 다시 실행합니다.

## 처음 설정

1. 처음 나타나는 설정 화면에서 스크린샷을 저장할 폴더를 하나 이상 선택합니다.
2. **화면 기록**과 **손쉬운 사용** 항목에서 **권한 요청**을 누르고 macOS의 안내에 따라 허용합니다.
   - 화면 기록 권한은 앱에서 영역 캡처를 시작할 때 사용합니다.
   - 손쉬운 사용 권한은 `Command + Shift + 4` 단축키를 감지할 때 사용합니다.
3. 권한을 변경한 뒤 앱에 상태가 반영되지 않으면 ScreenshotRouter를 완전히 종료한 다음 다시 실행합니다.
4. 쓰기 가능한 저장 폴더가 하나 이상 등록되면 **계속**을 눌러 설정을 마칩니다.

권한을 나중에 허용해도 저장 폴더 설정은 사용할 수 있습니다. 권한 상태는 ScreenshotRouter의 **설정** 화면에서 다시 확인할 수 있습니다.

## 사용 방법

1. 다음 방법 중 하나로 영역 캡처를 시작합니다.
   - 메뉴 막대의 카메라 아이콘을 누르고 **영역 캡처…**를 선택합니다.
   - `Command + Shift + 4`를 누릅니다. 이 방법은 손쉬운 사용 권한이 필요합니다.
2. 캡처할 영역을 드래그합니다.
3. ScreenshotRouter 창이 나타나면 필요할 때 파일 이름을 바꾸고, 원하는 저장 폴더를 클릭합니다.

파일 이름 칸에는 `스크린샷_날짜_시간`이 들어 있습니다. 이름을 바꾸려면 칸을 클릭해 수정하세요. 확장자(`.png`)는 자동으로 붙습니다. 이름을 비우면 기본 이름으로 저장되고, `/`와 `:`는 `-`로 바뀝니다.

저장 폴더는 다음 방법으로도 선택할 수 있습니다.

- `Command + 1`부터 `Command + 9`: 해당 순서의 폴더에 즉시 저장
- 위쪽/아래쪽 방향키: 저장 폴더 선택 변경
- `Return` 또는 `Command + S`: 현재 선택한 폴더에 저장
- `Escape`: 저장하지 않고 창 숨기기

파일은 같은 이름의 파일을 덮어쓰지 않으며, 이름이 겹치면 번호를 붙여 저장합니다.

### 클립보드

캡처 이미지는 캡처 직후 PNG 이미지로 클립보드에 복사됩니다. 파일 경로는 함께 복사하지 않으므로 `Command + V`로 붙여넣으면 이미지만 들어갑니다.

ScreenshotRouter 창에서 `Command + C`를 누르면 캡처 이미지를 다시 복사합니다. 파일 이름을 수정하는 중에는 일반 텍스트 복사로 동작합니다.

대부분의 터미널은 이미지를 붙여넣지 못해서 `Command + V`로는 아무것도 입력되지 않습니다. 터미널에서 실행하는 AI 도구에 이미지를 첨부하려면 도구의 이미지 붙여넣기 단축키를 사용하세요. Codex CLI와 Claude Code에서는 `Control + V`입니다.

## 설정 변경

메뉴 막대의 카메라 아이콘을 누르고 **설정…**을 선택하면 다음 항목을 변경할 수 있습니다.

- 한국어 또는 영어 선택
- 저장 폴더 추가 및 삭제
- 저장 폴더 순서 변경
- 화면 기록 및 손쉬운 사용 권한 상태 확인

저장 폴더 순서가 `Command + 1`부터 `Command + 9`까지의 단축키 순서가 됩니다. 등록한 폴더가 이동되거나 삭제되면 기존 항목을 제거하고 다시 추가하세요.

## 삭제

1. 메뉴 막대의 카메라 아이콘을 누르고 **종료**를 선택합니다.
2. 저장소를 복제한 폴더에서 `Uninstall ScreenshotRouter.command`를 실행합니다.
3. 계속할지 묻는 메시지가 나타나면 `y`를 입력하고 `Return`을 누릅니다.

삭제 스크립트는 다음 항목을 제거합니다.

- `~/Applications/ScreenshotRouter.app`
- ScreenshotRouter 설정 및 캐시
- 화면 기록 및 손쉬운 사용 권한 등록

ScreenshotRouter를 사용해 저장 폴더로 옮긴 스크린샷은 삭제되지 않습니다.

## 개발자용 빌드 및 테스트

CommandLineTools가 설치된 macOS에서 다음 명령으로 빌드하고 실행할 수 있습니다.

```sh
swift build -c release
.build/release/ScreenshotRouter
```

Swift 6.3.2 CommandLineTools 환경에서는 번들된 Testing 프레임워크 경로를 지정해 전체 테스트를 실행합니다.

```sh
swift test --enable-swift-testing \
  -Xswiftc -F \
  -Xswiftc /Library/Developer/CommandLineTools/Library/Developer/Frameworks
```

### 격리된 QA 환경

실제 스크린샷 폴더와 저장 설정을 건드리지 않고 테스트하려면 다음 환경변수를 사용합니다.

- `SCREENSHOT_ROUTER_WATCH_DIR`: 감시할 테스트 폴더
- `SCREENSHOT_ROUTER_DESTINATIONS`: 콜론(`:`)으로 구분한 저장 폴더 목록

저장 폴더 환경변수는 현재 실행 중인 앱의 메모리에서만 사용되며 기존 설정을 덮어쓰지 않습니다. QA 중에는 여러 앱 인스턴스를 동시에 실행하지 마세요.

## 문제를 제보할 때

다음 정보를 함께 전달해 주세요.

- 사용 중인 Mac 모델과 macOS 버전
- 문제가 발생하기 직전에 한 동작
- 화면에 표시된 메시지 또는 스크린샷
- 사용한 저장 폴더와 단축키

현재 배포본은 개발자 서명이 없는 테스트용 앱이므로 처음 실행할 때 macOS 보안 경고가 나타날 수 있습니다.

## 라이선스

이 프로젝트는 [MIT License](LICENSE)에 따라 배포됩니다.
