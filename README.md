# Mac Face

Mugshot에 등록한 얼굴로 앱 안의 보호 화면을 여는 Mac 앱입니다. 얼굴 인증은 이 Mac에서 처리합니다.

1. [Mugshot 1.3.0](https://github.com/Lorenzo-Coslado/macos-faceid/releases/tag/v1.3.0)을 실행하고 얼굴을 등록합니다.
2. `./Scripts/build.sh`로 `build/Mac Face.app`을 빌드합니다. Apple Silicon, macOS 14 이상 및 Xcode의 Swift 컴파일러가 필요합니다.
3. Finder에서 `build/Mac Face.app`을 더블클릭해 엽니다. 응용 프로그램 폴더에 복사해 사용할 수도 있습니다.
4. **얼굴 인증**을 누르고 카메라를 봅니다. 얼굴이 일치하면 보호 화면이 열립니다. **다시 잠그기**를 누르거나, 창을 닫거나, Mac을 잠그면 화면이 다시 잠깁니다.

앱은 서명을 확인한 Mugshot 엔진에 로컬 얼굴 검사를 요청합니다. Mugshot 버전이 바뀌면 내부 프로토콜 호환 여부를 확인해야 합니다.

일반 웹캠은 사진이나 영상에 속을 수 있습니다. 이 앱은 기기 안의 화면을 열어 보는 용도입니다.

카메라를 켜지 않고 Mugshot 연결을 확인하려면:

```sh
xcrun swiftc -parse-as-library Sources/MugshotClient.swift Tests/ConnectionProbe.swift -o build/connection-probe
build/connection-probe
```
