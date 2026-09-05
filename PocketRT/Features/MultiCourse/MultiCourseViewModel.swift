import Foundation

/// 合算タブの 1 コース分の入力。
///
/// **α/β を持たない。** α/β は「どの組織の生物効果を見ているか」を決める値で、
/// 評価対象に属する。コースごとに別の α/β を入れられると、腫瘍の BED と
/// 晩期反応組織の BED を足すような操作ができてしまい、その和が生物効果を
/// 表す組織は存在しない。α/β は `MultiCourseViewModel` が画面に 1 つだけ持つ。
@Observable
final class CourseInput: Identifiable {
    let id = UUID()
    var totalDoseText: String
    var fractionsText: String

    init(totalDose: Double = 60, fractions: Int = 30) {
        self.totalDoseText = DoseFormat.doseString(totalDose)
        self.fractionsText = "\(fractions)"
    }

    var totalDose: Double? { Double(totalDoseText) }
    var fractions: Int? { Int(fractionsText) }

    var isValid: Bool {
        guard let D = totalDose, let n = fractions else { return false }
        return (0.1...200).contains(D) && (1...99).contains(n)
    }

    var asCourse: Course? {
        guard let D = totalDose, let n = fractions, isValid else { return nil }
        return Course(id: id, totalDose: D, fractions: n)
    }

    /// このコース単独の BED。評価対象の α/β を受け取る。
    func bed(alphaBeta: Double) -> Double? {
        guard let c = asCourse else { return nil }
        return LQCore.bed(totalDose: c.totalDose, fractions: c.fractions, alphaBeta: alphaBeta)
    }

    /// このコース単独の EQD2。評価対象の α/β を受け取る。
    func eqd2(alphaBeta: Double) -> Double? {
        guard let b = bed(alphaBeta: alphaBeta) else { return nil }
        return LQCore.eqd2(bed: b, alphaBeta: alphaBeta)
    }
}

@Observable
final class MultiCourseViewModel {
    var courses: [CourseInput] = [
        CourseInput(),
        CourseInput(totalDose: 30, fractions: 10)
    ]
    let maxCourses = 3

    /// 評価する組織の α/β。**画面に 1 つだけ持つ。**
    ///
    /// 合算が意味を持つのは、評価対象の組織を 1 つ決めたときだけである。
    /// 「脊髄への累積線量はいくつか」という問いに対して、全コースを同じ
    /// α/β で評価する。コースごとに変えられるようにしていた頃は、混ざった
    /// 和を作れてしまい、その値が生物効果を表す組織が存在しなかった。
    var alphaBetaText: String = DoseFormat.alphaBetaString(10)

    var alphaBeta: Double? {
        guard let ab = Double(alphaBetaText), (0.5...30).contains(ab) else { return nil }
        return ab
    }

    var alphaBetaError: String? {
        alphaBetaText.isEmpty || alphaBeta != nil ? nil : String(localized: "0.5〜30 Gy")
    }

    var validCourses: [Course] { courses.compactMap(\.asCourse) }
    var canAdd: Bool { courses.count < maxCourses }

    /// 合算できる状態か。α/β が無ければ、コースが揃っていても合算しない。
    var canSum: Bool { alphaBeta != nil && !validCourses.isEmpty }

    var cumulativeBED: Double? {
        guard let ab = alphaBeta, !validCourses.isEmpty else { return nil }
        return LQCore.cumulativeBED(courses: validCourses, alphaBeta: ab)
    }

    var cumulativeEQD2: Double? {
        guard let ab = alphaBeta, !validCourses.isEmpty else { return nil }
        return LQCore.cumulativeEQD2(courses: validCourses, alphaBeta: ab)
    }

    func addCourse() {
        if canAdd { courses.append(CourseInput()) }
    }

    func remove(_ course: CourseInput) {
        courses.removeAll { $0.id == course.id }
    }

    /// プリセットをコースに適用する。**線量と分割数だけを入れ、α/β は変えない。**
    ///
    /// プリセットが持つ α/β はその部位の代表値であって、この画面で問うている
    /// 「いま評価している組織」とは別物である。コースにプリセットを当てるたびに
    /// 画面共通の α/β が書き換わると、他のコースの評価基準まで黙って変わる。
    /// α/β は利用者が上の欄で明示的に選ぶ（α/β プリセットもそこにある）。
    func apply(_ selection: PresetSelection, to course: CourseInput) {
        // 自施設プリセットは読み込み経路を持つため、範囲外の巨大な値
        // （例: 1e100）が totalDose に入りうる。DoseFormat は Int() 変換の
        // トラップを避け、その場合でも文字列を返す。
        course.totalDoseText = DoseFormat.doseString(selection.totalDose)
        course.fractionsText = "\(selection.fractions)"
    }
}
