//
//  ViewController.swift
//  RedLightCameraTest
//
//  Created by Ryan Law on 4/21/25.
//

import UIKit
import AVFoundation
import Photos

protocol CamDelegate: AnyObject {
    func didPermissions()
    func didOrientation()
}
// We need to take photos
class ViewController: UIViewController, CamDelegate {
    
    private var photoOutput = AVCapturePhotoOutput()
    var bufferSize: CGSize = .zero
    private var camera: AVCaptureDevice?
    private let session = AVCaptureSession()
    private var videoDataOutput = AVCaptureVideoDataOutput()
    //private var previewLayer: AVCaptureVideoPreviewLayer! = nil
    var isSessionRunning: Bool = false
    private let sessionQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    var highestSupportedFrameRate = 0.0
    var highestFrameRate: CMTime? = nil
    var highestQualityFormat: AVCaptureDevice.Format? = nil
    @IBOutlet var toggler: UISwitch!
    @IBOutlet var takePhotoButton: UIButton!
    private var permissionsClass: Permissions
    private var orientationClass: MyOrientation
    var isPhotoLibraryReadWriteAccessGranted: Bool {
        get async {
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            
            // Determine if the user previously authorized read/write access.
            var isAuthorized = status == .authorized
            
            // If the system hasn't determined the user's authorization status,
            // explicitly prompt them for approval.
            if status == .notDetermined {
                isAuthorized = await PHPhotoLibrary.requestAuthorization(for: .readWrite) == .authorized
            }
            
            return isAuthorized
        }
    }
    
    // Correct initializer
    required init?(coder: NSCoder) {
        // Initialize your custom classes
        permissionsClass = Permissions(sessionQueue: sessionQueue)
        orientationClass = MyOrientation(videoDataOutput: videoDataOutput, session: session)

        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        takePhotoButton.addTarget(self, action: #selector(handleTap), for: .touchDown)
        toggler.addTarget(self, action: #selector(switchValueDidChange), for: .valueChanged)
        self.view.backgroundColor = UIColor(red: 255, green: 0, blue: 0, alpha: 1)
        permissionsClass.delegate = self
        orientationClass.delegate = self
        permissionsClass.attemptToStartCaptureSession()
    }

    func didPermissions(){
        print("did permissions")
        self.sessionQueue.async {
            self.setupCaptureSession()
        }
    }
    
    func didOrientation(){
        DispatchQueue.main.async {
            // self.setupLayers()
        }
    }
    
    private func setupCaptureSession() {
        print("setting up capture session")
        session.beginConfiguration()
        setupInput()
        setupOutput()
        session.commitConfiguration()
        //setupVision()
        startCaptureSession()
        //setupPreviewLayer()
    }
    
    private func setupInput() {
        var deviceInput: AVCaptureDeviceInput!
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTripleCamera, .builtInTelephotoCamera, .builtInLiDARDepthCamera, .builtInDualWideCamera, .builtInDualCamera], mediaType: .video, position: .front)
        
        var highestQualityDevice: AVCaptureDevice?
        session.sessionPreset = .high
        
        for device in discoverySession.devices.reversed() {
            // print("Device: \(device)")
            for format in device.formats {
                if(format.isHighestPhotoQualitySupported){
                    //print("is highest photo quality supported: \(format.isHighestPhotoQualitySupported)")
                    //print("is merely high photo quality supported: \(format.isHighPhotoQualitySupported)")
                    //print("Supported max photo dims: \(format.supportedMaxPhotoDimensions)")
                    for range in format.videoSupportedFrameRateRanges {
                        if range.maxFrameRate > highestSupportedFrameRate {
                            highestSupportedFrameRate = range.maxFrameRate
                            highestQualityDevice = device
                            highestQualityFormat = format
                            highestFrameRate = CMTime(value: 1, timescale: CMTimeScale(range.maxFrameRate))
                        }
                    }
                }
            }
        }
        
        camera = highestQualityDevice
        print("Device chosen: \(String(describing: highestQualityDevice))")
        guard let camera = camera else {
            print("No camera available")
            return
        }
                
        do {
            deviceInput = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(deviceInput) {
                session.addInput(deviceInput)
            } else {
                print("Could not add input")
                return
            }
        } catch {
            fatalError("Cannot create video device input")
        }
    }
    
    
    private func setupOutput() {
//        let sampleBufferQueue = DispatchQueue(label: "SampleBufferQueue")
//        videoDataOutput.setSampleBufferDelegate(self, queue: sampleBufferQueue)
//        videoDataOutput.alwaysDiscardsLateVideoFrames = true
//        videoDataOutput.videoSettings = [ String(kCVPixelBufferPixelFormatTypeKey) : kCVPixelFormatType_32BGRA]
//        orientationClass.setRotationAndImageOrientation(ori: UIDevice.current.orientation)
//
//        if session.canAddOutput(videoDataOutput) {
//            session.addOutput(videoDataOutput)
//        } else {
//            print("Output setup error")
//        }
//        
//        guard let connection = videoDataOutput.connection(with: .video) else { return }
//        connection.videoRotationAngle = orientationClass.ourVideoRotation
//        let currentInput = self.session.inputs.first as? AVCaptureDeviceInput
//        if currentInput?.device.position == .front {
//          connection.isVideoMirrored = true
//        } else {
//          connection.isVideoMirrored = false
//        }
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        do {
            try camera?.lockForConfiguration()
            if let format = highestQualityFormat {
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                bufferSize.width = CGFloat(dimensions.width)
                bufferSize.height = CGFloat(dimensions.height)
                camera?.activeFormat = format
                camera?.activeVideoMinFrameDuration = highestFrameRate!
                camera?.activeVideoMaxFrameDuration = highestFrameRate!
            }
            camera?.unlockForConfiguration()
        } catch {
            print("Error setting format or dimensions")
        }
    }
    
//    private func setupPreviewLayer() {
//        DispatchQueue.main.async {
//            self.previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
//            self.previewLayer.frame = self.view.bounds
//            self.previewLayer.videoGravity = .resizeAspectFill
//            //self.previewLayer.connection?.videoRotationAngle = self.ourVideoRotation
//            self.view.layer.addSublayer(self.previewLayer)
//            self.startCaptureSession()
//        }
//    }
    
