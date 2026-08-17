# PocketRT データ出典台帳

アプリに実装する**数値・引用の出典と検証状況**を記録する。spec `2026-08-03-pocketrt-phase2b-design.md` §9 のブロッキングタスク B1〜B3 の成果物。

**原則**: 一次資料に当たって転記する。特定できない値は「未特定」と記録し、**推測で出典を付けない。**

最終更新: 2026-08-03

---

## B2. SBRT 逸脱判定表（RTOG 0813 / 0915）

### 検証結果: 両プロトコルの Table 1 は完全に同一

原典 PDF を 2 つ独立に取得し、逐字照合した。

| プロトコル | 取得元 | 該当箇所 |
|---|---|---|
| RTOG 0915（末梢型・Arm 1: 34 Gy/1 Fr、Arm 2: 48 Gy/4 Fr） | `filecache.mediaroom.com/mr5mr_varianmedicalaffairs/179735/download/RTOG0915.pdf` | §6.4.2.1 の直後、p.16「Table 1: Conformality of Prescribed Dose for Calculations Based on Deposition of Photon Beam Energy in Heterogeneous Tissue」 |
| RTOG 0813（中心型・5 分割、8〜12 Gy/Fr） | `pps4rt.com/wp-content/uploads/2019/07/RTOG-0813-1.pdf` | 同名の Table 1、p.16 |

**PTV 体積・R100%・R50%・D2cm・V20 の全数値が一致し、表内の誤植（下記）まで一致する。**
したがって**アプリに実装する判定表は 1 つでよい。**0813 と 0915 の違いは処方線量・分割数と OAR 制約であり、適合性の表ではない。

### 転記した表

| PTV 体積 (cc) | R100% None | R100% Minor | R50% None | R50% Minor | D2cm None (%) | D2cm Minor (%) | V20 None (%) | V20 Minor (%) |
|---|---|---|---|---|---|---|---|---|
| 1.8 | <1.2 | <1.5 | <5.9 | <7.5 | <50.0 | <57.0 | <10 | <15 |
| 3.8 | <1.2 | <1.5 | <5.5 | <6.5 | <50.0 | <57.0 | <10 | <15 |
| 7.4 | <1.2 | <1.5 | <5.1 | <6.0 | <50.0 | <58.0 | <10 | <15 |
| 13.2 | <1.2 | <1.5 | <4.7 | <5.8 | <50.0 | <58.0 | <10 | <15 |
| 22.0 | <1.2 | <1.5 | <4.5 | <5.5 | <54.0 | <63.0 | <10 | <15 |
| 34.0 | <1.2 | <1.5 | <4.3 | <5.3 | <58.0 | <68.0 | <10 | <15 |
| 50.0 | <1.2 | <1.5 | <4.0 | <5.0 | <62.0 | <77.0 | <10 | <15 |
| 70.0 | <1.2 | <1.5 | <3.5 | <4.8 | <66.0 | <86.0 | <10 | <15 |
| 95.0 | <1.2 | <1.5 | <3.3 | <4.4 | <70.0 | <89.0 | <10 | <15 |
| 126.0 | <1.2 | <1.5 | <3.1 | <4.0 | <73.0 | <91.0 | <10 | <15 |
| 163.0 | <1.2 | <1.5 | <2.9 | <3.7 | <77.0 | <94.0 | <10 | <15 |

### 原典の注記（実装に直結する）

> **Note 1**: For values of PTV dimension or volume not specified, **linear interpolation between table entries is required.**
>
> **Note 2**: Protocol deviations greater than listed here as "minor" will be **classified as "major"** for protocol compliance.

- **Note 1 により、表にない PTV 体積では線形補間が必須。**spec §6.4 の制約 3 で「原典に補間の規定がなければ併記する」としていたが、**原典が補間を明示的に要求しているため、線形補間を実装する**
- **Note 2 により判定は 3 段階**（None = per protocol / Minor / それを超えるものは Major）
- 表の範囲外（PTV < 1.8 cc、> 163.0 cc）については原典に規定がない。**外挿はせず「表の適用範囲外」と表示する**

### 原典の誤植（転記時に補正した箇所）

