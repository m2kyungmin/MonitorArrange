import SwiftUI

struct SettingsView: View {
    @ObservedObject var edgeDetector: EdgeDetector
    @ObservedObject var indicator: EdgeIndicatorController
    @AppStorage("showNotification") private var showNotification = true
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        Form {
            Section("감지 설정") {
                Toggle("자동 엣지 감지", isOn: $edgeDetector.isEnabled)

                HStack {
                    Text("감지 시간")
                    Slider(value: $edgeDetector.dwellThreshold, in: 0.1...2.0, step: 0.1)
                    Text("\(edgeDetector.dwellThreshold, specifier: "%.1f")초")
                        .monospacedDigit()
                        .frame(width: 40)
                }
                Text("화면 가장자리에서 마우스를 밀어야 하는 시간")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("가장자리 표시") {
                Toggle("위치 변경 시 깜빡임", isOn: $indicator.flashOnChange)
                Toggle("커서가 가까이 가면 표시", isOn: $indicator.cursorApproach)
                Toggle("항상 표시", isOn: $indicator.alwaysOn)
                Toggle("외장 모니터에도 표시", isOn: $indicator.mirrorOnExternal)

                ColorPicker("색상", selection: $indicator.glowColor, supportsOpacity: false)

                HStack {
                    Text("투명도")
                    Slider(
                        value: Binding(
                            get: { 1 - indicator.intensity },
                            set: { indicator.intensity = 1 - $0 }
                        ),
                        in: 0...0.9, step: 0.05
                    )
                    Text("\(Int((1 - indicator.intensity) * 100))%")
                        .monospacedDigit()
                        .frame(width: 44)
                }

                HStack {
                    Text("표시 테스트")
                    Spacer()
                    ForEach(DisplayPosition.allCases, id: \.self) { p in
                        Button {
                            indicator.preview(p)
                        } label: {
                            Image(systemName: p.icon)
                        }
                        .buttonStyle(.borderless)
                        .help("\(p.label) 가장자리 표시 미리보기")
                    }
                }

                Text("커서 근접 표시는 자동 엣지 감지(손쉬운 사용 권한)가 켜져 있어야 동작합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("일반") {
                Toggle("위치 변경 시 알림", isOn: $showNotification)
                Toggle("로그인 시 자동 실행", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
            }

            Section("상태") {
                HStack {
                    Text("손쉬운 사용 (Accessibility)")
                    Spacer()
                    if AXIsProcessTrusted() {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("허용됨")
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Button("권한 설정") {
                            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
                            AXIsProcessTrustedWithOptions(options)
                        }
                    }
                }
                HStack {
                    Text("엣지 감지")
                    Spacer()
                    if edgeDetector.isRunning {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("동작 중")
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("중지됨")
                        Button("재시도") {
                            edgeDetector.start()
                        }
                    }
                }
                Text("상태 코드: AX=\(AXIsProcessTrusted() ? "Y" : "N"), tap=\(edgeDetector.isRunning ? "Y" : "N"), enabled=\(edgeDetector.isEnabled ? "Y" : "N")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Section("사용법") {
                VStack(alignment: .leading, spacing: 6) {
                    Label("외장 모니터를 물리적으로 이동합니다", systemImage: "1.circle")
                    Label("맥북 화면 가장자리로 마우스를 밀어냅니다", systemImage: "2.circle")
                    Label("설정한 시간만큼 밀면 모니터 배치가 자동 변경됩니다", systemImage: "3.circle")
                }
                .font(.callout)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 580)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        if enabled {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }
}

import ServiceManagement