    private func startCaptureSession() {
        sessionQueue.async {
            if self.permissionsClass.status == .success {
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
            }
        }
    }
    
    @objc func switchValueDidChange(){
        if(toggler.isOn) {
            self.view.backgroundColor = UIColor(red: 255, green: 0, blue: 0, alpha: 1)
        } else {
            self.view.backgroundColor = UIColor(red: 255, green: 255, blue: 255, alpha: 1)
        }
    }
    
    @objc private func handleTap(_ sender: UIButton) {
        capturePhoto()
    }
    
    private func capturePhoto() {
        let photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self!.photoOutput.capturePhoto(with: photoSettings, delegate: self!)
           }
    }

}
// take photo with vol down button?
// photo post processing: -> redscale -> greyscale

// MARK: - AVCapturePhotoCaptureDelegate
extension ViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }
//        guard let imageData = photo.fileDataRepresentation() else { return }
//        let image = UIImage(data: imageData)
//        let currentDateTime = Date()
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyMMddHHmmss"
//        let timeStr = formatter.string(from: currentDateTime)
//        // print("Time string: \(timeStr)")
        Task {
           await save(photo: photo)
        }
        print("Photo captured!")
    }
    
    func save(photo: AVCapturePhoto) async {
        // Confirm the user granted read/write access.
        guard await isPhotoLibraryReadWriteAccessGranted else { return }
        
        // Create a data representation of the photo and its attachments.
        if let photoData = photo.fileDataRepresentation() {
            PHPhotoLibrary.shared().performChanges {
                // Save the photo data.
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: photoData, options: nil)
            } completionHandler: { success, error in
                if let error {
                    print("Error saving photo: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
}
