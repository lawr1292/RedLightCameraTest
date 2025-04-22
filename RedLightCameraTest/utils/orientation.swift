//
//  orientation.swift
//  RedLightCameraTest
//
//  Created by Ryan Law on 4/21/25.
//
import UIKit
import Foundation
import AVFoundation

class MyOrientation: NSObject {
    
    var ourVideoRotation = CGFloat(90)
    var ourImageOrientation: CGImagePropertyOrientation = .up
    var videoDataOutput:AVCaptureVideoDataOutput
    var session:AVCaptureSession
    weak var delegate: CamDelegate?

    
    init(videoDataOutput:AVCaptureVideoDataOutput, session:AVCaptureSession) {
        self.videoDataOutput = videoDataOutput
        self.session = session
        super.init()
        setUpOrientationChangeNotification()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setUpOrientationChangeNotification() {
        print("observer adad")
      NotificationCenter.default.addObserver(
        self, selector: #selector(orientationDidChange),
        name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    func setRotationAndImageOrientation(ori:UIDeviceOrientation){
        switch ori {
        case .portrait:
            ourVideoRotation = CGFloat(90)
            ourImageOrientation = .up
        case .portraitUpsideDown:
            ourVideoRotation = CGFloat(270)
            ourImageOrientation = .down
        case .landscapeRight:
            ourVideoRotation = CGFloat(0)
            ourImageOrientation = .right
        case .landscapeLeft:
            ourVideoRotation = CGFloat(180)
            ourImageOrientation = .left
        default:
          return
        }
    }
    
    @objc func orientationDidChange() {
      setRotationAndImageOrientation(ori: UIDevice.current.orientation)
      self.updateVideoOrientation()
    }
    
    func updateVideoOrientation() {
      guard let connection = videoDataOutput.connection(with: .video) else { return }
        connection.videoRotationAngle = ourVideoRotation
      let currentInput = self.session.inputs.first as? AVCaptureDeviceInput
      if currentInput?.device.position == .front {
        connection.isVideoMirrored = true
      } else {
        connection.isVideoMirrored = false
      }
        // Ensure the preview layer's frame matches the view's bounds to fill the screen.
        self.delegate?.didOrientation()

    }
    
    deinit {
        NotificationCenter.default.removeObserver(
          self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
}
