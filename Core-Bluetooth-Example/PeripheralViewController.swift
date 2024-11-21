//
//  PeripheralViewController.swift
//  Core-Bluetooth-Example
//
//  Created by Marchell on 11/20/24.
//

import UIKit
import Combine
import CoreBluetooth

final class PeripheralViewController: UIViewController {
    @IBOutlet weak var connectionStatusLabel: UILabel!
    @IBOutlet weak var sendMessageButton: UIButton!
    
    private let characteristicUUID = CBUUID(string: "0000FFF1-0000-1000-8000-00805F9B34FB")
    private let serviceUUID = CBUUID(string: "0000FFF0-0000-1000-8000-00805F9B34FB")
    
    private var peripheralManager: CBPeripheralManager!
    private var peripheralManagerQueue = DispatchQueue(label: "peripheral-manager-queue", qos: .utility)
    private var characteristic: CBCharacteristic? = nil
    
    @Published private var connectedCentral: CBCentral?
    private var disposables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPeripheralManager()
        setupBindings()
    }
    
    private func setupPeripheralManager() {
        peripheralManager = CBPeripheralManager(delegate: self, queue: peripheralManagerQueue)
        peripheralManager.startAdvertising(nil)
    }
    
    private func setupBindings() {
        $connectedCentral.receive(on: DispatchQueue.main).sink { [weak self] value in
            if let value {
                self?.connectionStatusLabel.text = "Connected to: \(value.identifier)"
            } else {
                self?.connectionStatusLabel.text = "Not Connected"
            }
        }.store(in: &disposables)
    }
    
    @IBAction func sendMessageAction(_ sender: Any) {
        
    }
    
}

// MARK: - Peripheral Manager delegate

extension PeripheralViewController: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        print("\(#function); state: \(peripheral.state)")
        
        if peripheral.state == .poweredOn {
            let characteristic = CBMutableCharacteristic(type: characteristicUUID, properties: [.notify, .read, .write], value: nil, permissions: [.readable, .writeable])
            let service = CBMutableService(type: serviceUUID, primary: true)
            service.characteristics = [characteristic]
            peripheralManager.add(service)
            self.characteristic = characteristic
            peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [serviceUUID]])
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: (any Error)?) {
        print("\(#function); error: \(error?.localizedDescription ?? "No Error")")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("\(#function); central identifier: \(central.identifier)")
        connectedCentral = central
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("\(#function); central identifier: \(central.identifier)")
        connectedCentral = nil
    }
}
