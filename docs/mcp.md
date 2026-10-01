# MCP サーバー（AI アシスタントから Big6 のデータを使う）

このサイト（Big6）の [Web API](https://big6.onrender.com/api/docs) は、MCP（Model Context Protocol）のサーバーとしても使えます。ChatGPT や Claude などの AI アシスタントにつなぐと、会話のなかで試合・順位表・選手の成績などを調べられます。

（2026年10月1日に確認。ChatGPT からの接続もこの日に確かめました）

## なぜ MCP なのか

ChatGPT は、そのままでは Web API を使えません。

- **コード実行（Python）の環境**は外部のネットワークに接続できません。API の URL への接続そのものが失敗します。
- **ウェブ検索の機能**は、API の URL を開けないことがあります（「Invalid URL」などと返ります）。

GPT の「アクション（Actions）」なら OpenAPI の仕様書から API を呼べますが、GPT は2026年12月11日に廃止されます。プラグインに移行しても、アクションは引き継がれません。ChatGPT のプラグインが外部のデータにつなぐ方法は、MCP のアプリです。

## 接続の情報

| 項目 | 値 |
|---|---|
| URL | `https://big6.onrender.com/mcp` |
| 方式 | Streamable HTTP（ステートレス。応答は JSON） |
| 認証 | なし |
| 操作 | 読み取りだけ（すべてのツールが `readOnlyHint: true`） |

## つなぎ方

### ChatGPT

有料プラン（Plus・Pro・Business・Enterprise・Edu）で使えます。Business や Enterprise のワークスペースでは、管理者の許可がいることがあります。

1. "Settings" で "Developer mode" をオンにします。場所は時期によってちがい、"Apps" → "Advanced settings" にあることも、"Security and login" にあることもあります。
2. サイドバーの "Plugins" の "+" から、アプリを追加します。名前と説明を入れ、"Connection" に上の URL を入れます。認証はなしです。
3. 作成すると、下の12個のツールが表示されます。

### Claude など

MCP に対応したアシスタントでは、カスタムのコネクタ（リモートの MCP サーバー）として上の URL を追加すれば使えます。

## ツール

ツールは [Web API](https://big6.onrender.com/api/docs) の項目と1対1です。返す JSON も、同じ API の応答そのものです（中身の説明は Web API のページにあります）。太字の引数は必須です。

| ツール | 内容 | 引数 |
|---|---|---|
| `list_universities` | 6大学の一覧 | なし |
| `get_university` | 1大学の情報と通算成績 | **slug** |
| `list_seasons` | 全シーズンの一覧 | なし |
| `get_season` | 1シーズンの全試合 | **year**、**term** |
| `get_standings` | シーズンの順位表 | **year**、**term**、exclude_weekdays |
| `search_games` | 試合の検索 | university、term、start_year、end_year、page |
| `get_game` | 1試合とスコアボード | **year**、**term**、**team0**、**team1**、**round** |
| `get_matchup` | 2大学の対戦成績 | **team0_slug**、**team1_slug**、since_years、year、term、exclude_weekdays |
| `search_players` | 選手・スタッフの検索 | q、university、start_year、end_year、role、status、page |
| `get_player` | 1人のプロフィールとシーズン別・通算成績 | **id** |
| `get_player_games` | 1人の試合ごとの記録 | **id** |
| `get_ranking` | 打者（OPS）・投手（防御率）のランキング | **kind**、year、term、university、minimum、sort、direction、page |

引数の値の決まり:

- **大学**は slug で表します。`waseda`（早大）、`keio`（慶大）、`meiji`（明大）、`hosei`（法大）、`tokyo`（東大）、`rikkio`（立大）。`university` には複数の大学を配列で渡せます。
- **シーズン**は `year`（年）と `term`（`spring`＝春季、`autumn`＝秋季）です。
- **選手**の `id` は BIG6 Scorebook の選手IDで、このサイトの選手ページの URL（`/players/20243028`）と同じ番号です。
- **試合**は年・シーズン・2大学・回戦（`round`）で表します。2大学の順番はどちらでもかまいません。

正しくない引数（存在しない大学名など）は、API を呼ぶ前にエラーになります。存在しない選手や試合を指定した場合は、`isError: true` の結果になります。

## 使い方の例

アシスタントは、サーバーの案内文とツールの説明を読んで、自分でツールを選びます。たとえば次のような流れになります。

- **「明大の湯田統真投手の今季の成績は？」**：`search_players`（`q: "湯田統真"`）で id を調べ、`get_player` でシーズン別の成績を見る。
- **「昨日の試合の結果は？」**：`get_season` でそのシーズンの全試合を取り、`played_on`（試合日）で昨日の試合に絞る。詳しいスコアは `get_game`。
- **「立大と東大の通算の対戦成績は？」**：`get_matchup`（`team0_slug: "rikkio"`、`team1_slug: "tokyo"`）。
- **「今季の打率のランキング」**：`get_ranking`（`kind: "batting"`、`year`・`term`、`sort: "average"`）。

## 注意点

- **データの範囲**は Web API と同じです。試合ごとの成績は、BIG6 Scorebook に試合ごとのデータがある試合だけで、1950年代や2010〜2016年の多くの試合は成績がありません（[BIG6 Scorebook](scorebook.md)を参照）。
- **試合中の試合**は、`status` が `in_progress` で、スコア（`score`）は試合が終わるまで `null` です。途中経過は `get_game` のスコアボードにあることがあります。
- **一覧は1ページ100件**です。`search_games`・`search_players`・`get_ranking` は、`total` が100を超えると `page` で続きを取ります。
- **応答の大きさ**：`get_season` はシーズンの全試合（中止を含めて30〜40試合ほど）、`get_player_games` は選手の全試合を一度に返します。
