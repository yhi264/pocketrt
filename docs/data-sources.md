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
