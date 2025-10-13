import SwiftUI
import AVFoundation

struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    let onError: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onImageCaptured = onImageCaptured
        controller.onError = onError
        controller.onDismiss = { dismiss() }
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

class CameraViewController: UIViewController {
    var onImageCaptured: ((UIImage) -> Void)?
    var onError: ((String) -> Void)?
    var onDismiss: (() -> Void)?

    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Camera should already be stopped, but ensure cleanup happens
        ensureCameraIsStopped()
    }

    deinit {
        ensureCameraIsStopped()
        stopCamera()
    }

    private func ensureCameraIsStopped() {
        // Only stop if still running (idempotent)
        if let session = captureSession, session.isRunning {
            session.stopRunning()
        }
    }

    private func stopCamera() {
        // Clean up all resources
        captureSession?.stopRunning()
        captureSession = nil
        photoOutput = nil
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
    }

    private func setupCamera() {
        // Check authorization
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureCamera()
                    } else {
                        self?.onError?("Camera access denied")
                        self?.onDismiss?()
                    }
                }
            }
        case .denied, .restricted:
            onError?("Camera access is denied. Please enable it in Settings.")
            onDismiss?()
        @unknown default:
            onError?("Unknown camera authorization status")
            onDismiss?()
        }
    }

    private func configureCamera() {
        let errorHandler = onError
        let dismissHandler = onDismiss

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let session = AVCaptureSession()
            session.beginConfiguration()
            session.sessionPreset = .photo

            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                DispatchQueue.main.async {
                    errorHandler?("Camera not available")
                    dismissHandler?()
                }
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if session.canAddInput(input) {
                    session.addInput(input)
                } else {
                    throw NSError(domain: "CameraError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot add camera input"])
                }
            } catch {
                DispatchQueue.main.async {
                    errorHandler?("Failed to access camera: \(error.localizedDescription)")
                    dismissHandler?()
                }
                return
            }

            let output = AVCapturePhotoOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
            } else {
                DispatchQueue.main.async {
                    errorHandler?("Cannot configure camera output")
                    dismissHandler?()
                }
                return
            }

            session.commitConfiguration()

            self.captureSession = session
            self.photoOutput = output

            DispatchQueue.main.async {
                self.setupPreviewLayer()
                self.setupUI()
            }

            session.startRunning()
        }
    }

    private func setupPreviewLayer() {
        guard let session = captureSession else { return }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.insertSublayer(preview, at: 0)
        self.previewLayer = preview
    }

    private func setupUI() {
        // Add capture button (white circle like iOS camera)
        let captureButton = UIButton(type: .custom)
        captureButton.backgroundColor = .white
        captureButton.layer.cornerRadius = 35
        captureButton.layer.borderWidth = 6
        captureButton.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)

        // Add press animation
        captureButton.addTarget(self, action: #selector(buttonPressed), for: .touchDown)
        captureButton.addTarget(self, action: #selector(buttonReleased), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        view.addSubview(captureButton)

        // Add cancel button
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70),

            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            cancelButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    @objc private func buttonPressed(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }
    }

    @objc private func buttonReleased(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = .identity
        }
    }

    @objc private func capturePhoto() {
        guard let photoOutput = photoOutput else { return }

        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    @objc private func cancelTapped() {
        onDismiss?()
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // CRITICAL: Stop camera session IMMEDIATELY and SYNCHRONOUSLY
        // This prevents the -17281 errors and keyboard blocking issues
        if let session = captureSession, session.isRunning {
            session.stopRunning()
        }

        // Process photo on background thread to avoid blocking
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.onError?("Failed to capture photo: \(error.localizedDescription)")
                    self.cleanupAndDismiss()
                }
                return
            }

            guard let imageData = photo.fileDataRepresentation(),
                  let image = UIImage(data: imageData) else {
                DispatchQueue.main.async {
                    self.onError?("Failed to process photo")
                    self.cleanupAndDismiss()
                }
                return
            }

            // Call callbacks on main thread with cleaned up resources
            DispatchQueue.main.async {
                self.onImageCaptured?(image)
                self.cleanupAndDismiss()
            }
        }
    }

    private func cleanupAndDismiss() {
        // Ensure camera is fully stopped and cleaned up
        stopCamera()
        onDismiss?()
    }
}