| 箇所 | 原典の表記 | 補正 | 根拠 |
|---|---|---|---|
| PTV 3.8 の R100% Minor | `.<1.5` | `<1.5` | 先頭のピリオドは組版上のノイズ。他の全行が `<1.5` |
| PTV 126.0 の D2cm Minor | `>91.0` | `<91.0` | 他の全行が `<`。かつ値は 86.0 → 89.0 → 91.0 → 94.0 と単調増加しており、`>` では表の意味をなさない |
| PTV 163.0 の D2cm Minor | `>94.0` | `<94.0` | 同上 |

**この 3 箇所は 0813・0915 の両 PDF で同一に誤植されている。**共通の原本から派生したためと考えられる。補正は明白だが、アプリ内の出典表示に「原典の表記ゆれを補正している」旨を注記する。

### 原典の記述の不一致（実装方針）

- **D2cm の単位**: 表の見出しは "Maximum Dose (in % of dose prescribed) @ 2 cm from PTV in Any Direction, **D2cm (Gy)**" と、「処方線量比 %」と「Gy」が併記されている。値（50.0〜94.0）は明らかに**処方線量に対する %**である。`(Gy)` は誤りとみなし、**% として実装する**
- **R50% の定義**: RTOG 0813 は "The ratio of the volume of **50% of the prescription dose isodose** to the volume of the PTV" と明快。RTOG 0915 は同じ箇所を "the volume of the **34 or 12 Gy** isodose volume" と書いており、Arm 1 の全線量（34 Gy）と Arm 2 の 1 回線量（12 Gy）を指す形になっていて 50% と整合しない。**表の見出し（"Ratio of 50% Prescription Isodose Volume to the PTV Volume, R50%"）と 0813 の記述に従い、「処方線量の 50% の等線量体積 ÷ PTV 体積」として実装する**

---

## B6. 頭部定位照射の逸脱判定基準（RTOG radiosurgery QA guidelines, Shaw 1993）

**原典**: Shaw E, Kline R, Gillin M, Souhami L, Hirschfeld A, Dinapoli R, Martin L.
"Radiation Therapy Oncology Group: radiosurgery quality assurance guidelines."
*Int J Radiat Oncol Biol Phys.* 1993;27(5):1231-1239. PMID 8262852 / DOI 10.1016/0360-3016(93)90548-a

**取得**: 利用者が PDF を提供（2026-08-14）。**本文 p.1235 の "Quality assurance review" 節から逐字転記。**

抄録が目的の 3 番目に "To define minor and major deviations in protocol treatment" を挙げており、
RTOG 0813 / 0915 の Table 1 と同じ機能を頭部定位照射に対して果たす。

### 原典の記述（逐字）

> **1. Coverage:** If the 90% of prescription isodose line completely encompasses the target, the case
> is considered per protocol. If the 90% of prescription dose isodose line does not completely cover
> the target, but the 80% of prescription dose isodose line does completely cover the target, this
> shall be classified as a minor deviation. If the 80% of prescription dose isodose line does not
> completely cover the target this shall be classified as a major acceptable deviation.

> **2. Homogeneity index:** A figure of merit for dose homogeneity within the target volume shall be
> determined as the maximum dose in the treatment volume divided by the prescription dose (ratio
> MDPD). This ratio shall be less than or equal to 2.0, and if achieved, the case will be per protocol.
> MDPD ratio greater than 2 but less than 2.5 shall be classified as minor deviation. MDPD ratio
> greater than 2.5 shall be classified as a major acceptable deviation.

> **3. Conformity index:** The volume of the prescription isodose surface shall be determined (this may
> be obtained from the dose volume histogram, or by measuring the area of the prescription isodose on
> sequential levels). A figure of merit for conformation of the prescription dose to the target shall be
> determined as the volume of the prescription isodose surface divided by the target volume (ratio
> PITV). This ratio shall be between 1.0 and 2.0; and if achieved, there will be no deviation from
> protocol. PITV ratios less than 1.0 but greater than 0.9 shall be classified as minor deviations.
> PITV ratios less than 0.9 shall be classified as major deviations. PITV ratios between 2.0 and 2.5
> shall be classified as minor deviations, while PITV ratios greater than 2.5 shall be classified as
> major acceptable deviations.

### アプリの既存指標との対応

**2 つの数値指標はいずれもアプリが既に計算している。**

