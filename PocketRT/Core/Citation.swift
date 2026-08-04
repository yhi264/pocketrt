import Foundation

/// 一次文献の書誌情報。
///
/// `unsourcedNote` は、特定の一次文献を同定できなかったレジメンに用いる。
/// 推測で `pmid` / `doi` を埋めることは禁止する（app/docs/data-sources.md 参照）。
struct Citation: Identifiable, Hashable, Sendable {
    let id: String
    let shortLabel: String
    let authors: String
    let title: String
    let journal: String
    let year: Int
    let pmid: String?
    let doi: String?
    let urlString: String?
    let unsourcedNote: String?

    init(
        id: String,
        shortLabel: String,
        authors: String = "",
        title: String = "",
        journal: String = "",
        year: Int = 0,
        pmid: String? = nil,
        doi: String? = nil,
        urlString: String? = nil,
        unsourcedNote: String? = nil
    ) {
        self.id = id
        self.shortLabel = shortLabel
        self.authors = authors
        self.title = title
        self.journal = journal
        self.year = year
        self.pmid = pmid
        self.doi = doi
        self.urlString = urlString
        self.unsourcedNote = unsourcedNote
    }

    /// 一次文献が同定できているか
    var hasPrimarySource: Bool { pmid != nil || doi != nil }

    /// "Nagata Y, et al. Int J Radiat Oncol Biol Phys. 2015." 形式
    var formattedReference: String {
        guard hasPrimarySource else { return unsourcedNote ?? "" }
        return "\(authors) \(journal). \(year)."
    }

    /// PubMed / DOI の参照先
    var url: URL? {
        if let urlString { return URL(string: urlString) }
        if let pmid { return URL(string: "https://pubmed.ncbi.nlm.nih.gov/\(pmid)/") }
        if let doi { return URL(string: "https://doi.org/\(doi)") }
        return nil
    }
}
