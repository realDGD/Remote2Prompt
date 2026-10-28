/// Optional preset. Filling it never enables mapping or replaces an existing gesture.
public enum CommonMappings {
    public static let bindings: [KeyBinding] = [
        KeyBinding(button: .power, gesture: .click, action: .escape),
        KeyBinding(button: .power, gesture: .longPress, action: .escape),
        KeyBinding(button: .up, gesture: .click, action: .arrowUp),
        KeyBinding(button: .up, gesture: .longPress, action: .customShortcut, shortcut: KeyboardShortcut(keyCode: 126, modifiers: [.command, .function])),
        KeyBinding(button: .left, gesture: .click, action: .arrowLeft),
        KeyBinding(button: .left, gesture: .longPress, action: .customShortcut, shortcut: KeyboardShortcut(keyCode: 123, modifiers: [.command, .function])),
        KeyBinding(button: .right, gesture: .click, action: .arrowRight),
        KeyBinding(button: .right, gesture: .longPress, action: .customShortcut, shortcut: KeyboardShortcut(keyCode: 124, modifiers: [.command, .function])),
        KeyBinding(button: .down, gesture: .click, action: .arrowDown),
        KeyBinding(button: .down, gesture: .longPress, action: .customShortcut, shortcut: KeyboardShortcut(keyCode: 125, modifiers: [.command, .function])),
        KeyBinding(button: .select, gesture: .click, action: .enter),
        KeyBinding(button: .select, gesture: .doubleClick, action: .customShortcut, shortcut: KeyboardShortcut(keyCode: 36, modifiers: .command)),
        KeyBinding(button: .select, gesture: .longPress, action: .customShortcut, shortcut: KeyboardShortcut(keyCode: 36, modifiers: .shift)),
        KeyBinding(button: .back, gesture: .click, action: .backspace),
        KeyBinding(button: .home, gesture: .click, action: .customShortcut, shortcut: KeyboardShortcut(keyCode: 6, modifiers: .command)),
        KeyBinding(button: .home, gesture: .longPress, action: .customShortcut, shortcut: KeyboardShortcut(keyCode: 6, modifiers: [.shift, .command])),
        KeyBinding(button: .menu, gesture: .click, action: .customShortcut, shortcut: KeyboardShortcut(keyCode: 43)),
        KeyBinding(button: .volumeUp, gesture: .click, action: .customShortcut, shortcut: KeyboardShortcut(keyCode: 24, modifiers: .shift)),
        KeyBinding(button: .volumeDown, gesture: .click, action: .customShortcut, shortcut: KeyboardShortcut(keyCode: 27)),
        KeyBinding(button: .tv, gesture: .click, action: .customShortcut, shortcut: KeyboardShortcut(keyCode: 47))
    ]
}
