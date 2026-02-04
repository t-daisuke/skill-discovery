# skill-discovery

セッションログを分析して、スキル化できる繰り返しパターンを発見・提案するClaude Codeスキルです。

## 概要

日々のClaude Codeセッションから「指示→操作」のペアを抽出し、繰り返しパターンを検出してスキル化の機会を提案します。

**こんな人におすすめ:**
- 毎日同じような指示をClaude Codeに出している
- 自分の作業パターンを可視化したい
- どんなスキルを作れば効率化できるか知りたい

## 動作確認環境

- macOS または Linux (WSL2含む)
  - macOS: `date -v`/`-j` と `stat -f` を使用
  - Linux: `date -d` と `stat -c` を使用
  - OSは実行時に自動判定
- `jq` コマンド (JSON解析用)
- Claude Code (Agent Skills対応版)

### jqのインストール

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq

# その他のLinux
# https://jqlang.github.io/jq/download/ を参照
```

## インストール

### 方法1: シンボリックリンク（推奨）

`git pull` で最新版に更新できます。

```bash
git clone https://github.com/t-daisuke/skill-discovery.git ~/skill-discovery
ln -s ~/skill-discovery/skill-discovery ~/.claude/skills/skill-discovery
```

### 方法2: コピー

リポジトリに依存せず独立して動作します。

```bash
git clone https://github.com/t-daisuke/skill-discovery.git /tmp/skill-discovery
cp -r /tmp/skill-discovery/skill-discovery ~/.claude/skills/
```

インストール後、新しいセッションを開始すると `/skill-discovery` が使えるようになります。

## 使い方

```bash
# 今日のセッションを分析
/skill-discovery

# 昨日のセッションを分析
/skill-discovery yesterday

# 指定日のセッションを分析
/skill-discovery 2026-01-20

# 直近7日間のセッションを分析（推奨）
/skill-discovery week
```

**おすすめ**: 週末に `/skill-discovery week` を実行して、1週間の作業パターンを振り返る

## 検出するパターン

| パターン種別 | 説明 | 例 |
|------------|------|-----|
| 類似指示パターン | 同じような指示が繰り返される | 「PRを作って」「コミットして」 |
| 操作シーケンスパターン | 特定の指示に対して同じ操作セットが実行される | PR作成 → diff→add→commit→push→gh pr create |
| プロジェクト横断パターン | 異なるプロジェクトで同じ指示が繰り返される | どのプロジェクトでも「テスト実行」が発生 |
| 定型作業パターン | 毎日/毎回実行される定型作業 | セッション開始時のgit pull |

## 出力例

実際に1週間分のセッションを分析した結果の例:

```
統計サマリー
- 分析期間: 2026-01-29 〜 2026-02-04 (7日間)
- 分析セッション数: 42
- 検出パターン数: 8
- スキル化推奨: 3件
```

### 高優先度（スキル化推奨）の例

**パターン: CI/GitHub Actions確認 → 原因調査 → 修正**

- 検出した指示例:
  - 「いまってci通ってる？」
  - 「はい。原因を教えて。」
- 対応する操作シーケンス:
  1. `gh pr checks` または `gh run list` でCI状況確認
  2. `gh run view --log-failed` で失敗ログ取得
  3. 該当ファイルを読んで原因特定
  4. 修正 → format check → push
- 検出回数: 4回（2個のプロジェクトで）
- スキル化案:
  - 名前: `fix-ci-failure`
  - 概要: CI失敗を検出 → ログ取得 → 原因特定 → 修正案提示を一括実行

**パターン: エラーメッセージから原因箇所を特定**

- 検出した指示例:
  - 「このエラーが出る箇所を教えて」
  - 「このエラーが出る仮説を箇条書きで教えて」
- 対応する操作シーケンス:
  1. Grep でエラーメッセージを検索
  2. 該当ファイルを Read で確認
  3. 呼び出し元を追跡
  4. 仮説を立てて検証
- 検出回数: 5回（3個のプロジェクトで）
- スキル化案:
  - 名前: `trace-error`
  - 概要: エラーメッセージを入力 → 発生箇所特定 → 呼び出し元追跡 → 原因仮説提示

### 既存スキルとの関係も分析

```
┌───────────────────┬──────────────────────┬──────────────────────────────────┐
│   検出パターン    │  関連する既存スキル  │             対応状況             │
├───────────────────┼──────────────────────┼──────────────────────────────────┤
│ コミット→プッシュ │ /auto-commit-push    │ 部分カバー（PR作成は含まない）   │
├───────────────────┼──────────────────────┼──────────────────────────────────┤
│ CI確認            │ /dos_check_gh_action │ 部分カバー（修正提案は含まない） │
└───────────────────┴──────────────────────┴──────────────────────────────────┘
```

## ワークフロー例

1. **週次レビュー**: 毎週金曜に `/skill-discovery week` を実行
2. **パターン確認**: 高優先度のパターンを確認
3. **スキル作成**: 提案されたスキル案を参考に新しいスキルを作成
4. **継続改善**: 翌週また分析して効果を確認

## セキュリティ

- パスワード、トークン、APIキーは自動的にフィルタリングされます（`***REDACTED***` に置換）
- フィルタリング対象:
  - `password=`, `token=`, `api_key=` などのパターン
  - `Bearer` トークン
  - GitHub Personal Access Token (`ghp_`, `gho_`)
  - OpenAI API Key (`sk-`)

## 技術詳細

- セッションログは `~/.claude/projects/` から読み取り
- subagentのログは除外（メインセッションのみ分析）
- macOSとLinuxの両方に対応

## ライセンス

MIT
