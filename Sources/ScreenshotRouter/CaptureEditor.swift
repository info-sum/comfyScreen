import CoreImage
import SwiftUI

struct BlurStroke {
    var points: [CGPoint]
    let width: CGFloat

    var outline: CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        if points.allSatisfy({ $0 == first }) {
            let radius = width / 2
            path.addEllipse(in: CGRect(x: first.x - radius, y: first.y - radius, width: width, height: width))
            return path
        }
        path.addLines(between: points)
        return path.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 1)
    }
}

enum CaptureEdits {
    static func blurred(_ image: CGImage) -> CGImage? {
        let input = CIImage(cgImage: image)
        let output = input.clampedToExtent().applyingGaussianBlur(sigma: 16).cropped(to: input.extent)
        return CIContext().createCGImage(output, from: input.extent)
    }

    static func render(_ image: CGImage, blurred: CGImage?, strokes: [BlurStroke], crop: CGRect?) -> CGImage? {
        let result: CGImage
        if strokes.isEmpty {
            result = image
        } else {
            guard let blurred, let context = CGContext(
                data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                space: blurred.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
            let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: bounds.height)
            context.setBlendMode(.copy)
            context.draw(image, in: bounds)
            for stroke in strokes {
                context.saveGState()
                context.concatenate(flip)
                context.addPath(stroke.outline)
                context.clip()
                context.concatenate(flip)
                context.draw(blurred, in: bounds)
                context.restoreGState()
            }
            guard let composited = context.makeImage() else { return nil }
            result = composited
        }

        guard let crop else { return result }
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        return result.cropping(to: crop.integral.intersection(bounds))
    }
}

struct CaptureEditor: View {
    private enum Tool { case crop, blur }

    @ObservedObject var model: RouterModel
    let capture: PendingCapture
    @Environment(\.dismiss) private var dismiss
    @State private var image: CGImage?
    @State private var blurred: CGImage?
    @State private var tool: Tool = .crop
    @State private var crop: CGRect?
    @State private var strokes: [BlurStroke] = []
    @State private var stroke: BlurStroke?
    @State private var brushWidth = 28.0
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(model.text("스크린샷 편집", "Edit screenshot"))
                    .font(.headline)
                Spacer()
                Picker(model.text("편집 도구", "Editing tool"), selection: $tool) {
                    Label(model.text("크롭", "Crop"), systemImage: "crop").tag(Tool.crop)
                    Label(model.text("블러 펜", "Blur Pen"), systemImage: "paintbrush").tag(Tool.blur)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
            }
            GeometryReader { geometry in
                if let image {
                    let scale = min(geometry.size.width / CGFloat(image.width), geometry.size.height / CGFloat(image.height))
                    if scale > 0 {
                        canvas(image, scale: scale)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            HStack {
                if tool == .crop {
                    Text(model.text("남길 영역을 드래그하세요.", "Drag over the area to keep."))
                    Spacer()
                    Button(model.text("크롭 해제", "Clear Crop")) { crop = nil }
                        .disabled(crop == nil)
                } else {
                    Slider(value: $brushWidth, in: 8...80) {
                        Text(model.text("펜 굵기", "Brush Size"))
                    }
                    .frame(width: 220)
                    Spacer()
                    Button(model.text("획 실행 취소", "Undo Stroke")) {
                        if !strokes.isEmpty { strokes.removeLast() }
                    }
                    .disabled(strokes.isEmpty)
                }
            }
            .foregroundStyle(.secondary)

            if let error {
                Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button(model.text("취소", "Cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(model.text("적용", "Apply"), action: apply)
                    .keyboardShortcut(.defaultAction)
                    .disabled(image == nil || (crop == nil && strokes.isEmpty))
            }
        }
        .padding(20)
        .frame(width: 710, height: 474)
        .task {
            image = model.preview?.cgImage(forProposedRect: nil, context: nil, hints: nil)
            if image == nil { showError() }
        }
    }

    private func canvas(_ image: CGImage, scale: CGFloat) -> some View {
        let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let bounds = CGRect(origin: .zero, size: size)
        return Canvas { context, _ in
            context.draw(Image(decorative: image, scale: 1), in: bounds)
            if let blurred {
                for stroke in strokes + (stroke.map { [$0] } ?? []) {
                    var layer = context
                    layer.clip(to: Path(stroke.outline).applying(transform))
                    layer.blendMode = .copy
                    layer.draw(Image(decorative: blurred, scale: 1), in: bounds)
                }
            }
            if let crop {
                let selection = crop.applying(transform)
                var shade = Path(bounds)
                shade.addRect(selection)
                context.fill(shade, with: .color(.black.opacity(0.52)), style: FillStyle(eoFill: true))
                context.stroke(Path(selection), with: .color(.white), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .contentShape(Rectangle())
        .accessibilityLabel(model.text("스크린샷 편집 미리보기", "Screenshot editing preview"))
        .gesture(DragGesture(minimumDistance: tool == .crop ? 2 : 0)
            .onChanged { value in
                let point = pixel(value.location, in: bounds, scale: scale)
                switch tool {
                case .crop:
                    let start = pixel(value.startLocation, in: bounds, scale: scale)
                    let rect = CGRect(x: min(start.x, point.x), y: min(start.y, point.y),
                                      width: abs(start.x - point.x), height: abs(start.y - point.y))
                    crop = rect.width >= 1 && rect.height >= 1 ? rect : nil
                case .blur:
                    if blurred == nil { blurred = CaptureEdits.blurred(image) }
                    guard blurred != nil else { showError(); return }
                    if stroke == nil {
                        stroke = BlurStroke(points: [pixel(value.startLocation, in: bounds, scale: scale)], width: brushWidth / scale)
                    }
                    stroke?.points.append(point)
                }
            }
            .onEnded { value in
                guard var finished = stroke else { return }
                finished.points.append(pixel(value.location, in: bounds, scale: scale))
                strokes.append(finished)
                stroke = nil
            })
    }

    private func pixel(_ point: CGPoint, in bounds: CGRect, scale: CGFloat) -> CGPoint {
        CGPoint(x: min(max(point.x, 0), bounds.width) / scale, y: min(max(point.y, 0), bounds.height) / scale)
    }

    private func apply() {
        guard let image, let result = CaptureEdits.render(image, blurred: blurred, strokes: strokes, crop: crop) else {
            showError()
            return
        }
        do {
            try model.applyEdit(result, to: capture)
            dismiss()
        } catch {
            showError()
        }
    }

    private func showError() {
        error = model.text("스크린샷을 편집하지 못했습니다.", "Could not edit the screenshot.")
    }
}