| 原典の指標 | 定義 | アプリの指標 |
|---|---|---|
| MDPD | 最大線量 ÷ 処方線量 | `hiRTOG`（`homogeneityIndexRTOG(maxDose:prescriptionDose:)`） |
| PITV | 処方等線量体積 ÷ 標的体積 | `ciRTOG`（`conformityIndexRTOG(piv:tv:)`） |

Coverage は数値指標ではなく「90% / 80% 等線量線が標的を完全に覆うか」という**真偽の判定**である。
アプリは現在この入力を持たない。

### 実装上の重大な差異: PITV は両側判定である

**RTOG 0813 / 0915 の表はすべて「小さいほど良い」の片側判定だが、PITV は両側である。**

```
        < 0.9        major
  0.9 〜 1.0        minor      ← 標的を覆いきれていない（under-coverage）
  1.0 〜 2.0        per protocol
  2.0 〜 2.5        minor
        > 2.5        major
```

現行の `ConformityCriteria.judge(value:none:minor:)` は `value < none` の片側しか扱えない。
**頭部定位照射を内蔵プロトコルとして入れるには、両側判定の仕組みが要る。**

これは D2（利用者定義の基準）の設計にも影響する。D2 の仕様 §2.3 は「判定の向きは
`value < none` に固定する」としているが、その根拠は「向きを選べると誤って反転させうる」で
あった。両側判定は「向きを選ぶ」のとは別で、**下限と上限の両方を持つ**形である。

### 原典の境界の不明確さ（実装時に判断が要る）

0813 / 0915 の誤植とは違い、これらは**原典の記述がその値を明示的に扱っていない**箇所である。

| 箇所 | 原典の記述 | 未定義の値 |
|---|---|---|
| MDPD | "less than or equal to 2.0" → per protocol、"greater than 2 but less than 2.5" → minor、"greater than 2.5" → major | **ちょうど 2.5**。「2.5 より大きい」でも「2.5 未満」でもない |
| PITV 下側 | "less than 1.0 but greater than 0.9" → minor、"less than 0.9" → major | **ちょうど 0.9**。「0.9 未満」でも「0.9 より大きい」でもない |
| PITV 上側 | "between 2.0 and 2.5" → minor、"greater than 2.5" → major | "between" が両端を含むかが不明。ただし 2.0 は "between 1.0 and 2.0" と重複する |

**Appendix II の計算例が一部を裏づける**（p.1238-1239）。

| 例 | 値 | 原典の分類 |
|---|---|---|
| Gamma Knife | MDPD = 2.0 | "acceptable"（≤2.0 が per protocol と整合） |
| Gamma Knife | PITV = 2.1 | "minor deviation"（2.0〜2.5 が minor と整合） |
| Linac | MDPD = 2.6 | "major acceptable deviation"（>2.5 が major と整合） |
| Linac | PITV = 1.9 | "per protocol"（1.0〜2.0 が per protocol と整合） |

計算例は境界そのものを踏んでいないため、上記 3 箇所の未定義は解消されない。
**実装時にどう扱うかを決め、アプリ内に明示する。**（0813 / 0915 で誤植の補正を明示したのと同じ扱い）

### 併せて入手した文書（照合済み・2026-08-14）

利用者が同時に提供。**両方を通読した結果、どちらも逸脱判定の閾値を持たない。**
Shaw 1993 が per protocol / minor / major の閾値を持つ唯一の文書である。
次に同じ調査をする人が読み直さずに済むよう、何が書かれていたかを残す。

#### Halvorsen PH, et al. AAPM-RSS Medical Physics Practice Guideline 9.a. for SRS-SBRT

*J Appl Clin Med Phys.* 2017;18(5):10-21. DOI 10.1002/acm2.12146

**判定基準は無い。** Table 1〜3 は**装置の QA 許容値**である（レーザー位置合わせ 1 mm、
放射線アイソセントリシティ 1.0 mm、出力恒常性 ±3%、E2E 線量評価 ±5% 等）。
機械の QA であって、計画の品質を段階分けする基準ではない。

§4.b.g に「標的被覆・線量落ち・適合性指標・重要臓器の線量目標を明記し放射線腫瘍医が
署名すべき」とあるが、数値の閾値は示されていない。

