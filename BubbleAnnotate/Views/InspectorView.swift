import SwiftUI

struct InspectorView: View {
    @ObservedObject var state: TimelineState
    let timelineEngine: TimelineEngine

    var body: some View {
        VStack(spacing: 0) {
            addBar
            Divider()
            if let item = state.selectedItem {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        switch item.content {
                        case .bubble(let data):
                            bubbleInspector(itemID: item.id, data: data)
                        case .arrow(let data):
                            arrowInspector(itemID: item.id, data: data)
                        }
                        timingSection(item: item)
                        Spacer(minLength: 16)
                    }
                }
            } else {
                VStack {
                    Spacer()
                    Text("Select an annotation\nto edit its properties")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .font(.callout)
                    Spacer()
                }
            }
        }
        .frame(minWidth: 220, maxWidth: 280)
    }

    // MARK: - Add bar

    private var addBar: some View {
        HStack(spacing: 8) {
            Button(action: addBubble) {
                Label("Bubble", systemImage: "bubble.left.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button(action: addArrow) {
                Label("Arrow", systemImage: "arrow.up.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Bubble

    @ViewBuilder
    private func bubbleInspector(itemID: AnnotationID, data: BubbleData) -> some View {
        // Content
        inspectorSection("Content") {
            TextEditor(text: Binding(
                get: { data.text },
                set: { state.updateBubbleData(id: itemID, text: $0) }
            ))
            .font(.body)
            .frame(minHeight: 56, maxHeight: 120)
            .scrollContentBackground(.hidden)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(NSColor.separatorColor), lineWidth: 0.5))

            propRow("Emoji") {
                TextField("None", text: Binding(
                    get: { data.leadingEmoji ?? "" },
                    set: { state.updateBubbleData(id: itemID, emoji: $0.isEmpty ? nil : $0) }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }

        // Text — Figma-style: font + size + color on compact rows
        inspectorSection("Text") {
            propRow("Font") {
                Picker("", selection: Binding(
                    get: { data.style.fontName },
                    set: { v in state.updateBubbleStyle(id: itemID) { $0.fontName = v } }
                )) {
                    Text("System").tag("")
                    Text("Rounded").tag("rounded")
                    Text("Serif").tag("serif")
                    Text("Mono").tag("mono")
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
            }
            propRow("Size") {
                HStack(spacing: 4) {
                    TextField("", value: Binding(
                        get: { Int(data.style.fontSize) },
                        set: { newSize in state.updateBubbleStyle(id: itemID) { $0.fontSize = Double(max(8, min(72, newSize))) } }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 36)
                    .multilineTextAlignment(.center)
                    Stepper("", value: Binding(
                        get: { Int(data.style.fontSize) },
                        set: { newSize in state.updateBubbleStyle(id: itemID) { $0.fontSize = Double(max(8, min(72, newSize))) } }
                    ), in: 8...72, step: 1)
                    .labelsHidden()
                }
            }
            propRow("Color") {
                ColorWellPickerView(color: Binding(
                    get: { data.style.textColor },
                    set: { c in state.updateBubbleStyle(id: itemID) { $0.textColor = c } }
                ))
                .frame(width: 28, height: 20)
            }
            propRow("Align") {
                Picker("", selection: Binding(
                    get: { data.style.textAlignment },
                    set: { a in state.updateBubbleStyle(id: itemID) { $0.textAlignment = a } }
                )) {
                    ForEach(BubbleTextAlignment.allCases, id: \.self) { a in
                        Image(systemName: a.icon).tag(a)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 80)
            }
        }

        // Fill & stroke — one row each, swatch + value
        inspectorSection("Style") {
            HStack(spacing: 8) {
                Text("Preset")
                    .frame(width: 48, alignment: .leading)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    ForEach(BubbleBackgroundPreset.allCases, id: \.self) { preset in
                        let isSelected = data.style.backgroundPreset == preset
                        Button {
                            if let style = BubbleStyle.presets.first(where: { $0.backgroundPreset == preset }) {
                                state.updateBubbleData(id: itemID, style: style)
                            }
                        } label: {
                            Text(preset.rawValue.capitalized)
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            propRow("Fill") {
                HStack(spacing: 6) {
                    ColorWellPickerView(color: Binding(
                        get: { data.style.backgroundColor },
                        set: { c in state.updateBubbleStyle(id: itemID) { $0.backgroundColor = c } }
                    ))
                    .frame(width: 28, height: 20)
                    opacityField(data.style.backgroundColor.alpha) { v in
                        state.updateBubbleStyle(id: itemID) { s in
                            s.backgroundColor = CodableColor(red: s.backgroundColor.red, green: s.backgroundColor.green, blue: s.backgroundColor.blue, alpha: v)
                        }
                    }
                }
            }
            propRow("Stroke") {
                HStack(spacing: 6) {
                    ColorWellPickerView(color: Binding(
                        get: { data.style.borderColor },
                        set: { c in state.updateBubbleStyle(id: itemID) { $0.borderColor = c } }
                    ))
                    .frame(width: 28, height: 20)
                    strokeWidthField(data.style.borderWidth) { v in
                        state.updateBubbleStyle(id: itemID) { $0.borderWidth = v }
                    }
                }
            }
            propRow("Corner") {
                cornerField(data.style.cornerRadius) { v in state.updateBubbleStyle(id: itemID) { $0.cornerRadius = v } }
            }
            propRow("Shadow") {
                shadowField(data.style.shadowOpacity) { v in state.updateBubbleStyle(id: itemID) { $0.shadowOpacity = v } }
            }
        }
    }

    // MARK: - Arrow

    @ViewBuilder
    private func arrowInspector(itemID: AnnotationID, data: ArrowData) -> some View {
        inspectorSection("Arrow") {
            propRow("Label") {
                TextField("None", text: Binding(
                    get: { data.label ?? "" },
                    set: { state.updateArrowData(id: itemID, label: $0.isEmpty ? nil : $0) }
                ))
                .textFieldStyle(.roundedBorder)
            }
            colorRow("Color", color: Binding(
                get: { data.style.color },
                set: { c in state.updateArrowStyle(id: itemID) { $0.color = c } }
            ))
            compactSlider("Thickness", value: data.style.thickness, range: 1...10, step: 0.5) { v in
                state.updateArrowStyle(id: itemID) { $0.thickness = v }
            }
            compactSlider("Head", value: data.style.headSize, range: 6...30, step: 1) { v in
                state.updateArrowStyle(id: itemID) { $0.headSize = v }
            }
            propRow("Dashed") {
                Toggle("", isOn: Binding(
                    get: { data.style.isDashed },
                    set: { v in state.updateArrowStyle(id: itemID) { $0.isDashed = v } }
                ))
                .labelsHidden()
            }
            if data.style.isDashed {
                compactSlider("Dash", value: data.style.dashLength, range: 4...20, step: 1) { v in
                    state.updateArrowStyle(id: itemID) { $0.dashLength = v }
                }
            }
        }
    }

    // MARK: - Timing (shared)

    private func timingSection(item: AnnotationItem) -> some View {
        inspectorSection("Timing") {
            HStack {
                label("Start")
                Text(formatTime(item.annotation.startTime)).font(.system(.caption, design: .monospaced))
                Spacer()
                Button("−") { nudgeStart(item.id, backward: true) }.buttonStyle(.borderless)
                Button("+") { nudgeStart(item.id, backward: false) }.buttonStyle(.borderless)
            }
            HStack {
                label("End")
                Text(formatTime(item.annotation.endTime)).font(.system(.caption, design: .monospaced))
                Spacer()
                Button("−") { nudgeEnd(item.id, backward: true) }.buttonStyle(.borderless)
                Button("+") { nudgeEnd(item.id, backward: false) }.buttonStyle(.borderless)
            }
        }
    }

    // MARK: - Layout helpers

    private func inspectorSection<Content: View>(_ title: String,
                                                 @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 14)
                .padding(.bottom, 0)
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
            Divider()
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .frame(width: 56, alignment: .leading)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func propRow<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .frame(width: 48, alignment: .leading)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            content()
            Spacer(minLength: 0)
        }
    }

    private func opacityField(_ value: Double, set: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 2) {
            TextField("", value: Binding(
                get: { Int(round(value * 100)) },
                set: { newVal in set(Double(max(0, min(100, newVal))) / 100) }
            ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 32)
                .multilineTextAlignment(.trailing)
            Text("%").font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    private func strokeWidthField(_ value: Double, set: @escaping (Double) -> Void) -> some View {
        TextField("", value: Binding(
            get: { value },
            set: { newVal in set(max(0, min(12, newVal))) }
        ), format: .number.precision(.fractionLength(1)))
            .textFieldStyle(.roundedBorder)
            .frame(width: 36)
            .multilineTextAlignment(.trailing)
    }

    private func cornerField(_ value: Double, set: @escaping (Double) -> Void) -> some View {
        TextField("", value: Binding(
            get: { Int(value) },
            set: { newVal in set(Double(max(0, min(60, newVal)))) }
        ), format: .number)
            .textFieldStyle(.roundedBorder)
            .frame(width: 36)
            .multilineTextAlignment(.trailing)
    }

    private func shadowField(_ value: Double, set: @escaping (Double) -> Void) -> some View {
        Slider(value: Binding(get: { value }, set: { set($0) }), in: 0...0.5, step: 0.05)
            .frame(maxWidth: 120)
    }

    private func colorRow(_ title: String, color: Binding<CodableColor>) -> some View {
        propRow(title) {
            ColorWellPickerView(color: color)
                .frame(width: 28, height: 20)
        }
    }

    private func compactSlider(_ title: String, value: Double,
                               range: ClosedRange<Double>, step: Double,
                               _ set: @escaping (Double) -> Void) -> some View {
        propRow(title) {
            HStack(spacing: 4) {
                Slider(value: Binding(get: { value }, set: { set($0) }), in: range, step: step)
                    .frame(maxWidth: 100)
                Text(value >= 1 ? "\(Int(value))" : (value < 0.01 ? "0" : String(format: "%.1f", value)))
                    .frame(width: 28, alignment: .trailing)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func addBubble() {
        let start = timelineEngine.snapToFrame(state.currentTime)
        let item = AnnotationItem.bubble(start: start, end: start + 3)
        state.addAnnotation(item)
        state.setSelection(item.id)
    }

    private func addArrow() {
        let start = timelineEngine.snapToFrame(state.currentTime)
        state.addAnnotation(.arrow(start: start, end: start + 3))
    }

    private func nudgeStart(_ id: AnnotationID, backward: Bool) {
        guard let item = state.selectedItem, item.id == id else { return }
        let t = backward ? timelineEngine.nudgeBackward(item.annotation.startTime)
                         : timelineEngine.nudgeForward(item.annotation.startTime)
        if t < item.annotation.endTime - Annotation.minimumDuration {
            state.updateAnnotationTime(id: id, startTime: t)
        }
    }

    private func nudgeEnd(_ id: AnnotationID, backward: Bool) {
        guard let item = state.selectedItem, item.id == id else { return }
        let t = backward ? timelineEngine.nudgeBackward(item.annotation.endTime)
                         : timelineEngine.nudgeForward(item.annotation.endTime)
        if t > item.annotation.startTime + Annotation.minimumDuration {
            state.updateAnnotationTime(id: id, endTime: t)
        }
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        let frac = Int((t.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", m, s, frac)
    }
}
