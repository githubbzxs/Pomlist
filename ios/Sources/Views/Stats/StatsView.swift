import UniformTypeIdentifiers
import SwiftUI

struct StatsView: View {
    @ObservedObject var serviceHub: PLServiceHub

    @State private var snapshot: PLAnalyticsSnapshot?
    @State private var message: String?
    @State private var importing = false
    @State private var showPasscodeSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if let snapshot {
                        metrics(snapshot)
                        categorySection(snapshot)
                        hourlySection(snapshot)
                    } else {
                        PLPanelCard(title: "统计") {
                            Text("暂无统计数据")
                                .foregroundStyle(.secondary)
                        }
                    }

                    settingsSection
                }
                .padding(16)
            }
            .navigationTitle("统计")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("刷新") { reload() }
                }
            }
            .onAppear(perform: reload)
            .fileImporter(
                isPresented: $importing,
                allowedContentTypes: [UTType.json],
                allowsMultipleSelection: false
            ) { result in
                do {
                    guard let file = try result.get().first else { return }
                    try serviceHub.importMigration(from: file)
                    reload()
                    if let report = serviceHub.migrationReport {
                        message = "导入完成：新增任务 \(report.importedTodos)，更新任务 \(report.updatedTodos)，新增会话 \(report.importedSessions)。"
                    }
                } catch {
                    message = error.localizedDescription
                }
            }
            .sheet(isPresented: $showPasscodeSheet) {
                ChangePasscodeSheet(serviceHub: serviceHub) { error in
                    if let error {
                        message = error
                    } else {
                        message = "口令修改成功。"
                    }
                }
            }
            .alert("提示", isPresented: .constant(message != nil), presenting: message) { _ in
                Button("知道了") { message = nil }
            } message: { text in
                Text(text)
            }
        }
    }

    private func metrics(_ snapshot: PLAnalyticsSnapshot) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                PLMetricCard(title: "今日会话", value: "\(snapshot.todaySessions)")
                PLMetricCard(title: "今日用时", value: PLFormatters.minuteText(seconds: snapshot.todayDurationSeconds))
            }
            HStack(spacing: 10) {
                PLMetricCard(title: "连续天数", value: "\(snapshot.streakDays)")
                PLMetricCard(title: "30天平均完成率", value: PLFormatters.rateText(snapshot.avgCompletionRate))
            }
            HStack(spacing: 10) {
                PLMetricCard(title: "近7天会话", value: "\(snapshot.sessionsLast7Days)")
                PLMetricCard(title: "近30天会话", value: "\(snapshot.sessionsLast30Days)")
            }
        }
    }

    private func categorySection(_ snapshot: PLAnalyticsSnapshot) -> some View {
        PLPanelCard(title: "分类分布") {
            if snapshot.categoryDistribution.isEmpty {
                Text("暂无分类数据")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(snapshot.categoryDistribution) { point in
                        HStack {
                            Text(point.category)
                            Spacer()
                            Text("\(point.count)")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
    }

    private func hourlySection(_ snapshot: PLAnalyticsSnapshot) -> some View {
        PLPanelCard(title: "时间分布") {
            let nonEmpty = snapshot.hourlyDistribution.filter { $0.count > 0 }
            if nonEmpty.isEmpty {
                Text("暂无时段数据")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(nonEmpty) { point in
                        HStack {
                            Text(String(format: "%02d:00", point.hour))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            GeometryReader { proxy in
                                let width = max(4, CGFloat(point.count) * 10)
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.blue.opacity(0.65))
                                    .frame(width: min(width, proxy.size.width), height: 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: point.count)
                            }
                            .frame(height: 8)
                            Text("\(point.count)")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
    }

    private var settingsSection: some View {
        PLPanelCard(title: "设置") {
            VStack(alignment: .leading, spacing: 10) {
                Button("导入迁移包（PomlistMigrationV1）") {
                    importing = true
                }
                .buttonStyle(.bordered)

                Button("修改口令") {
                    showPasscodeSheet = true
                }
                .buttonStyle(.bordered)

                Button("锁定应用") {
                    serviceHub.lock()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func reload() {
        do {
            snapshot = try serviceHub.analyticsService?.snapshot()
        } catch {
            message = error.localizedDescription
        }
    }
}

private struct ChangePasscodeSheet: View {
    @ObservedObject var serviceHub: PLServiceHub
    let onFinish: (String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var oldPasscode = ""
    @State private var newPasscode = ""

    var body: some View {
        NavigationStack {
            Form {
                SecureField("旧口令", text: $oldPasscode)
                    .keyboardType(.asciiCapable)
                SecureField("新口令（4位）", text: $newPasscode)
                    .keyboardType(.asciiCapable)
            }
            .navigationTitle("修改口令")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        do {
                            try serviceHub.changePasscode(oldPasscode: oldPasscode, newPasscode: newPasscode)
                            onFinish(nil)
                            dismiss()
                        } catch {
                            onFinish(error.localizedDescription)
                        }
                    }
                    .disabled(oldPasscode.count != 4 || newPasscode.count != 4)
                }
            }
        }
    }
}