#### Shakeshaft J, et al. TROG SRS Technical Working Group

*J Med Imaging Radiat Oncol.* 2026;70(2):226-236. DOI 10.1111/1754-9485.70064

**判定基準は無い。** Table 1〜5 はすべて手順・文書化の勧告（"Document…" "Confirm…"）、
Table 6 は幾何学的精度の監査結果であって基準ではない。

ただし **§3.3.7 Dose Distribution Metrics に、本アプリに関わる記述が 3 つある。**

> Required dose metrics (such as near-max, near-min, conformity index) should be defined in the
> trial protocol. Note that some dose metrics, for example, conformity index, have multiple
> definitions and therefore the protocol should define the expected calculation method. ...
> It is recommended that the ICRU 91 Conformity Index, Gradient Index, near-maximum, and
> near-minimum doses are reported as a minimum requirement. As discussed in ICRU 91, where
> multiple PTVs are close to each other are likely to be present (as is commonly the case with BM),
> calculation of the gradient index may not be possible. Therefore, it may be helpful to include in
> the trial protocol reporting of additional metrics which have clinical relevance, such as normal
> brain V12Gy (or V10Gy) excluding CTVs.

| 記述 | 本アプリへの意味 |
|---|---|
| 適合性指数には**複数の定義**があり、どの計算方法かを定めるべき | **既存の設計判断の裏づけ。** アプリは CI (RTOG) と CI (Paddick) を別ラベルで併記しており、`manual-tests.md` §1.1 に「ラベルのない数値は曖昧で危険」という理由付きの確認項目がある |
| 標的が近接して複数ある場合、**gradient index は計算できないことがある** | **アプリの穴。** GI (Paddick) を無条件に計算・表示しており、この但し書きが無い。多発脳転移は頭部 SRS の主要な適応である |
| 正常脳 **V12Gy**（または V10Gy、CTV 除く）が臨床的に意味を持つ | アプリは計算していない。将来の候補 |

§3.3.8 は「処方と報告は ICRU Report 91 に従うことを強く推奨する」としている。
ICRU 91 は本アプリで未参照。

---

## B3. 既存プリセットの書誌情報

`academic/references/bibliography.md` に既出のものは参照先を示す。

### 確認済み

| プリセット | 出典 | 状態 |
|---|---|---|
| 前立腺 60/20 | CHHiP: Dearnaley D, et al. *Lancet Oncol.* 2016;17(8):1047-60. PMID 27339115 | bibliography [10] |
| 前立腺SBRT 36.25/5 | PACE-B: van As N, Griffin C, Tree A, et al. *N Engl J Med.* 2024;391(15):1413-25. PMID 39413377 | **掲載誌を確定（2026-08-03）。**下記参照 |
| 乳癌 START-B 40.05/15 | START Trialists' Group. *Lancet.* 2008;371(9618):1098-107. PMID 18355913 | bibliography [12] |
| 乳癌 FAST-Forward 26/5 | Murray Brunt A, et al. *Lancet.* 2020;395(10237):1613-26. PMID 32580883 | bibliography [13] |
| 乳癌 Whelan 42.56/16 | Whelan TJ, et al. *N Engl J Med.* 2010;362(6):513-20. PMID 20147717 | bibliography [14] |
| 早期肺癌 末梢 48/4 | JCOG0403: Nagata Y, et al. *Int J Radiat Oncol Biol Phys.* 2015;93(5):989-96. PMID 26581137 | bibliography [15] |
| 食道癌 60/30 | JCOG0303 (PMID 25640628) / JCOG0909 (PMID 35932949) | bibliography [17][18]。**2 試験に依拠するため、アプリでは 2 件の `Citation` として保持する**（下記） |
| 脳転移 分割SRT 27/3 | JLGK0901: Yamamoto M, et al. *Lancet Oncol.* 2014;15(4):387-95. PMID 24621620 | bibliography [19] |
| 脳転移 SRS 20/1・24/1 | RTOG 90-05: Shaw E, et al. *Int J Radiat Oncol Biol Phys.* 2000;47(2):291-8. PMID 10802351 | bibliography [20] |

### データモデル上の決定: 1 プリセット = 複数出典（2026-08-03）

