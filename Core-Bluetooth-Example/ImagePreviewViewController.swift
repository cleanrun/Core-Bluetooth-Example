//
//  ImagePreviewViewController.swift
//  Core-Bluetooth-Example
//
//  Created by cleanmac on 21/11/24.
//

import UIKit

final class ImagePreviewViewController: UIViewController {
    @IBOutlet weak var previewImageView: UIImageView!
    
    func setImage(data: Data) {
        let image = UIImage(data: data)
        previewImageView.image = image
    }
}
