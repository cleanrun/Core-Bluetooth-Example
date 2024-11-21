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
    @IBOutlet weak var sendImageButton: UIButton!
    
    private var peripheralManager: CBPeripheralManager!
    private var peripheralManagerQueue = DispatchQueue(label: "peripheral-manager-queue", qos: .utility)
    private var messageCharacteristic: CBMutableCharacteristic? = nil
    private var jpegCharacteristic: CBMutableCharacteristic? = nil
    
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
            
            self?.sendMessageButton.isHidden = value == nil
            self?.sendImageButton.isHidden = value == nil
        }.store(in: &disposables)
    }
    
    @IBAction func sendMessageAction(_ sender: Any) {
        guard let messageCharacteristic, let message = "This is a message".data(using: .utf8) else { return }

        if peripheralManager.updateValue(message, for: messageCharacteristic, onSubscribedCentrals: nil) {
            print("\(#function); Message sent")
        } else {
            print("\(#function); Message not sent")
        }
    }
    
    @IBAction func sendImageAction(_ sender: Any) {
        guard let jpegCharacteristic,
              let exampleImageURL = Bundle.main.url(forResource: "example-image", withExtension: "png"),
              let imageData = try? Data(contentsOf: exampleImageURL)
        else { return }
        
        if peripheralManager.updateValue(imageData, for: jpegCharacteristic, onSubscribedCentrals: nil) {
            print("\(#function); Image sent")
        } else {
            print("\(#function); Image not sent")
        }
    }
    
}

// MARK: - Peripheral Manager delegate

extension PeripheralViewController: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        print("\(#function); state: \(peripheral.state)")
        
        if peripheral.state == .poweredOn {
            let messageCharacteristic = CBMutableCharacteristic(type: messageCharacteristicUUID, properties: [.notify, .read, .write], value: nil, permissions: [.readable, .writeable])
            
            let jpegCharacteristic = CBMutableCharacteristic(type: jpegCharacteristicUUID, properties: [.notify], value: nil, permissions: [.readable])
            
            let service = CBMutableService(type: serviceUUID, primary: true)
            service.characteristics = [messageCharacteristic, jpegCharacteristic]
            peripheralManager.add(service)
            self.messageCharacteristic = messageCharacteristic
            self.jpegCharacteristic = jpegCharacteristic
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
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        print("\(#function)")
    }
}
