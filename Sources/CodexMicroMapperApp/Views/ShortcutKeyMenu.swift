import Carbon
import CodexMicroCore
import SwiftUI

/// Manual choices are organized by keyboard role, without preferred keys.
struct ShortcutKeyMenu: View {
    let language: AppLanguage
    let canClear: Bool
    let onSelect: (KeyStrokeDefinition) -> Void
    let onClear: () -> Void

    var body: some View {
        Menu(language.text("输入与编辑", "Input and Editing")) {
            keys([kVK_Return, kVK_Tab, kVK_Space])
            Divider()
            keys([kVK_Delete, kVK_ForwardDelete])
            Divider()
            keys([kVK_Escape])
        }
        Menu(language.text("方向与导航", "Arrows and Navigation")) {
            keys([kVK_UpArrow, kVK_DownArrow, kVK_LeftArrow, kVK_RightArrow])
            Divider()
            keys([kVK_Home, kVK_End])
            keys([kVK_PageUp, kVK_PageDown])
        }
        Menu(language.text("字母、数字与符号", "Letters, Numbers, and Symbols")) {
            Menu(language.text("字母 A–Z", "Letters A–Z")) {
                keys([
                    kVK_ANSI_A, kVK_ANSI_B, kVK_ANSI_C, kVK_ANSI_D, kVK_ANSI_E,
                    kVK_ANSI_F, kVK_ANSI_G, kVK_ANSI_H, kVK_ANSI_I, kVK_ANSI_J,
                    kVK_ANSI_K, kVK_ANSI_L, kVK_ANSI_M, kVK_ANSI_N, kVK_ANSI_O,
                    kVK_ANSI_P, kVK_ANSI_Q, kVK_ANSI_R, kVK_ANSI_S, kVK_ANSI_T,
                    kVK_ANSI_U, kVK_ANSI_V, kVK_ANSI_W, kVK_ANSI_X, kVK_ANSI_Y,
                    kVK_ANSI_Z,
                ])
            }
            Menu(language.text("数字 0–9", "Numbers 0–9")) {
                keys([kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4,
                      kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9])
            }
            Menu(language.text("符号", "Symbols")) {
                keys([kVK_ANSI_Grave, kVK_ANSI_Minus, kVK_ANSI_Equal])
                Divider()
                keys([kVK_ANSI_LeftBracket, kVK_ANSI_RightBracket, kVK_ANSI_Backslash,
                      kVK_ANSI_Semicolon, kVK_ANSI_Quote])
                Divider()
                keys([kVK_ANSI_Comma, kVK_ANSI_Period, kVK_ANSI_Slash])
            }
        }
        Menu(language.text("修饰键", "Modifiers")) {
            modifiers([.leftShift, .rightShift])
            Divider()
            modifiers([.leftControl, .rightControl])
            Divider()
            modifiers([.leftOption, .rightOption])
            Divider()
            modifiers([.leftCommand, .rightCommand])
            Divider()
            modifiers([.function])
        }
        Menu(language.text("功能键", "Function Keys")) {
            keys([kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6,
                  kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12])
            Divider()
            keys([kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20])
        }
        Divider()
        Button(language.text("清除快捷键", "Clear Shortcut"), action: onClear)
            .disabled(!canClear)
    }

    private func keys(_ codes: [Int]) -> some View {
        ForEach(codes, id: \.self) { code in
            Button(keyTitle(code)) { onSelect(.init(keyCode: UInt16(code))) }
        }
    }

    private func modifiers(_ keys: [ModifierKey]) -> some View {
        ForEach(keys, id: \.self) { key in
            Button(ViewFormatting.modifierName(key, language: language)) {
                onSelect(.init(keyCode: key.rawValue))
            }
        }
    }

    private func keyTitle(_ code: Int) -> String {
        switch code {
        case kVK_Return: language.text("回车 ↩", "Return ↩")
        case kVK_Tab: language.text("制表 ⇥", "Tab ⇥")
        case kVK_Space: language.text("空格", "Space")
        case kVK_Delete: language.text("删除 ⌫", "Delete ⌫")
        case kVK_ForwardDelete: language.text("向前删除 ⌦", "Forward Delete ⌦")
        case kVK_Escape: "Escape ⎋"
        case kVK_UpArrow: language.text("上 ↑", "Up ↑")
        case kVK_DownArrow: language.text("下 ↓", "Down ↓")
        case kVK_LeftArrow: language.text("左 ←", "Left ←")
        case kVK_RightArrow: language.text("右 →", "Right →")
        default: ViewFormatting.keyName(for: UInt16(code))
        }
    }
}
