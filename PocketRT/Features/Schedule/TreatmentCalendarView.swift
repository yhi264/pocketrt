import SwiftUI

/// カレンダーの日の種別。色・記号・読み上げの3つに同じ判定を使う。
private enum DayKind {
    case treatment(fraction: Int)
    case manualRest      // 個別休止
    case holiday         // 祝日（照射しない設定のとき）
    case weekend
    case ordinary        // 治療期間内の非照射日
    case outsidePeriod
}

struct TreatmentCalendarView: View {
    let schedule: ScheduleResult
    let holidays: HolidayProvider
    let includeHolidays: Bool
    let overrideOff: Set<DateKey>
    let today: Date

    private let calendar = Calendar.jstGregorian
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    /// 表示月数は治療期間（開始日〜終了日）から導出する。1〜3ヶ月にクランプ。
    private var monthCount: Int {
        ScheduleCalculator.monthCount(from: schedule.startDate, to: schedule.endDate, calendar: calendar)
    }

    private var treatmentKeys: [DateKey: Int] {
        var map: [DateKey: Int] = [:]
        for (i, d) in schedule.treatmentDays.enumerated() {
            map[DateKey(from: d, calendar: calendar)] = i + 1
        }
        return map
    }

    private var grids: [MonthGrid] {
        ScheduleCalculator.monthGrids(
            from: schedule.startDate, monthCount: monthCount, calendar: calendar)
    }

    private var monthFormatter: DateFormatter {
        let f = DateFormatter()
        f.timeZone = calendar.timeZone
        f.setLocalizedDateFormatFromTemplate("yMMMM")
        return f
    }

    /// アクセシビリティラベル用の「8月3日」形式の日付フォーマッタ。
    /// グリッドの日付は JST で計算されるため、timeZone を明示しないと
    /// JST より西のデバイスで日付がずれて読み上げられる（過去に一度修正した不具合）。
    private var accessibilityDateFormatter: DateFormatter {
        let f = DateFormatter()
        f.timeZone = calendar.timeZone
        f.setLocalizedDateFormatFromTemplate("Md")
        return f
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            weekdayHeader

            ForEach(grids) { grid in
                VStack(alignment: .leading, spacing: 4) {
                    Text(monthFormatter.string(from: grid.firstDay))
                        .font(.subheadline.bold())
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(0..<grid.leadingBlanks, id: \.self) { _ in
                            Color.clear.frame(height: 34)
                        }
                        ForEach(1...grid.dayCount, id: \.self) { day in
                            if let date = calendar.date(byAdding: .day, value: day - 1, to: grid.firstDay) {
                                dayCell(date)
                            }
                        }
                    }
                }
            }

            legend

            if schedule.endDate > lastDisplayedDay {
                Text("治療期間は表示範囲（\(monthCount) ヶ月）を超えています。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var lastDisplayedDay: Date {
        guard let last = grids.last,
              let end = calendar.date(byAdding: .day, value: last.dayCount - 1, to: last.firstDay)
        else { return schedule.startDate }
        return end
    }

    private var weekdaySymbols: [String] {
        DateFormatter().shortWeekdaySymbols
    }

    private var weekdayHeader: some View {
        HStack(spacing: 2) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { i, symbol in
                Text(symbol)
                    .font(.caption2)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(i == 0 ? .red : (i == 6 ? .blue : .secondary))
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ date: Date) -> some View {
        let key = DateKey(from: date, calendar: calendar)
        let isToday = calendar.isDate(date, inSameDayAs: today)
        let inPeriod = date >= calendar.startOfDay(for: schedule.startDate)
            && date <= calendar.startOfDay(for: schedule.endDate)
        let kind = dayKind(date: date, key: key, inPeriod: inPeriod)

        VStack(spacing: 1) {
            Text("\(calendar.component(.day, from: date))")
                .font(.caption2)
            Text(marker(for: kind))
                .font(.caption2.bold())
        }
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(color(for: kind))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isToday ? Color.accentColor : .clear, lineWidth: 2)
        )
        .foregroundStyle(inPeriod ? .primary : .tertiary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(date: date, kind: kind))
    }

    /// 日の種別を1箇所で判定する。色・記号・読み上げの3つがこの結果を共有する。
    private func dayKind(date: Date, key: DateKey, inPeriod: Bool) -> DayKind {
        if let frNumber = treatmentKeys[key] { return .treatment(fraction: frNumber) }
        guard inPeriod else { return .outsidePeriod }
        if overrideOff.contains(key) { return .manualRest }
        if holidays.holidayName(date) != nil && !includeHolidays { return .holiday }
        let wd = calendar.component(.weekday, from: date)
        if wd == 1 || wd == 7 { return .weekend }
        return .ordinary
    }

    private func color(for kind: DayKind) -> Color {
        switch kind {
        case .treatment: return .green.opacity(0.25)
        case .holiday: return .red.opacity(0.15)
        case .manualRest: return .orange.opacity(0.15)
        case .weekend: return Color(.systemGray5)
        case .ordinary, .outsidePeriod: return .clear
        }
    }

    /// 分割回数がない日のうち、色だけでは区別できない種別に1文字の記号を添える。
    ///
    /// `LocalizedStringKey` を返すことで `Text(_:)` の非ローカライズ初期化子
    /// （`Text(some StringProtocol)`）に解決されるのを避け、「祝」「休」が
    /// String Catalog に載るようにする。
    private func marker(for kind: DayKind) -> LocalizedStringKey {
        switch kind {
        case .treatment(let fraction): return "\(fraction)"
        case .manualRest: return "休"
        case .holiday: return "祝"
        case .weekend, .ordinary, .outsidePeriod: return " "
        }
    }

    private func accessibilityLabel(date: Date, kind: DayKind) -> String {
        let dateText = accessibilityDateFormatter.string(from: date)
        switch kind {
        case .treatment(let fraction):
            return String(localized: "\(dateText) 第\(fraction)回")
        case .manualRest:
            return String(localized: "\(dateText) 個別休止")
        case .holiday:
            return String(localized: "\(dateText) 祝日")
        case .weekend:
            let wd = calendar.component(.weekday, from: date)
            return wd == 1
                ? String(localized: "\(dateText) 日曜")
                : String(localized: "\(dateText) 土曜")
        case .ordinary:
            return String(localized: "\(dateText) 照射なし")
        case .outsidePeriod:
            return String(localized: "\(dateText) 治療期間外")
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendItem(.green.opacity(0.25), "照射日")
            legendItem(Color(.systemGray5), "土日")
            legendItem(.red.opacity(0.15), "祝日")
            legendItem(.orange.opacity(0.15), "個別休止")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func legendItem(_ color: Color, _ label: LocalizedStringKey) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(label)
        }
    }
}
