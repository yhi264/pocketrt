import Foundation

@Observable
final class CourseInput: Identifiable {
    let id = UUID()
    var totalDoseText: String
    var fractionsText: String
    var alphaBetaText: String

    init(totalDose: Double = 60, fractions: Int = 30, alphaBeta: Double = 10) {
        self.totalDoseText = DoseFormat.doseString(totalDose)
        self.fractionsText = "\(fractions)"
        self.alphaBetaText = DoseFormat.alphaBetaString(alphaBeta)
    }

    var totalDose: Double? { Double(totalDoseText) }
    var fractions: Int? { Int(fractionsText) }
    var alphaBeta: Double? { Double(alphaBetaText) }

    var isValid: Bool {
        guard let D = totalDose, let n = fractions, let ab = alphaBeta else { return false }
        return (0.1...200).contains(D) && (1...99).contains(n) && (0.5...30).contains(ab)
    }

    var asCourse: Course? {
        guard let D = totalDose, let n = fractions, let ab = alphaBeta, isValid else { return nil }
        return Course(id: id, totalDose: D, fractions: n, alphaBeta: ab)
    }

    var bed: Double? {
        guard let c = asCourse else { return nil }
        return LQCore.bed(totalDose: c.totalDose, fractions: c.fractions, alphaBeta: c.alphaBeta)
    }
    var eqd2: Double? {
        guard let b = bed, let ab = alphaBeta else { return nil }
        return LQCore.eqd2(bed: b, alphaBeta: ab)
    }
}

@Observable
final class MultiCourseViewModel {
    var courses: [CourseInput] = [
        CourseInput(),
        CourseInput(totalDose: 30, fractions: 10, alphaBeta: 10)
    ]
    let maxCourses = 3

    var validCourses: [Course] { courses.compactMap(\.asCourse) }
    var canAdd: Bool { courses.count < maxCourses }

    var cumulativeBED: Double? {
        guard !validCourses.isEmpty else { return nil }
        return LQCore.cumulativeBED(courses: validCourses)
    }
    var cumulativeEQD2: Double? {
        guard !validCourses.isEmpty else { return nil }
        return LQCore.cumulativeEQD2(courses: validCourses)
    }

    /// 全コースが同じ α/β なら表示用にその値を返す
    var commonAlphaBeta: Double? {
        let abs = validCourses.map(\.alphaBeta)
        guard let first = abs.first, abs.allSatisfy({ $0 == first }) else { return nil }
        return first
    }

    func addCourse() {
        if canAdd { courses.append(CourseInput()) }
    }
    func remove(_ course: CourseInput) {
        courses.removeAll { $0.id == course.id }
    }
    func apply(_ selection: PresetSelection, to course: CourseInput) {
        // 自施設プリセットは読み込み経路を持つため、範囲外の巨大な値
        // （例: 1e100）が totalDose に入りうる。DoseFormat は Int() 変換の
        // トラップを避け、その場合でも文字列を返す。
        course.totalDoseText = DoseFormat.doseString(selection.totalDose)
        course.fractionsText = "\(selection.fractions)"
        if let ab = selection.alphaBeta {
            course.alphaBetaText = DoseFormat.alphaBetaString(ab)
        }
    }
}