食道癌 60 Gy/30 Fr のように、**1 つのレジメンが複数の試験に依拠する**ケースがある。当初の実装は 2 試験を 1 件の `Citation` にまとめ、`shortLabel` を "JCOG0303 / JCOG0909" としていたが、`Citation` は PMID/DOI を 1 組しか持てないため **JCOG0303 の識別子がアプリ内から失われていた**（リンク先は JCOG0909 のみ）。台帳にある値がアプリに届かないのは、本プロジェクトが排除しようとしている忠実性の欠落そのものである。

**決定**: `FractionationPreset` は `citations: [Citation]` を持つ。1 試験のレジメンは要素 1 件の配列とする。表示は `shortLabel` を " / " で連結し、詳細画面では各文献に個別の書誌情報とリンクを出す。

この構造は BL-1（JASTRO ガイドラインを典拠とする案）にもそのまま使える。ガイドラインの記載と、その根拠となる試験の両方を並べられる。

### 訂正した誤り

#### 1. 「早期肺癌 中心 60 Gy/8 Fr」の出典は JCOG0702 ではなく **JROSG10-1**

**誤り**: `Core/Presets.swift` は当該プリセットの `source` を `"JCOG0702"` としていた。

**事実**（PubMed で確認）:

- **JCOG0702** = Onimaru R, Onishi H, Ogawa G, et al. "Final report of survival and late toxicities in the Phase I study of stereotactic body radiation therapy for **peripheral T2N0M0** non-small cell lung cancer (JCOG0702)." *Jpn J Clin Oncol.* 2018;48(12):1076-82. PMID 30277519. DOI 10.1093/jjco/hyy141
  → **末梢型 T2**、**4 分割**（40/45/50/55/60 Gy を D95 処方で漸増）。中心型でも 8 分割でもない
- **正しい出典** = Kimura T, Nagata Y, Harada H, et al. "Phase I study of stereotactic body radiation therapy for **centrally located stage IA** non-small cell lung cancer (**JROSG10-1**)." *Int J Clin Oncol.* 2017;22(5):849-56. PMID 28466183. DOI 10.1007/s10147-017-1125-y
  → 抄録に **"The RD of SBRT for centrally located stage IA NSCLC was 60 Gy in eight fractions."** とあり、プリセットと完全一致。52〜68 Gy/8 分割の 5 段階で設定し、MTD 60 Gy

**裏付け**: JASTRO 放射線治療計画ガイドライン 2020「胸部・Ⅲ 肺癌に対する定位放射線治療・4 線量分割」に、

> 中枢性肺癌に対する定位照射の最大耐容線量および推奨線量を決定するため，国内における **JROSG10-1 では 60 Gy/8 回（アイソセンタ処方）が推奨線量**となった

とある。同ガイドラインは 60 Gy/8 回を末梢型で行われている分割の一つとしても挙げているが、**中枢型の推奨線量として明示しているのは JROSG10-1** である。

**処方点に注意**: JROSG10-1 は**アイソセンタ処方**。同ガイドラインは「アイソセンタ処方で 48 Gy は PTV D95% 処方で 42 Gy とほぼ同等」とも述べており、処方点の違いは BED 計算に影響する。**プリセットの注記に処方点を明示する。**

#### 2. PACE-B の掲載誌を確定（`bibliography.md` [11] の未解決事項を解消）

`bibliography.md` [11] は掲載誌を「IJROBP 2023 抄録 / NEJM 2024 のいずれか未確定」としていた。PubMed で確認し確定した。

- **主要有効性論文（プリセットが依拠すべきもの）**: van As N, Griffin C, Tree A, et al. "Phase 3 Trial of Stereotactic Body Radiotherapy in Localized Prostate Cancer." *N Engl J Med.* 2024;391(15):1413-25. **PMID 39413377. DOI 10.1056/NEJMoa2403365**
  抄録に **"SBRT (36.25 Gy in 5 fractions over a period of 1 or 2 weeks)"** とあり、プリセットと完全一致。5 年 FFBCF 95.8% vs 94.6%（HR 0.73、非劣性 p=0.004）
- **急性期毒性の別報**（混同しやすいので併記）: Brand DH, Tree AC, Ostler P, et al. *Lancet Oncol.* 2019;20(11):1531-43. PMID 31540791. DOI 10.1016/S1470-2045(19)30569-8

