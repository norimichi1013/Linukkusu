<div align="center">

# Linukkusu

### そうだ、git bashがあるじゃないか

**Windows と Git for Windows から育てる、自分だけの開発環境。**

[![Shell syntax](https://github.com/norimichi1013/Linukkusu/actions/workflows/checks.yml/badge.svg)](https://github.com/norimichi1013/Linukkusu/actions/workflows/checks.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[はじめる](#はじめる) · [できること](#できること) · [設計と検証](docs/technical-guide.md) · [開発に参加する](CONTRIBUTING.md)

</div>

---

Windows でも、いつものシェルでコードを書きたい。
C++ をビルドしたい。Python も Node.js も使いたい。
できれば、開発ツールのインストーラーを一つずつ巡るところからは始めたくない。

そこで、すでに入っている Git for Windows に目を向ける。

**そうだ、git bashがあるじゃないか。**

Git Bash には、シェルも、ダウンロードの道具もある。
その小さな足場から、自分専用の MSYS2 と UCRT64 の開発環境を組み立てる。
それが **Linukkusu** です。

入口は Git Bash。作業場は `~/.dev/Linukkusu`。
リポジトリを clone して、`./bootstrap.sh` を実行するところから始まります。

## はじめる

用意するのは、**x86_64 の Windows 10 / 11 と、現在の Git for Windows**。
ダウンロード用のインターネット接続と、数 GB の空き容量も必要です。
WSL・管理者権限・開発ツールの MSI インストールは不要です。
Node.js、Python、CMake を先に入れておく必要もありません。

**Git Bash を開いて**実行します。

```bash
git clone https://github.com/norimichi1013/Linukkusu.git
cd Linukkusu
./bootstrap.sh

export PATH="$HOME/.dev/bin:$PATH"
dev
```

```text
MINGW64 /c/work/project
$ dev

UCRT64 /c/work/project
$
```

作業中のディレクトリを引き継いで、Linukkusu のシェルに入ります。
`exit` で元の Git Bash に戻れます。

次回からも `dev` を使えるようにするには、上の `export` 行を
Git Bash の `~/.bashrc` に追加してください。
bootstrap が Windows の PATH やシェルの設定ファイルを書き換えることはありません。

## できること

| 道具 | 用途 |
| --- | --- |
| Bash・pacman・base-devel・Git | シェル操作、パッケージ管理、開発の土台 |
| UCRT64 C/C++ toolchain | Windows 向けの C/C++ 開発 |
| CMake・Ninja | プロジェクトの構成とビルド |
| Python | スクリプトと開発ツール |
| Node.js・npm | JavaScript の開発とパッケージ管理 |
| ripgrep・fd | テキストとファイルの検索 |

導入するパッケージは [`packages/base.txt`](packages/base.txt) にまとめています。

### 入口は、三つのコマンド

```bash
dev                           # UCRT64 の対話シェルに入る
dev-run python --version      # 環境内でコマンドを一つ実行する
dev-update                    # インストール済みのパッケージを更新する
```

`dev-run` は引数と終了コードを引き継ぐので、Git Bash から必要な道具だけを
呼び出すこともできます。パイプなどのシェル構文を使うときは、明示的に Bash を呼びます。

```bash
dev-run cmake --version
dev-run node --version
dev-run bash -c 'printf "%s\n" "$PWD"'
```

更新は、Linukkusu のシェルとバックグラウンドの作業を閉じてから、Git Bash で実行してください。
MSYS2 のコア更新では、その環境で動いているプロセスが終了することがあります。

## 小さく始めて、混ぜずに育てる

```text
Windows
└── Git for Windows / Git Bash
    └── ./bootstrap.sh
        └── ~/.dev/Linukkusu
            ├── MSYS2     シェルとパッケージ管理
            └── UCRT64    Windows ネイティブの開発ツール
```

Git Bash は bootstrap と起動の担当です。
日々の開発は、独立した MSYS2 のランタイムで動く UCRT64 が担当します。
Linux カーネルや Linux バイナリの実行環境を提供するものではありません。

**Git Bash の PATH に追加するのは `~/.dev/bin` だけ。**
Linukkusu の `usr/bin` を追加すると、二つの MSYS ランタイムを混ぜてしまいます。
環境の境界は `dev` と `dev-run` が受け持ちます。

ホームディレクトリも環境内の `/home/dev` に分けています。
独自のビルド変数や認証設定は自動では引き継がないため、Linukkusu 内で設定するか、
`dev-run env NAME=value COMMAND` で明示的に渡してください。

### 同じ定義から、もう一度

`./bootstrap.sh` は再実行できます。既存の環境を更新し、不足するパッケージを追加して、
ランチャーをリポジトリの定義に揃えます。ホームや追加で導入したパッケージは保持します。
パッケージ一覧から項目を削除しても、自動ではアンインストールしません。

初期アーカイブの日付と SHA-256 は固定していますが、MSYS2 はローリング更新です。
v0.1 が再現するのは**環境の構成とパッケージの選択**であり、全パッケージのバージョン固定ではありません。

## リポジトリの案内

```text
Linukkusu/
├── .github/              Issue・PR テンプレート、GitHub Actions
├── bin/                  dev / dev-run / dev-update と共通処理
├── docs/                 詳細な設計・運用・検証の記録
├── packages/             導入するパッケージの定義
├── tests/                Windows 上でのスモークテスト
├── bootstrap.sh          Git Bash からのセットアップ
├── CONTRIBUTING.md       開発と変更確認の手順
├── LICENSE               MIT License
└── README.md             このページ
```

詳しいインストール構成、引数の扱い、更新時の復旧、空白を含むパスへの対策は
[Technical guide（英語）](docs/technical-guide.md) にまとめています。
不具合や提案は [Issues](https://github.com/norimichi1013/Linukkusu/issues) へどうぞ。

## いまの到達点

**v0.1 の初期実装です。** 空白を含む隔離環境で、初期化、実際の runtime 更新、
全パッケージ導入、bootstrap の再実行、引数の保持、CMake/Ninja による C++ ビルド、
対話シェルの出入り、証明書を使った HTTPS 接続を確認しています。

クリーンな Windows での既定パスへの初回導入、非 ASCII のユーザー名、
Ctrl-C や通信中断からの復旧は、追加の確認が必要です。
上の CI バッジは **Bash の構文チェック**の結果を示します。実環境テストの代わりにはなりません。

Codex CLI、GitHub CLI、追加のパッケージ構成、dotfiles、VS Code 連携は今後の候補です。
まずは、起動の仕組みを読んで理解できる、小さな開発環境から。

## 最初の Linukkusu は、手で作る

Windows と Git for Windows だけで始められる Linukkusu。
けれど、その Linukkusu を置く**最初の GitHub リポジトリ**は、Git だけでは作れません。
リポジトリの作成は、GitHub のサービスや API の仕事だからです。

だから、最初の一つは手で作りました。
その後は `gh` のような道具を追加すれば、次のリポジトリを作るところまで自分でできるようになります。
なお、`gh` は現在の基本パッケージには含まれていません。

**最初の Linukkusu は人の手で。その先は、Linukkusu から。**

---

[MIT License](LICENSE) · Built on [Git for Windows](https://gitforwindows.org/) and [MSYS2](https://www.msys2.org/)
