//
//  permissions.swift
//  RedLightCameraTest
//
//  Created by Ryan Law on 4/21/25.
//

import Foundation
import AVFoundation

enum CameraConfigurationStatus {
    case success
    case permissionDenied
    case failed
}


class Permissions:NSObject {
    var status: CameraConfigurationStatus = .failed
    private var sessionQueue:DispatchQueue?
    weak var delegate: CamDelegate?
    
    
    init(sessionQueue: DispatchQueue? = nil) {
        print("inititit")
        self.sessionQueue = sessionQueue
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func attemptToStartCaptureSession() {
        print("hi")
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.status = .success
        case .notDetermined:
            print("not determined")
            self.sessionQueue?.suspend()
            self.getPermissions { granted in
                self.sessionQueue?.resume()
            }
        case.denied:
            self.status = .permissionDenied
        default:
            break
        }
        print("calling didpermissions?")
        self.delegate?.didPermissions()
    }
    
    private func getPermissions(completion: @escaping (Bool) -> ()) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if !granted {
                self.status = .permissionDenied
            } else {
                self.status = .success
            }
            completion(granted)
        }
    }
}