**STATUS.md の未解決事項「PACE-B [11] の引用情報の最終確認」はこれで解消する。**

#### 3. `bibliography.md` [16] の著者名が誤り

同エントリは JCOG0702 の著者を「Hamamoto Y, Kataoka M, Nogami N, Yamamoto N, Doi Y, Saito M, et al.」としているが、**PubMed の PMID 30277519 の著者は Onimaru R, Onishi H, Ogawa G, Hiraoka M, Ishikura S, Karasawa K, Matsuo Y, Kokubo M, Shioyama Y, Matsushita H, Ito Y, Shirato H** である。

また同エントリの注釈は「recommending 55 Gy / 4 fractions」とするが、**抄録に推奨線量の記載はない**（40/45/50/55/60 Gy の各群の患者数と生存を報告するのみ）。

**論文側（`academic/papers/draft01.md`、`bibliography.md`）の修正も必要。**STATUS.md の未解決事項「JCOG0702 [16] の引用情報の最終確認」はこれで解消する。

### 未確認

| プリセット | 現在の source | 課題 |
|---|---|---|
| 頭頸部根治 70/35 | "NCCN H&N" | ガイドラインのバージョン（年・版）を特定して記載する必要がある |
| 前立腺癌根治 78/39 | "JASTRO 前立腺癌GL" | 同上 |
| 乳癌温存術後 50/25 | "従来標準" | 特定の一次文献ではない。慣用として扱うか、START-A/B の対照群を引くか |
| GBM 60/30 | "Stupp" | Stupp R, et al. *N Engl J Med.* 2005;352(10):987-96 と推定されるが未照合 |
| 骨転移 シングル 8/1 | "Bone Pain Trial" | Bone Pain Trial Working Party 1999 と推定されるが未照合 |

---

## B1. 出典未特定 7 件

### 特定できたもの

| プリセット | 出典 |
|---|---|
| 骨転移 20/5・30/10 | Rich SE, Chow R, Raman S, et al. "Update of the systematic review of palliative radiation therapy fractionation for bone metastases." *Radiother Oncol.* 2018;126(3):547-57. PMID 29397209. DOI 10.1016/j.radonc.2018.01.003（29 の RCT のメタ解析。単回 vs 複数回で疼痛緩和は同等、再照射は単回で有意に多い〔20% vs 8%〕）<br>**注**: 本メタ解析は「単回 vs 複数回」の比較であり、20 Gy/5 回・30 Gy/10 回という**個別の分割を定義した試験ではない**。複数回分割群の代表的レジメンとして引く |

### 未特定 → **暫定対応を決定（2026-08-03）**

以下は、単一の定義的試験を特定できていない。いずれも広く行われているレジメンだが、「このレジメンを定めた試験」が存在するかが確認できていない。

| プリセット | 状況 |
|---|---|
| 脳転移 分割SRT 30/5 | 定義的試験を特定できず |
| 聴神経腫瘍 12/1 | 12 Gy 辺縁線量の SRS 報告は多数あるが、標準を定めた単一試験を特定できず |
| 肝SBRT 40/5 | 同上 |
| 脊椎転移SBRT 24/2 | 同上 |
| 全脳照射 30/10 | RTOG の初期研究（Borgelt ら）が起源と考えられるが未照合 |

**決定**: 当面は `Citation.unsourcedNote` に「広く用いられる慣用レジメン。特定の一次文献に基づかない」と記録して実装を進める。**推測で一次文献を付けることはしない。**

**バックログ項目として、対応方針を改めて検討する**（spec §5.2 バックログに記載）。

**有力な方針: JASTRO『放射線治療計画ガイドライン』を出典とする。**
本調査で「早期肺癌 中心 60 Gy/8 回」の出典（JROSG10-1）を特定できたのは、同ガイドライン胸部章の記載が起点だった。同様に、上記 5 件も同ガイドラインの該当章に標準的分割として記載されている可能性が高い。

その場合、出典の性格が変わる点に注意する。一次文献（試験）ではなく**診療ガイドラインの記載**を典拠とすることになるため、`Citation` にはガイドライン名・版・章・該当ページを記録し、**「一次文献ではなくガイドラインに基づく」ことが利用者に分かる表示**にする必要がある。

