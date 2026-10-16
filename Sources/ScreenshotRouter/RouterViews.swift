import SwiftUI

struct RouterView: View {
    @ObservedObject var model: RouterModel

    var body: some View {
        Group {
            if model.activeTab == .setup {
                SetupView(model: model)
            } else {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Label("ScreenshotRouter", systemImage: "camera.viewfinder")
                            .font(.headline)
                        Spacer()
                        RouterNavigation(model: model)
                    }
                    .padding(.horizontal, 24)

                    Group {
                        switch model.activeTab {
                        case .save:
                            SaveView(model: model)
                        case .settings:
                            SettingsView(model: model)
                        case .setup:
                            EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.vertical, 20)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.94))
        .frame(minWidth: 760, minHeight: 540)
    }
}

private struct SetupView: View {
    @ObservedObject var model: RouterModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Label("ScreenshotRouter", systemImage: "camera.viewfinder")
                    .font(.headline)
                Text(model.text("시작하기", "Get started"))
                    .font(.largeTitle.weight(.semibold))
                Text(model.text("저장할 폴더를 고르고, 영역 캡처에 필요한 권한을 확인하세요.", "Choose where screenshots go and review the permissions used for area capture."))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Label(model.text("저장 폴더", "Destination folders"), systemImage: "folder")
                    .font(.headline)
                Text(model.destinations.isEmpty
                    ? model.text("스크린샷을 저장할 폴더를 하나 이상 선택하세요.", "Choose one or more folders for saved screenshots.")
                    : model.text("\(model.destinations.count)개의 저장 폴더를 선택했습니다.", "\(model.destinations.count) destination folders selected."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !model.destinations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(model.destinations.enumerated()), id: \.element.id) { index, destination in
                            HStack(spacing: 10) {
                                Image(systemName: destination.writable ? "folder.fill" : "folder.badge.questionmark")
                                    .foregroundStyle(destination.writable ? Color.accentColor : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(destination.name).font(.subheadline.weight(.medium))
                                    Text((destination.path as NSString).abbreviatingWithTildeInPath)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                Text("⌘\(index + 1)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .background(Color.primary.opacity(0.07), in: Capsule())
                            }
                            .padding(10)
                            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
                Button {
                    model.addFolder()
                } label: {
                    Label(model.text("폴더 선택", "Choose folders"), systemImage: "folder.badge.plus")
                }
            }
            .padding(20)
            .routerGlass(cornerRadius: 20)

            VStack(alignment: .leading, spacing: 12) {
                Label(model.text("권한", "Permissions"), systemImage: "lock.shield")
                    .font(.headline)
                PermissionRow(
                    title: model.text("화면 녹화", "Screen Recording"),
                    detail: model.text("영역을 직접 캡처할 때 필요합니다.", "Used when capturing an area directly."),
                    granted: model.screenRecordingPermissionGranted,
                    grantedLabel: model.text("허용됨", "Allowed"),
                    deniedLabel: model.text("허용되지 않음", "Not allowed"),
                    requestLabel: model.text("권한 요청", "Request permission"),
                    request: model.requestScreenRecordingPermission
                )
                PermissionRow(
                    title: model.text("손쉬운 사용", "Accessibility"),
                    detail: model.text("Command+Shift+4 단축키를 감지할 때 필요합니다.", "Used to detect the Command+Shift+4 shortcut."),
                    granted: model.accessibilityPermissionGranted,
                    grantedLabel: model.text("허용됨", "Allowed"),
                    deniedLabel: model.text("허용되지 않음", "Not allowed"),
                    requestLabel: model.text("권한 요청", "Request permission"),
                    request: model.requestAccessibilityPermission
                )
                Button(model.text("권한 상태 다시 확인", "Check permission status")) {
                    model.refreshPermissionStatus()
                }
                .buttonStyle(.link)
            }
            .padding(20)
            .routerGlass(cornerRadius: 20)

            HStack {
                Text(model.text("권한은 나중에 macOS 시스템 설정에서 바꿀 수 있습니다.", "You can change permissions later in macOS System Settings."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(model.text("계속", "Continue")) {
                    model.completeSetup()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.destinations.contains(where: \.writable))
            }
            }
            .padding(.horizontal, 24)
            .padding(.top, 52)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let grantedLabel: String
    let deniedLabel: String
    let requestLabel: String
    let request: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
                Text(granted ? grantedLabel : deniedLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(granted ? grantedLabel : requestLabel, action: request)
                .disabled(granted)
        }
        .padding(10)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct RouterNavigation: View {
    @ObservedObject var model: RouterModel

    var body: some View {
        HStack(spacing: 4) {
            tab(model.text("저장", "Save"), systemImage: "tray.and.arrow.down", value: .save)
            tab(model.text("설정", "Settings"), systemImage: "gearshape", value: .settings)
        }
        .padding(4)
        .routerGlass(cornerRadius: 18)
        .accessibilityElement(children: .contain)
    }

    private func tab(_ title: String, systemImage: String, value: RouterTab) -> some View {
        Button {
            model.activeTab = value
        } label: {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(model.activeTab == value ? Color.primary.opacity(0.1) : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(model.activeTab == value ? .isSelected : [])
    }
}

private struct SaveView: View {
    @ObservedObject var model: RouterModel

    var body: some View {
        Group {
            if let capture = model.pending.first, let image = NSImage(contentsOf: capture.url) {
                HStack(spacing: 16) {
                    PreviewWell(image: image, filename: capture.filename, model: model)
                    DestinationRail(model: model)
                        .frame(width: 264)
                }
            } else {
                EmptyRouter(model: model)
            }
        }
        .padding(.horizontal, 24)
    }
}

private struct PreviewWell: View {
    let image: NSImage
    let filename: String
    @ObservedObject var model: RouterModel

    var body: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor)
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.12))
        }
        .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.text("스크린샷 미리보기: \(filename)", "Screenshot preview: \(filename)"))
    }
}

private struct DestinationRail: View {
    @ObservedObject var model: RouterModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.text("스크린샷 저장", "Save screenshot"))
                .font(.title2.weight(.semibold))

