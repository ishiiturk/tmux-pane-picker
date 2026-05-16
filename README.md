# tmux pane picker

macOS 上で常駐し、iTerm2 とは別のフローティング UI から tmux pane を検索して focus を切り替えるツールです。

## v1 Scope

- macOS 専用。
- iTerm2 のみ対応。
- tmux server は単一。
- tmux session は複数対応。
- pane 一覧は全 session 横断で表示する。
- 選択した pane に切り替えたあと、iTerm2 を前面化する。

## Non Goals

- Terminal.app, WezTerm, Ghostty など iTerm2 以外の対応。
- 複数 tmux server / 複数 tmux socket の自動切り替え。
- 複数 iTerm2 window にある tmux client の厳密な識別。
- リモート host 上の tmux server の直接操作。

## Product Requirements

- メニューバーに常駐する。
- フローティング picker を表示する。
- pane 一覧を検索できる。
- Enter で選択中の pane に切り替える。
- Esc で picker を閉じる。
- pane 選択後に picker を閉じ、iTerm2 を前面に戻す。
- `tmux` が見つからない場合は、復旧できるエラーを表示する。

## tmux Integration

pane 一覧は tmux の format を使って取得する。

```sh
tmux list-panes -a -F '#{session_name}\t#{window_index}\t#{window_name}\t#{pane_index}\t#{pane_id}\t#{pane_current_command}\t#{pane_current_path}'
```

選択時は session/window を切り替えてから pane を選択する。

```sh
tmux list-clients -F '#{client_name}\t#{client_session}\t#{client_activity}\t#{client_flags}\t#{client_tty}'
tmux switch-client -c "$client_name" -t "$session_name:$window_index"
tmux select-pane -t "$pane_id"
osascript -e 'tell application "iTerm2" to activate'
```

`pane_id` は `%12` のような tmux 内部 ID を使う。表示名や index は変わり得るため、実際の focus 切り替えでは `pane_id` を優先する。

tmux client は `attached` な client の中から `focused` を優先し、該当がなければ `client_activity` が新しいものを使う。v1 では単一 tmux server 前提のため、複数 socket の探索はしない。

## Implementation Plan

1. SwiftUI macOS app の最小構成を作る。
2. `Process` 経由で `tmux list-panes` を実行し、pane model に parse する。
3. picker UI に pane 一覧と検索を実装する。
4. 選択時に `tmux switch-client`, `tmux select-pane`, iTerm2 activate を実行する。
5. メニューバー常駐とフローティング window を実装する。
6. グローバルショートカットを追加する。

## Development

Build and test with SwiftPM.

```sh
swift test
swift build
```

Run the local executable during development.

```sh
swift run tmux-pane-picker
```

The current implementation is a SwiftPM executable that opens a macOS menu bar app. Packaging it as a `.app` bundle is a later step.

## Runtime Assumptions

GUI アプリからは shell の PATH が引き継がれない場合があるため、`tmux` は以下の順で探す。

- `/opt/homebrew/bin/tmux`
- `/usr/local/bin/tmux`
- `/usr/bin/tmux`
- `PATH` 上の `tmux`

初期実装では App Sandbox を無効にする。外部コマンド実行と AppleScript による iTerm2 activate を単純に扱うため。
