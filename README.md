# Mac Face

Mugshot에 등록한 얼굴로 앱 안의 보호 화면을 여는 Mac 앱입니다. 얼굴 인증은 이 Mac에서 처리합니다.

Apple Silicon Mac과 macOS 14 이상이 필요합니다.

1. GitHub 릴리스에서 DMG를 내려받아 열고, **Mac Face**를 **응용 프로그램** 폴더로 드래그합니다.
2. Mac Face를 엽니다. **Mugshot 1.3.0 다운로드**가 보이면 공식 릴리스에서 `Mugshot.dmg`를 받아 설치합니다. Mac Face로 돌아오면 설치 여부를 다시 확인합니다.
3. **Mugshot 열기**를 눌러 카메라 접근을 허용하고 얼굴을 등록합니다. Mac Face의 얼굴 인증에는 Mugshot의 Mac 잠금 화면 해제나 `sudo` 설정이 필요하지 않습니다.
4. Mac Face에서 **얼굴 인증**을 누르고 카메라를 봅니다. 얼굴이 일치하면 보호 화면이 열립니다. **다시 잠그기**를 누르거나, 창을 닫거나, Mac을 잠그면 화면이 다시 잠깁니다.

기본 빌드의 DMG는 Apple 공증을 받지 않아 다운로드 후 첫 실행이 차단될 수 있습니다. [Apple의 앱 실행 안내](https://support.apple.com/ko-kr/102445)

앱은 서명을 확인한 Mugshot 엔진에 로컬 얼굴 검사를 요청합니다. Mugshot 버전이 바뀌면 내부 프로토콜 호환 여부를 확인해야 합니다.

일반 웹캠은 사진이나 영상에 속을 수 있습니다. 이 앱은 기기 안의 화면을 열어 보는 용도입니다.

소스에서 빌드하려면 Xcode의 Swift 컴파일러가 필요합니다. `./Scripts/build.sh`는 `build/Mac Face.app`을 만들고, `./Scripts/package-dmg.sh`는 DMG를 만들어 체크섬을 출력합니다.

공증된 배포 파일을 만들려면 이 Mac의 키체인에 **Developer ID Application** 인증서와 개인 키가 있어야 합니다. `security find-identity -v -p codesigning`에 나온 인증서 해시와 `xcrun notarytool store-credentials`로 만든 키체인 프로파일 이름을 지정합니다. 스크립트는 앱과 DMG에 서명하고, 공증 티켓과 Gatekeeper 검사를 통과한 파일을 `build/`에 `-notarized.dmg`로 저장합니다. [Apple의 공증 안내](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

```sh
MACFACE_DEVELOPER_ID='DEVELOPER_ID_APPLICATION_CERTIFICATE_HASH' \
MACFACE_NOTARY_PROFILE='NOTARY_KEYCHAIN_PROFILE_NAME' \
./Scripts/package-dmg.sh
```

카메라를 켜지 않고 Mugshot 연결을 확인하려면:

```sh
xcrun swiftc -parse-as-library Sources/MugshotClient.swift Tests/ConnectionProbe.swift -o build/connection-probe
build/connection-probe
```
