//
//  QRScannerView.swift
//  SuperDex
//

import SwiftUI
import AVFoundation

fileprivate struct CameraProperties {
    var session: AVCaptureSession = .init()
    var output: AVCaptureMetadataOutput = .init()
    var scannedCode: String?
    var permissionState: Permission?

    enum Permission: String {
        case idle = "Not Determined"
        case approved = "Access Granted"
        case denied = "Access Denied"
    }

    static func checkAndAskCameraPermission() async -> Permission? {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return Permission.approved
        case .notDetermined:
            if await AVCaptureDevice.requestAccess(for: .video) {
                return Permission.approved
            } else {
                return Permission.denied
            }
        case .denied, .restricted: return Permission.denied
        default: return nil
        }
    }
}

extension View {
    @ViewBuilder
    func qrScanner(isScanning: Binding<Bool>, onScan: @escaping (String) -> Void) -> some View {
        self
            .modifier(QRScannerViewModifier(isScanning: isScanning, onScan: onScan))
    }
}

fileprivate struct QRScannerViewModifier: ViewModifier {
    @Binding var isScanning: Bool
    var onScan: (String) -> Void
    @State private var showFullScreenCover: Bool = false

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $showFullScreenCover) {
                DIQRScannerView {
                    isScanning = false
                    Task { @MainActor in
                        showFullScreenCoverWithoutAnimation(false)
                    }
                } onScan: { code in
                    onScan(code)
                }
                .presentationBackground(.clear)
            }
            .onChange(of: isScanning) { oldValue, newValue in
                if newValue {
                    showFullScreenCoverWithoutAnimation(true)
                }
            }
    }

    private func showFullScreenCoverWithoutAnimation(_ status: Bool) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            showFullScreenCover = status
        }
    }
}