            if model.destinations.isEmpty {
                ContentUnavailableView {
                    Label(model.text("저장 폴더 없음", "No destinations"), systemImage: "folder.badge.plus")
                } description: {
                    Text(model.text("먼저 저장할 폴더를 추가하세요.", "Add a folder before saving."))
                } actions: {
                    Button(model.text("폴더 추가", "Add Folder")) { model.showSettings() }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(model.destinations.enumerated()), id: \.element.id) { index, destination in
                            DestinationRow(destination: destination, shortcut: index + 1, model: model)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            if let error = model.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(model.text("⌘1–9로 바로 저장 · Esc로 닫기", "⌘1–9 to save · Esc to close"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .routerGlass(cornerRadius: 20)
    }
}

private struct DestinationRow: View {
    let destination: Destination
    let shortcut: Int
    @ObservedObject var model: RouterModel

    var body: some View {
        Button {
            model.save(to: destination)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: destination.writable ? "folder.fill" : "folder.badge.questionmark")
                    .foregroundStyle(destination.writable ? Color.accentColor : .secondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(destination.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text((destination.path as NSString).abbreviatingWithTildeInPath)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 4)
                Text("⌘\(shortcut)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.07), in: Capsule())
            }
            .padding(10)
            .background(model.selection == destination.id ? Color.primary.opacity(0.09) : Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!destination.writable)
        .opacity(destination.writable ? 1 : 0.55)
        .help(destination.path)
        .accessibilityLabel(model.text("\(destination.name)에 저장, 단축키 Command \(shortcut)", "Save to \(destination.name), shortcut Command \(shortcut)"))
    }
}

private struct EmptyRouter: View {
    @ObservedObject var model: RouterModel

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                Text(model.text("대기 중인 스크린샷 없음", "No pending screenshot"))
                    .font(.title2.weight(.semibold))
                Text(model.text("Command+Shift+4를 눌러 영역을 캡처하세요.", "Press Command+Shift+4 to capture an area."))
                    .foregroundStyle(.secondary)
            }
            Button(model.text("영역 캡처", "Capture Area")) { model.captureArea() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .routerGlass(cornerRadius: 20)
    }
}

private struct SettingsView: View {
    @ObservedObject var model: RouterModel
    @State private var selected: UUID?

    private var index: Int? { model.destinations.firstIndex { $0.id == selected } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(model.text("설정", "Settings"))
                    .font(.title2.weight(.semibold))
                Text(model.text("언어와 저장 폴더 순서를 관리합니다.", "Manage language and destination order."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label(model.text("언어", "Language"), systemImage: "globe")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Picker(model.text("언어", "Language"), selection: Binding(get: { model.language }, set: { model.setLanguage($0) })) {
                    Text("한국어").tag(AppLanguage.korean)
                    Text("English").tag(AppLanguage.english)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 190)
            }

            Divider()

            HStack {
                Label(model.text("저장 폴더", "Destination folders"), systemImage: "folder")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Button {
                    model.addFolder()
                } label: {
                    Label(model.text("추가", "Add"), systemImage: "plus")
                }
            }

            List(selection: $selected) {
                ForEach(model.destinations) { destination in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(destination.name)
                        Text((destination.path as NSString).abbreviatingWithTildeInPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .tag(destination.id)
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(height: 112)
            .scrollContentBackground(.hidden)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                if model.destinations.isEmpty {
                    ContentUnavailableView(model.text("저장 폴더 없음", "No destinations"), systemImage: "folder.badge.plus", description: Text(model.text("스크린샷을 저장할 폴더를 추가하세요.", "Add a folder for saved screenshots.")))
                }
            }
            .accessibilityLabel(model.text("저장 폴더 순서", "Ordered destination folders"))

            HStack {
                Button(role: .destructive) {
                    if let selected {
                        model.remove(selected)
                        self.selected = nil
                    }
                } label: {
                    Label(model.text("삭제", "Remove"), systemImage: "trash")
                }
                .disabled(selected == nil)
                Spacer()
                Button { if let selected { model.move(selected, by: -1) } } label: { Label(model.text("위로", "Move Up"), systemImage: "arrow.up") }
                    .disabled(index == nil || index == 0)
                Button { if let selected { model.move(selected, by: 1) } } label: { Label(model.text("아래로", "Move Down"), systemImage: "arrow.down") }
                    .disabled(index == nil || index == model.destinations.count - 1)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Label(model.text("권한", "Permissions"), systemImage: "lock.shield")
                    .font(.subheadline.weight(.medium))
                PermissionRow(
                    title: model.text("화면 녹화", "Screen Recording"),
                    detail: model.text("영역 캡처", "Area capture"),
                    granted: model.screenRecordingPermissionGranted,
                    grantedLabel: model.text("허용됨", "Allowed"),
                    deniedLabel: model.text("허용되지 않음", "Not allowed"),
                    requestLabel: model.text("권한 요청", "Request permission"),
                    request: model.requestScreenRecordingPermission
                )
                PermissionRow(
                    title: model.text("손쉬운 사용", "Accessibility"),
                    detail: model.text("캡처 단축키", "Capture shortcut"),
                    granted: model.accessibilityPermissionGranted,
                    grantedLabel: model.text("허용됨", "Allowed"),
                    deniedLabel: model.text("허용되지 않음", "Not allowed"),
                    requestLabel: model.text("권한 요청", "Request permission"),
                    request: model.requestAccessibilityPermission
                )
                Button(model.text("권한 상태 다시 확인", "Check permission status")) {
                    model.refreshPermissionStatus()
                }
                .buttonStyle(.link)
            }

            if let error = model.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            }
            .padding(24)
        }
        .routerGlass(cornerRadius: 20)
        .padding(.horizontal, 24)
    }
}

private extension View {
    func routerGlass(cornerRadius: CGFloat) -> some View {
        modifier(RouterGlass(cornerRadius: cornerRadius))
    }
}

private struct RouterGlass: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12))
                }
        } else {
            #if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                content
                    .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            } else {
                content
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(.white.opacity(0.16))
                    }
                    .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
            }
            #else
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.16))
                }
                .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
            #endif
        }
    }
}
