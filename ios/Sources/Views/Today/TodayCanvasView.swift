import SwiftUI

struct TodayCanvasView: View {
    @ObservedObject var serviceHub: PLServiceHub

    @StateObject private var viewModel: TodayCanvasViewModel
    @State private var activePanel: PLTodayPanel = .center
    @State private var dragOffset: CGSize = .zero
    @State private var didLoad = false

    @State private var showingTaskDrawer = false
    @State private var showingTagManager = false

    @State private var taskEditorTodoID: String?
    @State private var taskEditorTitle = ""
    @State private var taskEditorPrimaryTag = ""
    @State private var taskEditorSecondaryTag = ""
    @State private var taskEditorContent = ""
    @State private var taskEditorNotice: String?

    @State private var createTitle = ""
    @State private var createPrimaryTag = ""
    @State private var createSecondaryTag = ""
    @State private var createContent = ""

    @State private var tagNotice: String?
    @State private var newTagName = ""
    @State private var newTagColor = TodayCanvasViewModel.defaultTagColor
    @State private var editingTag: String?
    @State private var editingTagName = ""

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let commonTagColors = [
        "#1d4ed8",
        "#2563eb",
        "#3b82f6",
        "#0284c7",
        "#059669",
        "#d97706",
        "#dc2626",
        "#7c3aed",
    ]

    init(serviceHub: PLServiceHub) {
        self.serviceHub = serviceHub
        _viewModel = StateObject(wrappedValue: TodayCanvasViewModel(serviceHub: serviceHub))
    }