fileprivate struct DIQRScannerView: View {
    var onClose: () -> ()
    var onScan: (String) -> Void
    @State private var isInitialized: Bool = false
    @State private var showContent: Bool = false
    @State private var isExpanding: Bool = false
    @State private var camera: CameraProperties = .init()
    @Environment(\.openURL) private var openURL
    @Environment(SubscriptionManager.self) private var subscription
    @State private var showPhotoPicker: Bool = false
    @State private var showPaywall: Bool = false
    @State private var photoScanFailed: Bool = false

    var body: some View {
        GeometryReader {
            let size = $0.size
            let safeArea = $0.safeAreaInsets

            let haveDynamicIsland: Bool = safeArea.top >= 59
            let dynamicIslandWidth: CGFloat = 120
            let dynamicIslandHeight: CGFloat = 36
            let topOffset: CGFloat = haveDynamicIsland ? (11 + max((safeArea.top - 59), 0)) : (isExpanding ? (nonDynamicIslandHaveSpacing ? safeArea.top : -20) : -50)

            let expandedWidth: CGFloat = size.width - 30
            let expandedHeight: CGFloat = expandedWidth

            ZStack(alignment: .top) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .contentShape(.rect)
                    .opacity(isExpanding ? 1 : 0)
                    .onTapGesture {
                        toggle(false)
                    }

                if showContent {
                    ConcentricRectangle(corners: .concentric(minimum: .fixed(30)), isUniform: true)
                        .fill(.black)
                        .overlay {
                            GeometryReader {
                                let cameraSize = $0.size

                                ScannerView(cameraSize)
                            }
                            .overlay(alignment: .bottom) {
                                Text("Scan a SuperDex QR code")
                                    .font(.caption2)
                                    .foregroundStyle(.white.secondary)
                                    .lineLimit(1)
                                    .fixedSize()
                                    .offset(y: 25)
                            }
                            .padding(80)
                            .compositingGroup()
                            .blur(radius: isExpanding ? 0 : 15)
                            .opacity(isExpanding ? 1 : 0)
                            .geometryGroup()
                            .offset(y: nonDynamicIslandHaveSpacing || haveDynamicIsland ? 0 : 10)
                        }
                        .overlay {
                            PermissionDeniedView()
                        }
                        .frame(
                            width: isExpanding ? expandedWidth : dynamicIslandWidth,
                            height: isExpanding ? expandedHeight : dynamicIslandHeight
                        )
                        .offset(y: topOffset)
                        .background {
                            if isExpanding {
                                Rectangle()
                                    .fill(.clear)
                                    .onDisappear {
                                        showContent = false
                                    }
                            }
                        }
                        .transition(.identity)
                        .onDisappear {
                            onClose()
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .overlay(alignment: .bottom) {
                if isExpanding {
                    photoScanButton
                        .padding(.bottom, 80)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .ignoresSafeArea()
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPicker { image in
                    showPhotoPicker = false
                    handlePickedImage(image)
                }
                .ignoresSafeArea()
            }
            .paywallSheet(isPresented: $showPaywall)
            .alert("No QR Found", isPresented: $photoScanFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("We couldn't find a SuperDex QR code in that image. Try another photo.")
            }
            .task {
                guard !isInitialized else { return }
                isInitialized = true
                showContent = true
                try? await Task.sleep(for: .seconds(0.05))
                toggle(true)
                camera.permissionState = await CameraProperties.checkAndAskCameraPermission()
            }
            .onChange(of: camera.scannedCode) { oldValue, newValue in
                if let newValue {
                    onScan(newValue)
                    toggle(false)
                }
            }
        }
        .statusBarHidden()
    }

    @ViewBuilder
    private func ScannerView(_ size: CGSize) -> some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)

        ZStack {
            if let permissionState = camera.permissionState {
                if permissionState == .approved {
                    CameraLayerView(size: size, camera: $camera)
                        .overlay(alignment: .top) {
                            ScannerAnimation(size.height)
                        }
                }
            }

            shape
                .stroke(.white, lineWidth: 2)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
    }

    @ViewBuilder
    private func PermissionDeniedView() -> some View {
        VStack(spacing: 4) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 45))
                .foregroundStyle(.white)

            Text("Permission denied")
                .font(.caption)
                .foregroundStyle(.red)

            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                Button("Go to Settings") {
                    openURL(settingsURL)
                }
                .font(.caption)
                .foregroundStyle(.white)
                .underline()
            }
        }
        .fixedSize()
        .compositingGroup()
        .opacity(camera.permissionState == .denied ? 1 : 0)
        .blur(radius: isExpanding ? 0 : 15)
        .opacity(isExpanding ? 1 : 0)
    }

    @ViewBuilder
    private func ScannerAnimation(_ height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white)
            .frame(height: 2.5)
            .phaseAnimator([false, true], content: { content, isScanning in
              content
                    .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: isScanning ? 15 : -15)
                    .offset(y: isScanning ? height : 0)
            }, animation: { _ in
                    .easeInOut(duration: 0.85).delay(0.1)
            })
    }

    @ViewBuilder
    private var photoScanButton: some View {
        Button {
            if subscription.isPro {
                showPhotoPicker = true
            } else {
                showPaywall = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 15, weight: .semibold))
                Text("Scan from Photos")
                    .font(.gilroy(.semiBold, size: 15))
                if !subscription.isPro {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func handlePickedImage(_ image: UIImage?) {
        guard let image else { return }   // cancelled or failed load — stay silent
        Task {
            let code = await Task.detached { QRImageDecoder.decode(image) }.value
            await MainActor.run {
                if let code {
                    onScan(code)
                    toggle(false)
                } else {
                    photoScanFailed = true
                }
            }
        }
    }

    private func toggle(_ status: Bool) {
        withAnimation(.interpolatingSpring(duration: 0.35, bounce: 0, initialVelocity: 0)) {
            isExpanding = status
        }

        if !status {
            DispatchQueue.global(qos: .background).async {
                camera.session.stopRunning()
            }
        }
    }

    var nonDynamicIslandHaveSpacing: Bool {
        return true
    }
}

fileprivate struct CameraLayerView: UIViewRepresentable {
    var size: CGSize
    @Binding var camera: CameraProperties

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .init(origin: .zero, size: size))
        view.backgroundColor = .clear

        let layer = AVCaptureVideoPreviewLayer(session: camera.session)
        layer.frame = .init(origin: .zero, size: size)
        layer.videoGravity = .resizeAspectFill
        layer.masksToBounds = true
        view.layer.addSublayer(layer)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: CameraLayerView

        init(parent: CameraLayerView) {
            self.parent = parent
            super.init()
            Task {
                setupCamera()
            }
        }

        func setupCamera() {
            do {
                let session = parent.camera.session
                let output = parent.camera.output

                guard !session.isRunning else { return }
                guard let device = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first else {
                    return
                }

                let input = try AVCaptureDeviceInput(device: device)
                guard session.canAddInput(input), session.canAddOutput(output) else {
                    return
                }

                session.beginConfiguration()
                session.addInput(input)
                session.addOutput(output)
                output.metadataObjectTypes = [.qr]
                output.setMetadataObjectsDelegate(self, queue: .main)
                session.commitConfiguration()

                DispatchQueue.global(qos: .background).async {
                    session.startRunning()
                }
            } catch {
                print(error.localizedDescription)
            }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject, let code = object.stringValue {
                guard parent.camera.scannedCode == nil else { return }
                parent.camera.scannedCode = code
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            }
        }
    }
}
