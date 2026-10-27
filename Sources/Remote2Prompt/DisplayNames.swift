import Remote2PromptCore

extension RemoteButton {
    var title: String {
        switch self {
        case .up: "上"
        case .down: "下"
        case .left: "左"
        case .right: "右"
        case .select: "确认"
        case .back: "返回"
        case .home: "主页"
        case .menu: "菜单"
        case .tv: "TV"
        case .volumeUp: "音量 +"
        case .volumeDown: "音量 −"
        case .power: "电源"
        }
    }
}

extension ButtonGesture {
    var title: String {
        switch self {
        case .click: "单击"
        case .doubleClick: "双击"
        case .longPress: "长按"
        }
    }
}

extension MappedAction {
    var title: String {
        switch self {
        case .none: "不执行动作"
        case .arrowUp: "↑ 方向键"
        case .arrowDown: "↓ 方向键"
        case .arrowLeft: "← 方向键"
        case .arrowRight: "→ 方向键"
        case .enter: "↩ 回车"
        case .escape: "⎋ Escape"
        case .backspace: "⌫ 退格"
        case .copy: "⌘C 复制"
        case .paste: "⌘V 粘贴"
        case .commandTab: "⌘⇥ 切换应用"
        case .volumeUp: "增大音量"
        case .volumeDown: "减小音量"
        case .mute: "静音"
        case .playPause: "播放 / 暂停"
        case .customShortcut: "自定义快捷键…"
        }
    }
}

extension VoiceTrigger {
    var title: String {
        switch self {
        case .function: "Fn / 地球键"
        case .leftControl: "左 Control"
        case .rightControl: "右 Control"
        case .leftCommand: "左 Command"
        case .rightCommand: "右 Command"
        case .leftOption: "左 Option"
        case .rightOption: "右 Option"
        }
    }
}
