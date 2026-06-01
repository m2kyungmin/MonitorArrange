fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Mac

### mac dmg

```sh
[bundle exec] fastlane mac dmg
```

공유용 DMG (공증 X — 받는 사람은 우클릭→열기 필요). 지금 바로 사용 가능.

사용 예: DEVELOPMENT_TEAM=<팀ID> fastlane mac dmg

### mac release

```sh
[bundle exec] fastlane mac release
```

정식 배포: Developer ID 서명 + 공증 + staple + DMG (유료 Developer Program 필요)

필요 ENV:

  CODE_SIGN_IDENTITY='Developer ID Application: NAME (TEAMID)'

  DEVELOPMENT_TEAM=<팀ID>

  notarytool 자격증명 — APPLE_ID + FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD

  (또는 App Store Connect API key: ASC_KEY_PATH 지정)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