確認すべき章（`https://www.jastro.or.jp/medicalpersonnel/guideline/2020/` 配下）:

| プリセット | 確認先 |
|---|---|
| 脳転移 分割SRT 30/5、全脳照射 30/10 | 中枢神経系の章 |
| 聴神経腫瘍 12/1 | 中枢神経系の章、または『良性疾患の放射線治療ガイドライン』 |
| 肝SBRT 40/5 | 腹部（肝）の章 |
| 脊椎転移SBRT 24/2 | 骨転移・緩和の章 |

なお本調査で取得済みの胸部章 PDF（`04chest.pdf`）は `pdftotext -layout` でテキスト抽出できた。他章も同様に扱えると見込まれる。


---

## B4. JASTRO 放射線治療計画ガイドライン 2020 との照合（2026-08-06）

出典未特定として残していた項目を、JASTRO 放射線治療計画ガイドライン 2020 年版（章別 PDF）と PubMed で照合した。

**参照した資料**: `~/SynologyDrive/放射線治療/放射線治療ガイドライン2020/` の章別 PDF。本文は `pdftotext -layout` で抽出して該当箇所を確認した。

### B4.1 PubMed で一次文献が確定したもの

| プリセット | 確定した出典 | 根拠 |
|---|---|---|
| Glioblastoma 60 Gy/30 Fr | Stupp R, et al. *N Engl J Med.* 2005;352(10):987-96. **PMID 15758009** / DOI 10.1056/NEJMoa043330 | 要旨に「daily fractions of 2 Gy given 5 days per week for 6 weeks, for a total of 60 Gy」。線量・分割ともに一致 |
| 骨転移 シングル 8 Gy/1 Fr | Bone Pain Trial Working Party. *Radiother Oncol.* 1999;52(2):111-21. **PMID 10577696** | 要旨に「single fraction of 8 Gy」。対照群は「20 Gy/5 fractions or 30 Gy/10 fractions」 |

DOI は Stupp のみ付与されている。Bone Pain Trial は PMID のみ。

**派生論点**: Bone Pain Trial の対照群が 20 Gy/5 回と 30 Gy/10 回であるため、現在メタ解析を出典としている「骨転移 中等回数 20/5」「骨転移 マルチ 30/10」も、この一次文献に寄せられる可能性がある。どちらを主たる出典とするかは未決。

### B4.2 ガイドラインの記載と一致したもの

| プリセット | アプリの値 | ガイドラインの記載 | 章 |
|---|---|---|---|
| 頭頸部根治 | 70 Gy/35 Fr | **「70 Gy/35 回/7 週の通常分割照射が標準分割照射法である」** | 頭頸部 |
| 乳癌温存術後 | 50 Gy/25 Fr | 「通常分割照射（50 Gy/25 回/35 日）」 | 胸部 |
| 全脳照射 | 30 Gy/10 Fr | **「全脳照射では、30 Gy/10 回/2 週が標準的である」** | 緩和 |
| 聴神経腫瘍 | 12 Gy/1 Fr | 「SRS：辺縁線量 12〜13 Gy で行われることが多く」 | 中枢神経 |

### B4.3 記載はあるが標準として指定されていないもの

| プリセット | アプリの値 | ガイドラインの記載 | 評価 |
|---|---|---|---|
| 前立腺癌根治 | 78 Gy/39 Fr | 「3D-CRT の場合 70〜72 Gy、IMRT の場合には 74〜78 Gy が用いられることが多い」 | 総線量は範囲の上限に一致。**分割数はこの文には書かれていない**。1 回 2 Gy とすれば 39 回になる |
| 肝SBRT | 40 Gy/5 Fr | 「SBRT では 1 回線量を増加することが可能であり、さまざまな線量分割の報告がみられる（表 1）」。表 1 に本邦の報告として 40 Gy/5 回が掲載 | **単一の標準を示していない**。報告例の一つ |

### B4.4 不一致が見つかったもの（要判断）

**出荷済みの値がガイドラインの記載と分割数で一致しない。**

