import SwiftUI

struct ScheduleView: View {
    @State private var vm = ScheduleViewModel()
    @State private var showPresetSheet = false
    @Environment(PresetStoreModel.self) private var presetStore
    @State private var showOverrideOnPicker = false
    @State private var showOverrideOffPicker = false
    @State private var newOverrideOnDate: Date = Date()
    @State private var newOverrideOffDate: Date = Date()

    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("Md E")
        return f
    }()
    private let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("yMMMd E")
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // --- 線量分割 ---
                    Group {
                        Button {
                            showPresetSheet = true
                        } label: {
                            Label("プリセットから選ぶ", systemImage: "list.clipboard")
                        }
                        .buttonStyle(.bordered)

                        NumberField(label: "総線量", unit: "Gy", value: $vm.totalDoseText, error: vm.totalDoseError)
                        NumberField(label: "分割数", unit: "Fr", value: $vm.fractionsText, error: vm.fractionsError)
                        if let d = vm.dosePerFraction {
                            HStack {
                                Text("1回線量").frame(width: 80, alignment: .leading)
                                Spacer()
                                Text(String(format: "%.2f Gy", d))
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Divider()

                    // --- スケジュール条件 ---
                    Group {
                        Text("スケジュール条件").font(.headline)
                        DatePicker("開始日", selection: $vm.startDate, displayedComponents: .date)
                        Toggle("土日も照射", isOn: $vm.includeWeekends)
                        Toggle("祝日も照射", isOn: $vm.includeHolidays)
                    }

                    Divider()

                    // --- 個別指定 ---
                    overrideSection(
                        title: "強制照射日",
                        keys: Array(vm.overrideOn).sorted(),
                        showPicker: $showOverrideOnPicker,
                        pickerDate: $newOverrideOnDate,
                        onAdd: { vm.addOverrideOn($0) },
                        onRemove: { vm.removeOverrideOn($0) }
                    )
                    overrideSection(
                        title: "強制休止日",
                        keys: Array(vm.overrideOff).sorted(),
                        showPicker: $showOverrideOffPicker,
                        pickerDate: $newOverrideOffDate,
                        onAdd: { vm.addOverrideOff($0) },
                        onRemove: { vm.removeOverrideOff($0) }
                    )

                    // --- 結果 ---
                    if let warning = vm.holidayDataWarning {
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    ResultCard(title: "予測", isDisabled: !vm.isValid) {
                        if let s = vm.schedule {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("開始日")
                                    Spacer()
                                    Text(fullDateFormatter.string(from: s.startDate))
                                        .font(.body.monospacedDigit())
                                }
                                HStack {
                                    Text("終了予定日")
                                    Spacer()
                                    Text(fullDateFormatter.string(from: s.endDate))
                                        .font(.body.monospacedDigit())
                                        .bold()
                                }
                                HStack {
                                    Text("治療期間")
                                    Spacer()
                                    Text("\(s.totalCalendarDays) 日（照射 \(s.treatmentDays.count) + 休止 \(s.restDays)）")
                                        .font(.body.monospacedDigit())
                                }
                                if !vm.activeCitations.isEmpty {
                                    Divider()
                                    HStack(spacing: 4) {
                                        Image(systemName: "text.book.closed")
                                            .font(.caption2)
                                        Text("線量分割の出典: \(vm.activeCitations.map { String(localized: $0.shortLabel) }.joined(separator: " / "))")
                                            .font(.caption2)
                                    }
                                    .foregroundStyle(.secondary)
                                }
                                if let name = vm.activeInstitutionalName {
                                    Text("自施設のプロトコル: \(name)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        } else {
                            Text("入力を確認してください").font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    ResultCard(title: "今日の進捗", isDisabled: !vm.isValid) {
                        if vm.isValid, let n = vm.fractions, let total = vm.totalDose {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("照射済")
                                    Spacer()
                                    Text("\(vm.todayCompletedFractions) Fr / \(n) Fr")
                                        .font(.body.monospacedDigit())
                                        .bold()
                                }
                                if let dose = vm.todayCompletedDose {
                                    HStack {
                                        Text("累積線量")
                                        Spacer()
                                        Text(String(format: "%.2f Gy / %.2f Gy", dose, total))
                                            .font(.body.monospacedDigit())
                                    }
                                }
                                if let p = vm.progressFraction {
                                    ProgressView(value: p)
                                    HStack {
                                        Spacer()
                                        Text(String(format: "%.1f %%", p * 100))
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    if let s = vm.schedule {
                        ResultCard(title: "カレンダー") {
                            TreatmentCalendarView(
                                schedule: s,
                                holidays: vm.holidays,
                                includeHolidays: vm.includeHolidays,
                                overrideOff: vm.overrideOff,
                                today: Date())
                        }
                    }

                    // --- 直近のスケジュール ---
                    if !vm.upcomingEntries().isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("直近 14 日").font(.headline)
                            ForEach(vm.upcomingEntries()) { entry in
                                HStack {
                                    Text(dayFormatter.string(from: entry.date))
                                        .font(.callout.monospacedDigit())
                                        .frame(width: 100, alignment: .leading)
                                    Spacer()
                                    if entry.isTreatment, let fn = entry.fractionNumber {
                                        Image(systemName: "circle.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.blue)
                                        Text("\(fn) Fr")
                                            .font(.callout.monospacedDigit())
                                    } else {
                                        Text(entry.restReason ?? String(localized: "休"))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                    }
                }
                .padding()
            }
            .navigationTitle("スケジュール")
            .dismissibleKeyboard()
            .sheet(isPresented: $showPresetSheet) {
                PresetSheet(onSelect: { selection in
                    vm.apply(selection)
                }, model: presetStore)
            }
            .infoToolbarButton()
        }
    }

    @ViewBuilder
    private func overrideSection(
        title: LocalizedStringKey,
        keys: [DateKey],
        showPicker: Binding<Bool>,
        pickerDate: Binding<Date>,
        onAdd: @escaping (Date) -> Void,
        onRemove: @escaping (DateKey) -> Void
    ) -> some View {
        // LocalizedStringKey を文字列補間に入れてはならない。専用の
        // appendInterpolation オーバーロードが無いため汎用版に解決され、
        // String(describing:) の結果——LocalizedStringKey(key: "強制照射日",
        // hasFormatting: false, arguments: []) という内部表現——がそのまま
        // 画面に出る。title が String だった頃はこれで正しく動いていたが、
        // ローカライズ対応で LocalizedStringKey に変えたときに壊れた。
        // Text を連結して、それぞれを独立したローカライズ単位として扱う。
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(keys, id: \.self) { key in
                    HStack {
                        Text(fullDateFormatter.string(from: key.date()))
                            .font(.callout.monospacedDigit())
                        Spacer()
                        Button(role: .destructive) {
                            onRemove(key)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                    }
                }
                Button {
                    showPicker.wrappedValue = true
                } label: {
                    Label("追加", systemImage: "plus.circle")
                }
            }
            .padding(.top, 4)
        } label: {
            Text(title) + Text(" (\(keys.count))")
        }
        .sheet(isPresented: showPicker) {
            NavigationStack {
                DatePicker("日付を選択", selection: pickerDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("追加") {
                                onAdd(pickerDate.wrappedValue)
                                showPicker.wrappedValue = false
                            }
                        }
                        ToolbarItem(placement: .topBarLeading) {
                            Button("キャンセル") {
                                showPicker.wrappedValue = false
                            }
                        }
                    }
            }
        }
    }
}
