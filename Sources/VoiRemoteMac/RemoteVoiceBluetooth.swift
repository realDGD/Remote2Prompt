import CoreBluetooth
import Foundation
import VoiRemoteCore

/// One selected ATVV connection; CoreBluetooth delegates are delivered on the main queue.
@MainActor
final class RemoteVoiceBluetooth: NSObject, RemoteVoiceTransport, @preconcurrency CBCentralManagerDelegate, @preconcurrency CBPeripheralDelegate {
    var onReady: ((VoiceCapabilities) -> Void)?
    var onOpen: (() -> Void)?
    var onStarted: (() -> Void)?
    var onStopped: ((RemoteVoiceStopReason) -> Void)?
    var onAudio: ((Data) -> Void)?
    var onSync: ((Data) -> Void)?
    var onStatus: ((String) -> Void)?
    var onFailure: ((String) -> Void)?
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var tx: CBCharacteristic?
    private var audio: CBCharacteristic?
    private var control: CBCharacteristic?
    private var enabled = false
    private var requestedCapabilities = false
    private var ready = false
    private var session: UInt8 = 0
    private var generation: UInt64 = 0
    private var timeout: Task<Void, Never>?
    private let serviceID = CBUUID(string: RemoteVoiceProtocol.service)

    func start() {
        guard !enabled else { return }
        enabled = true; generation &+= 1
        let token = generation
        timeout?.cancel()
        timeout = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(8)) } catch { return }
            guard let self, self.enabled, self.generation == token, !self.ready else { return }
            self.fail("遥控器音频查找或初始化超时，请唤醒后重试。")
        }
        onStatus?("等待蓝牙就绪")
        central = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionShowPowerAlertKey: false])
    }
    func stop() {
        enabled = false; generation &+= 1; timeout?.cancel()
        if ready { _ = close() }
        central?.stopScan()
        if let peripheral { peripheral.delegate = nil; central?.cancelPeripheralConnection(peripheral) }
        central?.delegate = nil; central = nil; clearConnection()
    }
    @discardableResult func open() -> Bool {
        ready && write(RemoteVoiceProtocol.openMicrophone)
    }
    @discardableResult func close() -> Bool {
        ready && write(RemoteVoiceProtocol.closeMicrophone(session: session))
    }
    private func clearConnection() {
        ready = false; requestedCapabilities = false; peripheral = nil
        tx = nil; audio = nil; control = nil; session = 0
    }
    private func discover() {
        guard enabled, let central, central.state == .poweredOn, peripheral == nil else { return }
        onStatus?("查找遥控器音频通道，请按普通键唤醒遥控器")
        let connected = central.retrieveConnectedPeripherals(withServices: [serviceID, CBUUID(string: "1812")])
        if let candidate = connected.first(where: { supportedName($0.name) }) { connect(candidate); return }
        central.scanForPeripherals(withServices: [serviceID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }
    private func supportedName(_ name: String?) -> Bool {
        guard let name else { return false }
        return ["mi rc", "xiaomi bluetooth remote 2 pro", "小米蓝牙语音遥控器"].contains(name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
    private func connect(_ value: CBPeripheral) {
        guard enabled, peripheral == nil else { return }
        central?.stopScan(); peripheral = value; value.delegate = self
        onStatus?("正在连接遥控器音频")
        central?.connect(value, options: nil)
    }
    private func fail(_ message: String) {
        guard enabled else { return }
        generation &+= 1; timeout?.cancel()
        let previousCentral = central
        central = nil; previousCentral?.delegate = nil; previousCentral?.stopScan()
        if let peripheral { peripheral.delegate = nil; previousCentral?.cancelPeripheralConnection(peripheral) }
        clearConnection(); enabled = false; onFailure?(message)
    }
    private func write(_ data: Data) -> Bool {
        guard let peripheral, peripheral.state == .connected, let tx else { return false }
        let type: CBCharacteristicWriteType
        if tx.properties.contains(.write) { type = .withResponse }
        else if tx.properties.contains(.writeWithoutResponse) { type = .withoutResponse }
        else { return false }
        peripheral.writeValue(data, for: tx, type: type)
        return true
    }
    private func requestCapabilities() {
        guard !requestedCapabilities, audio?.isNotifying == true, control?.isNotifying == true, tx != nil else { return }
        requestedCapabilities = true
        if !write(RemoteVoiceProtocol.capabilitiesRequest) { fail("遥控器音频通道不可写入。") }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard self.central === central, enabled else { return }
        switch central.state {
        case .poweredOn: discover()
        case .unauthorized: fail("蓝牙访问未允许。")
        case .poweredOff: fail("系统蓝牙已关闭。")
        case .unsupported: fail("此 Mac 不支持所需蓝牙功能。")
        default: break
        }
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard self.central === central, enabled else { return }
        // A service-filtered advertisement is a protocol candidate, never proof of readiness.
        guard supportedName(peripheral.name) || supportedName(advertisementData[CBAdvertisementDataLocalNameKey] as? String) else { return }
        connect(peripheral)
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard self.central === central, self.peripheral === peripheral, enabled else { return }
        onStatus?("正在订阅遥控器音频通道")
        peripheral.discoverServices([serviceID])
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard self.central === central, self.peripheral === peripheral else { return }; fail("无法连接遥控器音频。")
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard self.central === central, self.peripheral === peripheral else { return }; fail("遥控器音频已断开。")
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard self.peripheral === peripheral, enabled else { return }
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == serviceID }) else { fail("遥控器没有提供 ATVV 音频服务。"); return }
        peripheral.discoverCharacteristics([CBUUID(string: RemoteVoiceProtocol.transmit), CBUUID(string: RemoteVoiceProtocol.audio), CBUUID(string: RemoteVoiceProtocol.control)], for: service)
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard self.peripheral === peripheral, enabled else { return }
        guard error == nil else { fail("无法读取遥控器音频通道。"); return }
        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid.uuidString.uppercased() {
            case RemoteVoiceProtocol.transmit: tx = characteristic
            case RemoteVoiceProtocol.audio: audio = characteristic
            case RemoteVoiceProtocol.control: control = characteristic
            default: break
            }
        }
        guard let audio, let control, tx != nil else { fail("遥控器音频通道不完整。"); return }
        for characteristic in [audio, control] {
            guard characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) else { fail("遥控器不支持音频通知。"); return }
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard self.peripheral === peripheral, enabled else { return }
        if error != nil { fail("订阅遥控器音频通知失败。"); return }
        requestCapabilities()
    }
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard self.peripheral === peripheral, enabled, error != nil else { return }
        fail("向遥控器发送音频命令失败。")
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard self.peripheral === peripheral, enabled else { return }
        guard error == nil, let data = characteristic.value, !data.isEmpty, data.count <= 4096 else { fail("遥控器音频数据无效。"); return }
        if characteristic === audio { if ready { onAudio?(data) }; return }
        guard characteristic === control, let opcode = data.first else { return }
        let bytes = Array(data)
        do {
            switch opcode {
            case 11:
                guard requestedCapabilities, !ready else { return }
                let capabilities = try VoiceCapabilities(packet: data)
                ready = true; timeout?.cancel(); onStatus?("遥控器音频已连接 · 16 kHz"); onReady?(capabilities)
            case 8: if ready { onOpen?() }
            case 4:
                guard ready, bytes.count >= 4, bytes[2] == 2 else { throw VoiceProtocolFailure.unsupportedCodec }
                session = bytes[3]; onStarted?()
            case 0: if ready { onStopped?(RemoteVoiceProtocol.stopReason(packet: data) ?? .unspecified) }
            case 10: if ready { onSync?(data) }
            default: break
            }
        } catch { fail("遥控器音频协议或编码不受支持。") }
    }
}
