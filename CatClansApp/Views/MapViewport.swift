import SwiftUI

/// Shared iOS 15 camera. State belongs to the viewport, not to resource/battle snapshots.
struct MapViewport<Content: View>: View {
    let worldSize: V2
    let home: V2
    var initialZoom: Double = 1.8
    var onTap: (V2) -> Void = { _ in }
    var onPreview: (V2?) -> Void = { _ in }
    let content: Content

    @State private var camera: MapCamera
    @GestureState private var touching = false
    @GestureState private var magnifying = false
    @State private var pinchBase: Double?
    @State private var dragLast = CGSize.zero
    @State private var dragDistance: CGFloat = 0
    @State private var suppressTapUntil = Date.distantPast
    @State private var touchSerial = 0

    init(worldSize: V2, home: V2, initialZoom: Double = 1.8,
         onTap: @escaping (V2) -> Void = { _ in },
         onPreview: @escaping (V2?) -> Void = { _ in },
         @ViewBuilder content: () -> Content) {
        self.worldSize = worldSize
        self.home = home
        self.initialZoom = initialZoom
        self.onTap = onTap
        self.onPreview = onPreview
        self.content = content()
        _camera = State(initialValue: MapCamera(worldSize: worldSize, viewport: V2(1, 1),
                                                center: home, zoom: initialZoom))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.ccGrassB
                content
                    .frame(width: CGFloat(worldSize.x), height: CGFloat(worldSize.y))
                    .scaleEffect(CGFloat(camera.scale), anchor: .topLeading)
                    .offset(x: CGFloat(camera.worldToScreen(V2(0, 0)).x),
                            y: CGFloat(camera.worldToScreen(V2(0, 0)).y))
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .clipped()
            .contentShape(Rectangle())
            .gesture(panAndTap)
            .simultaneousGesture(magnification)
            .overlay(alignment: .top) { cameraControls.padding(.top, 4) }
            .onAppear {
                camera.resize(V2(Double(geo.size.width), Double(geo.size.height)))
                camera.focus(home, zoom: initialZoom)
            }
            .onChange(of: touching) { active in
                if !active {
                    dragLast = .zero
                    dragDistance = 0
                    onPreview(nil)
                }
            }
            .onChange(of: magnifying) { active in
                if !active {
                    pinchBase = nil
                    suppressTapUntil = Date().addingTimeInterval(0.3)
                    onPreview(nil)
                }
            }
            .onChange(of: geo.size) { size in
                camera.resize(V2(Double(size.width), Double(size.height)))
            }
        }
    }

    private var magnification: some Gesture {
        MagnificationGesture()
            .updating($magnifying) { _, active, _ in active = true }
            .onChanged { amount in
                if pinchBase == nil { pinchBase = camera.zoom }
                suppressTapUntil = Date().addingTimeInterval(0.3)
                touchSerial += 1
                onPreview(nil)
                camera.setZoom((pinchBase ?? camera.zoom) * Double(amount))
            }
            .onEnded { _ in
                pinchBase = nil
                suppressTapUntil = Date().addingTimeInterval(0.3)
                onPreview(nil)
            }
    }

    private var panAndTap: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .updating($touching) { _, active, _ in active = true }
            .onChanged { value in
                let travel = hypot(value.translation.width, value.translation.height)
                dragDistance = max(dragDistance, travel)
                if pinchBase == nil, Date() > suppressTapUntil {
                    if dragDistance > 6 {
                        camera.pan(screenDelta: V2(Double(value.translation.width - dragLast.width),
                                                   Double(value.translation.height - dragLast.height)))
                        onPreview(nil)
                    } else {
                        onPreview(camera.screenToWorld(V2(Double(value.location.x), Double(value.location.y))))
                    }
                }
                dragLast = value.translation
            }
            .onEnded { value in
                let wasTap = dragDistance <= 6 && hypot(value.translation.width, value.translation.height) <= 6
                dragLast = .zero
                dragDistance = 0
                onPreview(nil)
                touchSerial += 1
                let serial = touchSerial
                let world = camera.screenToWorld(V2(Double(value.location.x), Double(value.location.y)))
                // Defer briefly: a simultaneous pinch may deliver its ending after the drag.
                // The generation guard also invalidates pending taps on a second interaction.
                if wasTap {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        guard serial == touchSerial, pinchBase == nil, Date() > suppressTapUntil else { return }
                        onTap(world)
                    }
                }
            }
    }

    private var cameraControls: some View {
        HStack(spacing: 0) {
            cameraButton("minus", label: "Отдалить") { camera.setZoom(camera.zoom / 1.3) }
            cameraButton("plus", label: "Приблизить") { camera.setZoom(camera.zoom * 1.3) }
            cameraButton("house", label: "К дому") { camera.focus(home, zoom: initialZoom) }
            cameraButton("arrow.up.left.and.arrow.down.right", label: "Вся карта") {
                camera.focus(worldSize * 0.5, zoom: 1)
            }
        }
        .background(Capsule().fill(Color.black.opacity(0.45)))
    }

    private func cameraButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            touchSerial += 1
            onPreview(nil)
            action()
        } label: {
            Image(systemName: symbol).font(.system(size: 14, weight: .semibold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .foregroundColor(.white)
        .accessibilityLabel(label)
    }
}
