import AppKit
import SwiftUI

@main
struct CodexMicroMapperApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Codex Micro Mapper", id: "main") {
            SettingsRootView(model: model)
                .frame(
                    minWidth: 740,
                    idealWidth: 980,
                    maxWidth: .infinity,
                    minHeight: 560,
                    idealHeight: 720,
                    maxHeight: .infinity
                )
        }
        .defaultSize(width: 980, height: 720)
        .windowResizability(.automatic)
        .commands {
            OpenMainWindowCommands(language: model.language)
        }

        MenuBarExtra {
            MenuBarMenu(model: model)
        } label: {
            Image(systemName: MapperSymbols.menuBar)
                .accessibilityLabel(model.menuStatusText)
        }
    }
}

private struct OpenMainWindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    let language: AppLanguage

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(language.text("打开设置", "Open Settings")) {
                openWindow(id: "main")
                AppLifecycleDelegate.presentMainWindow()
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}

private struct MenuBarMenu: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var model: AppModel

    var body: some View {
        Label(model.menuStatusText, systemImage: model.healthSymbolName)
            .disabled(true)

        Button {
            openWindow(id: "main")
            AppLifecycleDelegate.presentMainWindow()
        } label: {
            Label(model.language.text("打开设置", "Open Settings"), systemImage: "slider.horizontal.3")
        }
        .keyboardShortcut(",", modifiers: .command)

        Button {
            model.toggleEnabled()
        } label: {
            Label(
                model.isEnabled
                    ? model.language.text("暂停按键映射", "Pause Key Mappings")
                    : model.language.text("启用按键映射", "Enable Key Mappings"),
                systemImage: "power"
            )
        }

        Divider()

        Button(model.language.text("退出 Codex Micro Mapper", "Quit Codex Micro Mapper")) {
            model.shutdown()
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
