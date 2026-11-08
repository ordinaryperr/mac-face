# Mac Face

Apple로 로그인한 뒤 Mugshot에 등록한 얼굴로 앱 안의 보호 화면을 여는 Mac 앱입니다.

Apple Silicon, macOS 14 이상 및 Xcode의 Swift 컴파일러가 필요합니다. `./Scripts/build.sh`는 기본적으로 `build/apple-login-preview/Mac Face.app`에 로그인 화면 확인용 빌드를 만듭니다. Apple 개발자 서명 없이 실행한 미리보기에서는 로그인 버튼이 비활성화됩니다.

실제 Apple 로그인을 사용하려면 다음 순서로 설정합니다.

1. Apple Developer 계정에서 이 앱의 명시적 App ID를 등록하고 **Sign in with Apple**을 활성화합니다. 이 Mac과 사용할 **Apple Development** 인증서를 포함한 **macOS App Development** 프로비저닝 프로파일을 내려받습니다. 인증서와 개인 키는 이 Mac의 키체인에 있어야 합니다. [Apple 개발자 설정 안내](https://developer.apple.com/help/account/capabilities/about-sign-in-with-apple)
2. `security find-identity -v -p codesigning`에서 해당 Apple Development 인증서의 해시를 확인합니다. 아래 명령의 프로파일 경로와 해시를 교체해 빌드합니다. 번들 ID는 프로파일의 App ID에서 가져옵니다.

   ```sh
   MACFACE_PROVISIONING_PROFILE='/path/to/MacFace.provisionprofile' \
   MACFACE_SIGN_IDENTITY='APPLE_DEVELOPMENT_CERTIFICATE_HASH' \
   ./Scripts/build.sh
   ```

3. [Mugshot 1.3.0](https://github.com/Lorenzo-Coslado/macos-faceid/releases/tag/v1.3.0)을 실행하고 얼굴을 등록합니다. `open 'build/apple-login/Mac Face.app'`으로 서명된 Mac Face를 실행합니다. **Apple로 로그인**을 마치고 **얼굴 인증**을 누르면, 얼굴이 일치할 때 보호 화면이 열립니다.

Mac Face는 시스템 로그인에서 받은 사용자 식별자만 이 Mac의 키체인에 저장합니다. 재실행하면 Apple의 자격 상태를 확인하고 얼굴 인증을 다시 요구합니다. **다시 잠그기**를 누르거나, 창을 닫거나, Mac을 잠그면 화면이 다시 잠깁니다. **로그아웃**하면 키체인의 식별자를 지웁니다.

앱은 서명을 확인한 Mugshot 엔진에 로컬 얼굴 검사를 요청합니다. Mugshot 버전이 바뀌면 내부 프로토콜 호환 여부를 확인해야 합니다.

일반 웹캠은 사진이나 영상에 속을 수 있습니다. 이 예제는 기기 안의 화면을 열어 보는 용도입니다. 민감한 정보나 서버 로그인에는 운영체제 인증(Touch ID 또는 passkey 등)을 사용하세요.

카메라를 켜지 않고 Mugshot 연결을 확인하려면:

```sh
xcrun swiftc -parse-as-library Sources/MugshotClient.swift Tests/ConnectionProbe.swift -o build/connection-probe
build/connection-probe
```