    var body: some View {
        ZStack {
            backgroundLayer
            contentLayer
            if let error = viewModel.errorMessage {
                errorToast(error)
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showingTaskDrawer) {
            taskDrawerSheet
        }
        .sheet(isPresented: $showingTagManager) {
            tagManagerSheet
        }
        .sheet(isPresented: taskEditorPresentedBinding) {
            taskEditorSheet
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            viewModel.loadInitialData()
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.9), value: activePanel)
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.03, blue: 0.05),
                Color(red: 0.04, green: 0.06, blue: 0.1),
                Color(red: 0.03, green: 0.04, blue: 0.08),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Circle()
                .fill(Color.blue.opacity(0.14))
                .blur(radius: 90)
                .frame(width: 260, height: 260)
                .offset(x: -110, y: -260)
        }
        .overlay {
            Circle()
                .fill(Color.cyan.opacity(0.1))
                .blur(radius: 110)
                .frame(width: 320, height: 320)
                .offset(x: 150, y: 340)
        }
    }

    private var contentLayer: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                canvasStack(size: size)
                if horizontalSizeClass == .regular {
                    edgeLayer
                }
            }
            .padding(.horizontal, horizontalPadding(for: size.width))
            .padding(.vertical, 16)
        }
    }

    private func horizontalPadding(for width: CGFloat) -> CGFloat {
        if width > 700 {
            return max((width - 430) * 0.5, 12)
        }
        return 12
    }

    private func canvasStack(size: CGSize) -> some View {
        ZStack {
            panelContainer(centerPanel)
                .offset(x: 0, y: 0)
            panelContainer(taskPanel)
                .offset(x: size.width, y: 0)
            panelContainer(statisticPanel)
                .offset(x: 0, y: size.height)
            panelContainer(historyPanel)
                .offset(x: 0, y: -size.height)
        }
        .frame(width: size.width, height: size.height)
        .offset(x: baseOffset(for: activePanel, size: size).width + dragOffset.width)
        .offset(y: baseOffset(for: activePanel, size: size).height + dragOffset.height)
        .gesture(dragGesture(size: size))
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: activePanel)
    }

    private func panelContainer<Content: View>(_ content: Content) -> some View {
        VStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(6)
        .plLiquidGlassCard(cornerRadius: 30, borderOpacity: 0.3, highlightOpacity: 0.2, shadowOpacity: 0.34)
        .clipped()
    }

    private func baseOffset(for panel: PLTodayPanel, size: CGSize) -> CGSize {
        switch panel {
        case .center:
            return .zero
        case .right:
            return CGSize(width: -size.width, height: 0)
        case .down:
            return CGSize(width: 0, height: -size.height)
        case .up:
            return CGSize(width: 0, height: size.height)
        }
    }

    private func resolvePanel(current: PLTodayPanel, translation: CGSize) -> PLTodayPanel {
        let threshold: CGFloat = 56
        let absX = abs(translation.width)
        let absY = abs(translation.height)

        if absX >= threshold && absX > absY * 1.2 {
            if current == .center && translation.width < 0 {
                return .right
            }
            if current == .right && translation.width > 0 {
                return .center
            }
            return current
        }

        if absY >= threshold && absY > absX * 1.2 {
            if current == .center {
                if translation.height > 0 {
                    return .down
                }
                return .up
            }
            if current == .down && translation.height < 0 {
                return .center
            }
            if current == .up && translation.height > 0 {
                return .center
            }
        }

        return current
    }

    private func dragGesture(size _: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                let next = resolvePanel(current: activePanel, translation: value.translation)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    activePanel = next
                    dragOffset = .zero
                }
            }
    }

    private var edgeLayer: some View {
        ZStack {
            switch activePanel {
            case .center:
                edgeButton(position: .trailing, action: { activePanel = .right }, label: "去任务")
                edgeButton(position: .bottom, action: { activePanel = .down }, label: "去统计")
                edgeButton(position: .top, action: { activePanel = .up }, label: "去历史")
            case .right:
                edgeButton(position: .leading, action: { activePanel = .center }, label: "回主页")
            case .down:
                edgeButton(position: .top, action: { activePanel = .center }, label: "回主页")
            case .up:
                edgeButton(position: .bottom, action: { activePanel = .center }, label: "回主页")
            }
        }
    }

    private enum EdgePosition {
        case leading
        case trailing
        case top
        case bottom
    }

    private func edgeButton(position: EdgePosition, action: @escaping () -> Void, label: String) -> some View {
        Button(action: action) {
            Color.clear
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .frame(width: position == .leading || position == .trailing ? 52 : 220)
        .frame(height: position == .top || position == .bottom ? 52 : 240)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment(for: position))
        .padding(edgePadding(for: position))
    }

    private func alignment(for position: EdgePosition) -> Alignment {
        switch position {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        case .top:
            return .top
        case .bottom:
            return .bottom
        }
    }

    private func edgePadding(for position: EdgePosition) -> EdgeInsets {
        switch position {
        case .leading:
            return EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0)
        case .trailing:
            return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 4)
        case .top:
            return EdgeInsets(top: 4, leading: 0, bottom: 0, trailing: 0)
        case .bottom:
            return EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0)
        }
    }

    private var centerPanel: some View {
        VStack(spacing: 10) {
            panelHeader(title: "Pomlist")

            VStack(spacing: 14) {
                timerSection
                Divider().background(Color.white.opacity(0.18))
                taskSection
            }
            .padding(16)
            .plLiquidGlassCard(cornerRadius: 24, borderOpacity: 0.26, highlightOpacity: 0.16, shadowOpacity: 0.2)

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red.opacity(0.92))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var timerSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("进度")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.completedCount)/\(viewModel.totalCount)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(timerText)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            progressBar(
                progress: progressValue(
                    completed: viewModel.completedCount,
                    total: viewModel.totalCount
                )
            )

            if viewModel.activeSession == nil, let ended = viewModel.lastEndedSeconds {
                Text("上次结束用时 \(formatDuration(seconds: ended))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var taskSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("任务")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
            }

            if viewModel.centerTasks.isEmpty {
                Text("当前没有任务，先添加再开始。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(viewModel.centerTasks, id: \.id) { task in
                            Button {
                                viewModel.toggleCenterTask(taskID: task.id, completed: !task.completed)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(task.completed ? Color.green : Color.secondary)
                                    Text(task.title)
                                        .font(.subheadline)
                                        .foregroundStyle(task.completed ? Color.secondary : Color.white)
                                        .strikethrough(task.completed, color: .secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            .plLiquidGlassCard(cornerRadius: 14, borderOpacity: 0.2, highlightOpacity: 0.12, shadowOpacity: 0.14)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }

            HStack(spacing: 10) {
                Button("添加任务") {
                    showingTaskDrawer = true
                }
                .buttonStyle(PLSecondaryGlassButtonStyle())
                .frame(width: 120)

                if viewModel.activeSession != nil {
                    Button(viewModel.isEndingSession ? "正在结束..." : "结束并记录") {
                        viewModel.endSession()
                        activePanel = .center
                    }
                    .buttonStyle(PLPrimaryGlassButtonStyle())
                    .disabled(viewModel.isEndingSession)
                } else {
                    Button(viewModel.isStartingSession ? "正在开始..." : "开始专注（\(viewModel.plannedTodoIDs.count)）") {
                        viewModel.startSession()
                        activePanel = .center
                    }
                    .buttonStyle(PLPrimaryGlassButtonStyle())
                    .disabled(!viewModel.canStartSession)
                }
            }
        }
    }

    private var taskPanel: some View {
        VStack(spacing: 10) {
            panelHeader(title: "Task") {
                HStack(spacing: 8) {
                    Button("管理") {
                        showingTagManager = true
                        tagNotice = nil
                    }
                    .buttonStyle(PLSecondaryGlassButtonStyle())
                    .frame(width: 86)

                    Button("新建") {
                        showingTaskDrawer = true
                    }
                    .buttonStyle(PLPrimaryGlassButtonStyle())
                    .frame(width: 86)
                }
            }

            HStack {
                Text("可见任务 \(viewModel.libraryTodos.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.activeSession == nil ? "计划中" : "会话中") \(viewModel.plannedTodoIDs.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(viewModel.libraryTodos, id: \.id) { todo in
                        taskLibraryRow(todo)
                    }
                }
                .padding(.bottom, 12)
            }
        }
    }

    private func taskLibraryRow(_ todo: PLTodo) -> some View {
        let selected = viewModel.plannedTodoIDs.contains(todo.id)
        let tags = Array(todo.tags.prefix(2))

        return HStack(spacing: 10) {
            Button {
                openTaskEditor(todo)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(todo.title)
                        .font(.subheadline)
                        .foregroundStyle(todo.status == "completed" ? Color.secondary : Color.white)
                        .strikethrough(todo.status == "completed", color: .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        if let primary = tags.first {
                            tagPill(primary, color: Color(hex: viewModel.tagColorHex(for: primary)))
                        } else {
                            Text("未标签")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        if tags.count > 1 {
                            tagPill(tags[1], color: .cyan)
                        }
                    }

                    if !todo.notes.isEmpty {
                        Text(todo.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .buttonStyle(.plain)

            if selected {
                Button(selectionButtonText(todo: todo, selected: selected)) {
                    viewModel.togglePlan(todoID: todo.id)
                }
                .buttonStyle(PLPrimaryGlassButtonStyle())
                .frame(width: 82)
                .disabled(todo.status != "pending" || (viewModel.activeSession != nil && selected))
            } else {
                Button(selectionButtonText(todo: todo, selected: selected)) {
                    viewModel.togglePlan(todoID: todo.id)
                }
                .buttonStyle(PLSecondaryGlassButtonStyle())
                .frame(width: 82)
                .disabled(todo.status != "pending" || (viewModel.activeSession != nil && selected))
            }
        }
        .padding(12)
        .plLiquidGlassCard(cornerRadius: 16, borderOpacity: 0.2, highlightOpacity: 0.12, shadowOpacity: 0.16)
    }

    private func selectionButtonText(todo: PLTodo, selected: Bool) -> String {
        if todo.status != "pending" {
            return "已完成"
        }
        if viewModel.activeSession != nil {
            return selected ? "会话中" : "加入"
        }
        return selected ? "移出" : "加入"
    }

    private var historyPanel: some View {
        VStack(spacing: 10) {
            panelHeader(title: "History") {
                Button("刷新") {
                    viewModel.refresh()
                }
                .buttonStyle(PLSecondaryGlassButtonStyle())
                .frame(width: 86)
            }

            if viewModel.historySessions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("暂无历史记录")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 6)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(viewModel.historySessions, id: \.id) { session in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(PLFormatters.shortDateTime(session.endedAt))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text("\(session.completedTaskCount)/\(session.totalTaskCount)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }

                                Text("用时 \(formatDuration(seconds: session.elapsedSeconds)) · 完成率 \(PLFormatters.rateText(session.completionRate))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if !session.taskRefs.isEmpty {
                                    Text(session.taskRefs.sorted(by: { $0.orderIndex < $1.orderIndex }).map(\.titleSnapshot).joined(separator: " · "))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .plLiquidGlassCard(cornerRadius: 16, borderOpacity: 0.2, highlightOpacity: 0.12, shadowOpacity: 0.16)
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
        }
    }

    private var statisticPanel: some View {
        let snapshot = viewModel.analyticsSnapshot
        let maxCategory = max(1, snapshot.categoryDistribution.map(\.count).max() ?? 1)
        let maxHour = max(1, snapshot.hourlyDistribution.map(\.count).max() ?? 1)

        return VStack(spacing: 10) {
            panelHeader(title: "Statistic") {
                Button("刷新") {
                    viewModel.refresh()
                }
                .buttonStyle(PLSecondaryGlassButtonStyle())
                .frame(width: 86)
            }

            ScrollView {
                VStack(spacing: 10) {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8),
                        ],
                        spacing: 8
                    ) {
                        metricCard("今日任务钟", "\(snapshot.todaySessions)")
                        metricCard("今日时长", formatDuration(seconds: snapshot.todayDurationSeconds))
                        metricCard("连续天数", "\(snapshot.streakDays)")
                        metricCard("30天完成率", PLFormatters.rateText(snapshot.avgCompletionRate))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("周期视角")
                            .font(.headline)
                            .foregroundStyle(.white)
                        HStack(spacing: 8) {
                            periodCard("近7天", sessions: snapshot.sessionsLast7Days)
                            periodCard("近30天", sessions: snapshot.sessionsLast30Days)
                        }
                    }
                    .padding(12)
                    .plLiquidGlassCard(cornerRadius: 18, borderOpacity: 0.2, highlightOpacity: 0.1, shadowOpacity: 0.14)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("标签贡献")
                            .font(.headline)
                            .foregroundStyle(.white)
                        if snapshot.categoryDistribution.isEmpty {
                            Text("暂无分类数据")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(snapshot.categoryDistribution) { point in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(point.category)
                                            .font(.caption)
                                            .foregroundStyle(.white)
                                        Spacer()
                                        Text("\(point.count)")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                    progressBar(progress: max(0.04, CGFloat(point.count) / CGFloat(maxCategory)))
                                }
                            }
                        }
                    }
                    .padding(12)
                    .plLiquidGlassCard(cornerRadius: 18, borderOpacity: 0.2, highlightOpacity: 0.1, shadowOpacity: 0.14)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("时间分布")
                            .font(.headline)
                            .foregroundStyle(.white)
                        ForEach(snapshot.hourlyDistribution.filter { $0.count > 0 }) { point in
                            HStack(spacing: 8) {
                                Text(String(format: "%02d:00", point.hour))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 42, alignment: .leading)

                                progressBar(progress: max(0.04, CGFloat(point.count) / CGFloat(maxHour)))

                                Text("\(point.count)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24, alignment: .trailing)
                            }
                        }
                    }
                    .padding(12)
                    .plLiquidGlassCard(cornerRadius: 18, borderOpacity: 0.2, highlightOpacity: 0.1, shadowOpacity: 0.14)
                }
                .padding(.bottom, 12)
            }
        }
    }

    private var taskDrawerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 8) {
                        TextField("任务标题", text: $createTitle)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .frame(height: 44)
                            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        HStack(spacing: 8) {
                            TextField("一级标签", text: $createPrimaryTag)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 12)
                                .frame(height: 42)
                                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                            TextField("二级标签", text: $createSecondaryTag)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 12)
                                .frame(height: 42)
                                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        TextField("具体内容", text: $createContent, axis: .vertical)
                            .lineLimit(4 ... 8)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Button(viewModel.isCreatingTask ? "创建中..." : "创建并加入") {
                            viewModel.createTask(
                                title: createTitle,
                                primaryTag: createPrimaryTag,
                                secondaryTag: createSecondaryTag,
                                content: createContent
                            )
                            createTitle = ""
                            createPrimaryTag = ""
                            createSecondaryTag = ""
                            createContent = ""
                        }
                        .buttonStyle(PLPrimaryGlassButtonStyle())
                        .disabled(viewModel.isCreatingTask)
                    }
                    .padding(14)
                    .plLiquidGlassCard(cornerRadius: 18, borderOpacity: 0.2, highlightOpacity: 0.12, shadowOpacity: 0.14)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("待办任务")
                            .font(.headline)
                            .foregroundStyle(.white)

                        if viewModel.pendingTodos.isEmpty {
                            Text("暂无待办任务")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.pendingTodos, id: \.id) { todo in
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(todo.title)
                                            .font(.subheadline)
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        if !todo.tags.isEmpty {
                                            HStack(spacing: 6) {
                                                ForEach(Array(todo.tags.prefix(2)), id: \.self) { tag in
                                                    tagPill(tag, color: Color(hex: viewModel.tagColorHex(for: tag)))
                                                }
                                            }
                                        }
                                    }

                                    if viewModel.plannedTodoIDs.contains(todo.id) {
                                        Button("移出") {
                                            viewModel.togglePlan(todoID: todo.id)
                                        }
                                        .buttonStyle(PLPrimaryGlassButtonStyle())
                                        .frame(width: 82)
                                        .disabled(viewModel.activeSession != nil)
                                    } else {
                                        Button("加入") {
                                            viewModel.togglePlan(todoID: todo.id)
                                        }
                                        .buttonStyle(PLSecondaryGlassButtonStyle())
                                        .frame(width: 82)
                                        .disabled(false)
                                    }
                                }
                                .padding(10)
                                .plLiquidGlassCard(cornerRadius: 14, borderOpacity: 0.2, highlightOpacity: 0.1, shadowOpacity: 0.12)
                            }
                        }
                    }
                    .padding(14)
                    .plLiquidGlassCard(cornerRadius: 18, borderOpacity: 0.2, highlightOpacity: 0.12, shadowOpacity: 0.14)
                }
                .padding(12)
            }
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.96), Color.blue.opacity(0.26)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        showingTaskDrawer = false
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var tagManagerSheet: some View {
        NavigationStack {
            VStack(spacing: 12) {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("新标签", text: $newTagName)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .frame(height: 42)
                            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Button("新增") {
                            tagNotice = viewModel.addTag(name: newTagName, colorHex: newTagColor)
                            newTagName = ""
                        }
                        .buttonStyle(PLPrimaryGlassButtonStyle())
                        .frame(width: 80)
                    }

                    HStack(spacing: 8) {
                        ForEach(commonTagColors, id: \.self) { hex in
                            Button {
                                newTagColor = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 22, height: 22)
                                    .overlay {
                                        if newTagColor == hex {
                                            Circle()
                                                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                                                .frame(width: 26, height: 26)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(14)
                .plLiquidGlassCard(cornerRadius: 18, borderOpacity: 0.2, highlightOpacity: 0.12, shadowOpacity: 0.14)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(viewModel.tagOptions, id: \.self) { tag in
                            tagManagerRow(tag)
                        }
                    }
                    .padding(.bottom, 12)
                }

                if let tagNotice {
                    Text(tagNotice)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.96), Color.blue.opacity(0.24)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("管理标签")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        showingTagManager = false
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func tagManagerRow(_ tag: String) -> some View {
        VStack(spacing: 8) {
            if editingTag == tag {
                HStack(spacing: 8) {
                    TextField("标签名", text: $editingTagName)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Button("保存") {
                        tagNotice = viewModel.renameTag(source: tag, target: editingTagName)
                        editingTag = nil
                        editingTagName = ""
                    }
                    .buttonStyle(PLPrimaryGlassButtonStyle())
                    .frame(width: 68)

                    Button("取消") {
                        editingTag = nil
                        editingTagName = ""
                    }
                    .buttonStyle(PLSecondaryGlassButtonStyle())
                    .frame(width: 68)
                }
            } else {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: viewModel.tagColorHex(for: tag)))
                            .frame(width: 10, height: 10)
                        Text(tag)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        ForEach(commonTagColors, id: \.self) { color in
                            Button {
                                viewModel.updateTagColor(tag: tag, hex: color)
                            } label: {
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: 16, height: 16)
                                    .overlay {
                                        if viewModel.tagColorHex(for: tag) == color {
                                            Circle()
                                                .stroke(Color.white.opacity(0.88), lineWidth: 1.4)
                                                .frame(width: 20, height: 20)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button("改名") {
                        editingTag = tag
                        editingTagName = tag
                        tagNotice = nil
                    }
                    .buttonStyle(PLSecondaryGlassButtonStyle())
                    .frame(width: 66)

                    Button("删") {
                        tagNotice = viewModel.deleteTag(name: tag)
                    }
                    .buttonStyle(PLDangerGlassButtonStyle())
                    .frame(width: 56)
                }
            }
        }
        .padding(10)
        .plLiquidGlassCard(cornerRadius: 14, borderOpacity: 0.2, highlightOpacity: 0.1, shadowOpacity: 0.12)
    }

    private var taskEditorSheet: some View {
        NavigationStack {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(taskEditorTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("一级标签", text: $taskEditorPrimaryTag)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .frame(height: 42)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    TextField("二级标签", text: $taskEditorSecondaryTag)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .frame(height: 42)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    TextField("具体内容", text: $taskEditorContent, axis: .vertical)
                        .lineLimit(4 ... 8)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if !viewModel.tagOptions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(viewModel.tagOptions.prefix(12), id: \.self) { item in
                                    Button(item) {
                                        if taskEditorPrimaryTag.isEmpty {
                                            taskEditorPrimaryTag = item
                                        } else {
                                            taskEditorSecondaryTag = item
                                        }
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.12), in: Capsule())
                                }
                            }
                        }
                    }
                }
                .padding(14)
                .plLiquidGlassCard(cornerRadius: 18, borderOpacity: 0.2, highlightOpacity: 0.12, shadowOpacity: 0.14)

                HStack(spacing: 10) {
                    Button(viewModel.isDeletingTask ? "删除中..." : "删除任务") {
                        guard let id = taskEditorTodoID else { return }
                        viewModel.deleteTask(todoID: id)
                        taskEditorTodoID = nil
                    }
                    .buttonStyle(PLDangerGlassButtonStyle())
                    .disabled(viewModel.isDeletingTask || viewModel.isSavingTaskEditor)

                    Button(viewModel.isSavingTaskEditor ? "保存中..." : "保存修改") {
                        guard let id = taskEditorTodoID else { return }
                        viewModel.saveTaskEditor(
                            todoID: id,
                            primaryTag: taskEditorPrimaryTag,
                            secondaryTag: taskEditorSecondaryTag,
                            content: taskEditorContent
                        )
                        taskEditorNotice = "已保存任务信息。"
                    }
                    .buttonStyle(PLPrimaryGlassButtonStyle())
                    .disabled(viewModel.isSavingTaskEditor || viewModel.isDeletingTask)
                }

                if let taskEditorNotice {
                    Text(taskEditorNotice)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.96), Color.blue.opacity(0.24)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("编辑任务")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        taskEditorTodoID = nil
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func openTaskEditor(_ todo: PLTodo) {
        let tags = Array(todo.tags.prefix(2))
        taskEditorTodoID = todo.id
        taskEditorTitle = todo.title
        taskEditorPrimaryTag = tags.first ?? ""
        taskEditorSecondaryTag = tags.count > 1 ? tags[1] : ""
        taskEditorContent = todo.notes
        taskEditorNotice = nil
    }

    private var taskEditorPresentedBinding: Binding<Bool> {
        Binding(
            get: { taskEditorTodoID != nil },
            set: { presented in
                if !presented {
                    taskEditorTodoID = nil
                }
            }
        )
    }

    private var timerText: String {
        if viewModel.activeSession != nil {
            return PLFormatters.durationText(seconds: viewModel.displaySeconds)
        }
        return "--:--"
    }

    private func progressBar(progress: CGFloat) -> some View {
        GeometryReader { proxy in
            let width = max(0, min(1, progress)) * proxy.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.14))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.9), Color.cyan.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(6, width))
            }
        }
        .frame(height: 8)
    }

    private func tagPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2), in: Capsule())
            .overlay {
                Capsule().stroke(color.opacity(0.5), lineWidth: 1)
            }
    }

    private func panelHeader<Actions: View>(title: String, @ViewBuilder actions: () -> Actions) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            actions()
        }
        .padding(.horizontal, 4)
    }

    private func panelHeader(title: String) -> some View {
        panelHeader(title: title) {
            Button(viewModel.isRefreshing ? "刷新中..." : "刷新") {
                viewModel.refresh()
            }
            .buttonStyle(PLSecondaryGlassButtonStyle())
            .frame(width: 86)
            .disabled(viewModel.isRefreshing)
        }
    }

    private func metricCard(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .plLiquidGlassCard(cornerRadius: 16, borderOpacity: 0.2, highlightOpacity: 0.1, shadowOpacity: 0.12)
    }

    private func periodCard(_ title: String, sessions: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("任务钟 \(sessions)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .plLiquidGlassCard(cornerRadius: 14, borderOpacity: 0.2, highlightOpacity: 0.1, shadowOpacity: 0.1)
    }

    private func errorToast(_ message: String) -> some View {
        VStack {
            Spacer()
            Button {
                viewModel.clearError()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(message)
                        .lineLimit(2)
                }
                .font(.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private func progressValue(completed: Int, total: Int) -> CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(completed) / CGFloat(total)
    }

    private func formatDuration(seconds: Int) -> String {
        let minute = max(0, Int(round(Double(seconds) / 60)))
        if minute < 60 {
            return "\(minute) 分钟"
        }
        let hour = minute / 60
        let remain = minute % 60
        return "\(hour) 小时 \(remain) 分钟"
    }
}

private extension Color {
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else {
            self = .blue
            return
        }
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self = Color(red: red, green: green, blue: blue)
    }
}
