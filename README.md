# Big6

東京六大学野球（1925年以降の全試合）の記録サイトです。シーズンと順位表、カードごとの対戦成績、選手と個人成績、ランキングを扱い、JSON の Web API と MCP サーバーもあります。運用中のサイトは <https://big6.onrender.com/> です。

この README は、リポジトリを clone して手元で動かす人向けです。データの入手先（big6.gr.jp、BIG6 Scorebook、このサイトの API）の仕様は [docs/](docs/README.md) にまとめてあります。

## 必要なもの

| もの | バージョン・備考 |
|---|---|
| Ruby | 3.4（[.ruby-version](.ruby-version) を参照） |
| PostgreSQL | 16 以降（devcontainer は 16、CI は最新版） |
| libvips | OG 画像の生成に使います。テストにも必要です |
| 日本語フォント | `fonts-ipafont-gothic`。ないと OG 画像の日本語が描けません |
| libpq | `pg` gem のビルドに使います |

Node.js は要りません。JavaScript は importmap で読み込んでおり、ビルドの手順はありません。

## セットアップ

### devcontainer で動かす

VS Code などで「Reopen in Container」を選ぶと、Ruby の入ったコンテナと PostgreSQL のコンテナが立ち上がり、`bin/setup --skip-server` まで自動で実行されます。データベースは `DB_HOST=postgres`（ユーザー・パスワードとも `postgres`）で接続します。

注意点が2つあります。

- [.devcontainer/compose.yaml](.devcontainer/compose.yaml) は、リポジトリを `../../big6` としてマウントします。clone するディレクトリ名は `big6` にしてください。
- 同じファイルは作者の個人設定（`../../dots/.config/starship.toml`）もマウントします。手元にこのファイルがなければ、その行を消すかコメントアウトしてください。

### 手元の環境で動かす

Ubuntu / Debian の例です。

```sh
sudo apt-get install -y build-essential libpq-dev libvips fonts-ipafont-gothic postgresql
git clone https://github.com/ieremi/big6.git
cd big6
bin/setup --skip-server
```

macOS（Homebrew）なら `brew install postgresql@16 vips` と、IPA ゴシックなどの日本語フォントを入れてください。

データベースの接続先は [config/database.yml](config/database.yml) で決まります。

- 環境変数 `DB_HOST` を設定すると、そのホストにユーザー `postgres`、パスワード `postgres` で接続します。
- `DB_HOST` がなければ、ローカルの PostgreSQL に UNIX ソケット経由で、OS のユーザー名で接続します。
- ほかの接続先を使うときは `DATABASE_URL` を設定してください（例：`DATABASE_URL=postgres://user:pass@localhost:5432/big6_development`）。

`bin/setup` は gem を入れ、`big6_development` と `big6_test` を作り、マイグレーションと [db/seeds.rb](db/seeds.rb) を実行します。seeds が作るのは6大学と、1922年春〜2026年秋の各シーズンだけです。試合や選手のデータは、次の「データの取り込み」で入れます。

## 起動

```sh
bin/dev            # = bin/rails server
```

<http://localhost:3000/> を開きます。データを取り込む前は、シーズンの一覧などは空のままです。

`config/master.key` はリポジトリに含まれていませんが、development と test では要りません。

## データの取り込み

データは外部のサイトからスクレイピングして取り込みます。どのスクリプトも `bin/rails runner` で実行し、使える環境変数はそれぞれのファイルの先頭に書いてあります。相手のサーバーに負担をかけないよう、どのスクリプトもリクエストの間隔を空けています。全部を取り込むと数時間かかります。

最初から全部入れるときは、次の順に実行します。

```sh
# 1. 試合とスコア（BIG6 Scorebook）。FROM_YEAR と SEASON_LIMIT で年代を区切って分けて実行することもできます
bin/rails runner script/big6/full_sync.rb

# 2. 選手名鑑。3 と 4 より先に実行してください
bin/rails runner script/big6/import_players.rb

# 3. 試合ごとの出場選手（2021年以降。ネットワークは使いません）
bin/rails runner script/big6/import_game_members.rb

# 4. 試合ごとの打撃・投手成績（約5,900試合、1試合1秒間隔）
script/big6/import_game_stats.sh

# 5. 補足のデータ（どれも省略できます）
bin/rails runner script/big6/scrape_weather.rb            # 天気（気象庁）
bin/rails runner script/big6/scrape_sportsbull_videos.rb  # 試合動画（2023年以降）
bin/rails runner script/big6/update_reference_data.rb     # 首相・1人あたり GDP（Wikidata、世界銀行）
FILE='db/sources/*/*.yml' bin/rails runner script/big6/import_source_game.rb  # 書籍から書き起こした試合
```

一部のシーズンだけで試すなら、`FROM_YEAR=2025 SEASON_LIMIT=2 bin/rails runner script/big6/full_sync.rb` のように範囲を絞れます。`import_players.rb` と `import_game_stats.rb` も `FROM_YEAR` / `TO_YEAR` で絞れます。

`import_game_stats.sh` は、メモリが増えすぎて止まった（終了コード 75）取り込みを自動で再開します。途中で止めても、もう一度実行すれば続きから取り込みます。

本番では `config/recurring.yml` の定期ジョブ（直近の試合の同期など）が動きますが、development では動きません。直近の試合を更新したいときは、`full_sync.rb` をもう一度実行してください。

## 管理画面へのサインイン

サインインできるのは管理者だけで、管理者はメールアドレスで指定します。development では Google を使わずに、メールアドレスを入力するだけでサインインできます。

```sh
ADMIN_EMAILS=you@example.com bin/dev
```

<http://localhost:3000/login> から、指定したアドレスでサインインしてください。Google でサインインするには、Google Cloud の OAuth クライアントを作り、`GOOGLE_CLIENT_ID` と `GOOGLE_CLIENT_SECRET` を設定します（リダイレクト URI は `http://localhost:3000/auth/google_oauth2/callback`）。

## テストとチェック

```sh
bin/rails test     # テスト一式（並列で実行）
bin/rubocop        # コードスタイル
bin/ci             # rubocop、gem の脆弱性監査、brakeman、テスト、seeds をまとめて
```

テストは外部のサイトにアクセスしません。

`test/jobs/refresh_live_scoreboards_job_test.rb` のテストの1つは、UTC で 15:00〜24:00（日本時間の 0:00〜9:00）の間に実行すると失敗します。日付を UTC で作っているためで、既知の問題です。

## 本番環境

本番は Render で、[Dockerfile](Dockerfile) と [render.yaml](render.yaml) を使っています。`config/deploy.yml` と `.kamal/` は Rails のテンプレートの名残で、使っていません。

## そのほかの資料

- [CLAUDE.md](CLAUDE.md)：コードの構成、ドメインモデル、データの扱いの決まりごと（英語）
- [docs/](docs/README.md)：データの入手先の仕様と注意点。サイトの `/developers` でも公開しています
- `/api/docs`：Web API の説明（`config/openapi.yml` に OpenAPI の定義があります）
