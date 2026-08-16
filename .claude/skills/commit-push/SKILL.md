---
name: commit-push
description: SavePointリポジトリでの標準コミット・push手順。変更内容の確認、日本語コミットメッセージ作成、ユーザー承認、commit+pushをまとめて行う。「コミットして」「pushして」等の依頼で使う。
---

# commit-push

SavePointリポジトリでの変更を確認し、日本語でコミットメッセージを作成し、ユーザーの承認を得てからcommit・pushまで一括で行う。

## 手順

1. 以下を並列実行して現状を把握する:
   - `git status`（未追跡ファイル確認。`-uall`は使わない）
   - `git diff`（ステージ済み・未ステージ両方の変更）
   - `git log --oneline -10`（直近のメッセージスタイル確認。このリポジトリは日本語・体言止め寄りの短いメッセージが多い。例: 「Android SDKキャッシュを外し、CIキャッシュを3GB以内に収める」「アプリアイコンをセーブポイント風の立方体デザインに刷新」）

2. 変更内容から日本語で1〜2文のコミットメッセージ案を作成する。「なぜ」がわかる場合はそれを重視する。秘密情報（`key.properties`、`*.jks`、`env/*.json`等）が誤って含まれていないか必ず確認する。

3. ユーザーに変更内容の要約とコミットメッセージ案を提示し、commit・push実行の承認を得る（「OK」等の一言確認でよい）。承認前にcommit/pushを実行しない。

4. 承認後、関連ファイルのみを`git add`し（`-A`や`.`は使わない）、以下の形式でcommitする:
   ```
   git commit -m "$(cat <<'EOF'
   <日本語コミットメッセージ>

   Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
   EOF
   )"
   ```
   その後 `git push` する。

5. `git status`で成功を確認し、コミットハッシュとpush完了をユーザーに短く報告する。

## 注意

- ユーザーが明示的に依頼した場合のみ実行する（自発的にcommit/pushしない）。
- pre-commitフックが失敗した場合は原因を修正し、新規にcommitし直す（`--amend`や`--no-verify`は使わない）。
- force pushは明示的な依頼がない限り行わない。
