# skill-discovery

セッションログを分析して、スキル化できる繰り返しパターンを発見・提案するClaude Codeスキルです。

## 概要

日々のClaude Codeセッションから「指示→操作」のペアを抽出し、繰り返しパターンを検出してスキル化の機会を提案します。

## インストール

```bash
# リポジトリをクローン
git clone https://github.com/t-daisuke/skill-discovery.git ~/src/github.com/t-daisuke/skill-discovery

# スキルディレクトリにシンボリックリンクを作成
ln -s ~/src/github.com/t-daisuke/skill-discovery/skill-discovery ~/.claude/skills/skill-discovery
```

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

## 検出するパターン

1. **類似指示パターン**: 同じような仕事の指示が繰り返されている
2. **操作シーケンスパターン**: 特定の指示に対して同じ操作セットが実行される
3. **プロジェクト横断パターン**: 異なるプロジェクトで同じ「指示→操作」が繰り返される
4. **定型作業パターン**: 毎日/毎回実行される定型作業

## 出力例

```markdown
# スキル化提案レポート

## 高優先度（スキル化推奨）

### パターン: PR作成フロー
- **検出した指示例**: 「PRを作って」「プルリクお願い」など
- **対応する操作シーケンス**:
  1. git diff で差分確認
  2. git add で staging
  3. git commit でコミット
  4. git push でプッシュ
  5. gh pr create でPR作成
- **検出回数**: 5回（3個のプロジェクトで）
- **スキル化案**:
  - 名前: `create-pr`
  - 概要: 差分確認からPR作成まで一括実行
  - 期待効果: 毎回の手動指示が不要に
```

## セキュリティ

- パスワード、トークン、APIキーは自動的にフィルタリングされます
- 機密ファイルパスの取り扱いに注意してください

## ライセンス

MIT
