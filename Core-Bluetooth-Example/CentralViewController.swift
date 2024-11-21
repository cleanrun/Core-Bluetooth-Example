//
//  CentralViewController.swift
//  Core-Bluetooth-Example
//
//  Created by Marchell on 11/20/24.
//

import UIKit
import Combine
import CoreBluetooth

final class CentralViewController: UIViewController {
    @IBOutlet private weak var peripheralsTableView: UITableView!
    
    private var centralManager: CBCentralManager!
    private var centralManagerQueue = DispatchQueue(label: "central-manager-queue", qos: .utility)
    
    @Published private var connectedPeripheral: CBPeripheral?
    
    @Published private var discoveredPeripherals: [CBPeripheral] = []
    private var disposables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCentralManager()
        setupBindings()
    }

    private func setupCentralManager() {
        centralManager = CBCentralManager(delegate: self, queue: centralManagerQueue)
        centralManager.scanForPeripherals(withServices: [])
    }
    
    private func connect(to peripheral: CBPeripheral) {
        self.connectedPeripheral = peripheral
        centralManager.connect(peripheral)
        peripheral.delegate = self
    }
    
    private func disconnectPeripheral() {
        guard let connectedPeripheral else { return }
        
        centralManager.cancelPeripheralConnection(connectedPeripheral)
        self.connectedPeripheral = nil
    }
    
    private func setupBindings() {
        peripheralsTableView.delegate = self
        peripheralsTableView.dataSource = self
        
        $discoveredPeripherals.combineLatest($connectedPeripheral).receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.peripheralsTableView.reloadData()
        }.store(in: &disposables)
    }

}

// MARK: - Table View delegate and data source
extension CentralViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            1
        } else {
            discoveredPeripherals.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "PeripheralCell")
        cell.textLabel?.text = if indexPath.section == 0 {
            if let connectedPeripheral {
                "Connected to: \(connectedPeripheral.name ?? "Unknown")"
            } else {
                "Not connected"
            }
        } else {
            discoveredPeripherals[indexPath.row].name ?? "Unknown"
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        40
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if connectedPeripheral != nil {
            disconnectPeripheral()
        }
        
        connect(to: discoveredPeripherals[indexPath.row])
    }
    
}

// MARK: - Central Manager delegate

extension CentralViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("\(#function); state: \(central.state)")
        if central.state == .poweredOn, !central.isScanning {
            centralManager.scanForPeripherals(withServices: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.name != nil, !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if let name = peripheral.name {
            print("\(#function); name: \(name), identifier: \(peripheral.identifier), state: \(peripheral.state)")
        }
        
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        print("\(#function); name: \(peripheral.name ?? "nil"), error: \(error?.localizedDescription ?? "Unknown error")")
    }
}

// MARK: - Peripheral delegate

extension CentralViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        if let error {
            print("\(#function); error: \(error.localizedDescription)")
            return
        }
        
        if let value = characteristic.value {
            print("Characteristic \(characteristic.uuid) value: \(value)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        if let error {
            print("\(#function); error: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            print("\(#function); Services not available")
            return
        }
        
        services.forEach {
            print("Discovered service: \($0.uuid), description: \($0.description), primary: \($0.isPrimary)")
            peripheral.discoverCharacteristics(nil, for: $0)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        if let error {
            print("\(#function); error: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            print("\(#function); Characteristics not available")
            return
        }
        
        characteristics.forEach {
            print("Discovered characteristics: \($0.uuid), description: \($0.description)")
            
            if $0.properties.contains(.read) {
                peripheral.readValue(for: $0)
                if let value = $0.value, let valueToString = String(data: value, encoding: .utf8) {
                    print("Characteristic value: \(valueToString)")
                }
            }
            
            if $0.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: $0)
            }
        }
    }
}

