# 開発に参加する

不具合の報告、小さな修正、Windows 上での動作確認を歓迎します。
大きな機能を追加するときは、先に Issue で用途と変更範囲を共有してください。

## 大事にしていること

1. Git Bash と MSYS2 のランタイムを混ぜない。
2. Windows と Git for Windows からセットアップできる状態を保つ。
3. 空白を含むパス、空の引数、シェルの特殊文字をデータとして正しく扱う。
4. bootstrap を再実行できるようにし、失敗を隠さない。
5. 小さく、読んで理解できる実装にする。

設計の詳細は [Technical guide](docs/technical-guide.md) を参照してください。

## 変更を確認する

Git Bash で、まず構文と差分を確認します。

```bash
for script in bootstrap.sh bin/.linukkusu.sh bin/dev bin/dev-run bin/dev-update tests/smoke.sh; do
  bash -n "$script" || break
done
git diff --check
```

bootstrap・ランチャー・パッケージ定義を変更した場合は、専用の Windows テスト環境で
`./bootstrap.sh` を実行し、インストール後に次を確認してください。
bootstrap は、そのユーザーの `~/.dev` に書き込みます。

```bash
bash tests/smoke.sh
dev
# 作業ディレクトリと UCRT64 のプロンプトを確認して exit
./bootstrap.sh
```

スモークテストには導入済みの Python が必要です。
更新を試す前には、その Linukkusu で動いているシェルや作業を閉じてください。
パッケージの名前や起動の仕組みを変更するときは、MSYS2 の公式資料も確認します。

## Pull request

何が困っていたか、変更後にどう動くか、実行した検証を記載してください。
Windows や Git for Windows のバージョン、確認できていない条件もあると再現しやすくなります。
文書だけの変更であれば、リンクとコード例の確認で十分です。

GitHub Actions は Windows 上で Bash の構文を確認します。
MSYS2 のインストールや、実際の runtime 更新・対話操作は自動テストの対象外です。

ローカルの検証用ファイルは `.test-work/` に置けます。このディレクトリは Git の対象外です。