| プリセット | アプリの値 | ガイドラインの記載 | 差 |
|---|---|---|---|
| **脳転移 分割SRT** | 30 Gy/**5** Fr | 「分割照射による SRT では…**28〜32 Gy/4 分割**程度がしばしば用いられている」（緩和） | 総線量 30 Gy は範囲内だが、**分割数が 5 対 4** |
| **脊椎転移SBRT** | 24 Gy/**2** Fr | 「通常照射後の脊髄圧迫の再燃に対しては、**24 Gy/3 回**や 30 Gy/5 回などの SBRT も検討対象になる」（緩和） | 総線量は一致するが**分割数が 2 対 3**。さらに**ガイドラインの文脈は再照射**であり、初回治療の想定と異なる |

分割数が違えば BED も EQD2 も変わるため、これは表示上の差ではなく計算結果の差である。値を変えるか、注記で扱いを明示するかは**臨床的判断であり、開発者（利用者本人）が決める**。推測で書き換えない。

### B4.5 この照合で確定しなかったこと

- ガイドラインは**二次資料**である。上記の一致は「ガイドラインにその記載がある」ことを示すもので、一次文献まで遡ったわけではない。`Citation` の設計上、一次文献（PMID/DOI あり）とは区別して扱う必要がある
- 前立腺癌根治の分割数（39 回）は、ガイドラインの当該文からは確認できていない


---

## B5. ガイドライン照合に基づくプリセットの整理（2026-08-06 決定）

### 採用基準の変更

**「一次文献の裏付けがあること」から「JASTRO 放射線治療計画ガイドライン 2020 に明記されていること」へ、採用基準を変更した。**

理由は、本アプリが日本の放射線治療医と医学物理士を広く対象とするためである。論文や臨床試験で裏付けられていても、十分なコンセンサスが得られているとは言い難い線量分割を一覧に並べるのは、この対象設定と合わない。ガイドラインに明記されていない線量分割をあえて載せる必要はない。

この基準は一次文献の有無より厳しく、**よく引用される臨床試験のレジメンでも落ちうる**。実際に PACE-B（前立腺SBRT）が該当した。

### 削除した 5 件

| プリセット | 削除理由 |
|---|---|
| 脳転移 分割SRT 27 Gy/3 Fr | ガイドラインは「28〜32 Gy/4 分割程度がしばしば用いられている」とし、分割数が一致しない。同章は「適応と至適線量についてのエビデンスは少ない」とも記している |
| 脳転移 分割SRT 30 Gy/5 Fr | 同上 |
| 脊椎転移SBRT 24 Gy/2 Fr | ガイドラインは「24 Gy/3 回や 30 Gy/5 回などの SBRT」とし分割数が一致しない。さらに**その記載は通常照射後の脊髄圧迫再燃に対する再照射の文脈**であり、適応が異なる |
| 前立腺SBRT 36.25 Gy/5 Fr | extreme hypofractionation として言及はあるが**具体的線量の記載がなく**、「臨床試験が進められており、経験のある施設で慎重にすべきである」とされている |
| 肝SBRT 40 Gy/5 Fr | 「さまざまな線量分割の報告がみられる」として表に本邦の報告が載るのみで、**単一の標準が示されていない** |

**残した判断**: 乳癌超寡分割（FAST-Forward 26 Gy/5 Fr）はガイドライン 2020 年版に記載がないが、削除しない。FAST-Forward の主要報告が 2020 年でガイドラインに反映されていないだけであり、コンセンサスの欠如とは異なると判断した。

### 命名の変更

骨転移の 3 件を「骨転移 シングル」「骨転移 中等回数」「骨転移 マルチ」から、いずれも **「骨転移」** に統一した。この呼び分けは一般的ではなく、かつ `regimenLabel` が「8 Gy / 1 Fr」のように線量と分割を併記するため、名前で重ねて説明する必要がない。

### 削除に伴う整理

`jlgk0901`（JLGK0901）と `paceB`（PACE-B）は参照するプリセットがなくなったため定義ごと削除した。書誌情報は本文書 §B1 に残る。

**副次的に見つかった不整合**: `jlgk0901` は `Citations.all` に元から列挙されておらず、`CitationTests` の網羅検査（id の一意性、根拠の有無）の対象外だった。表示は `PresetSheet` 経由だったため気づかれていなかった。削除後、`Citations.all` は定義済み 16 件すべてを網羅する。

### 結果

プリセット 23 件 → **18 件**。
