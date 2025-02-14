# UEBAコンテナ ダウンロードサイト README

## 1. UEBAの概要

UEBA（User and Entity Behavior Analytics）は、ユーザーおよびエンティティの振る舞いを分析し、不審な挙動を検知するためのセキュリティソリューションです。本製品は、企業・組織の情報セキュリティを強化し、内部脅威や外部からの攻撃を未然に防ぐことを目的としています。

本UEBAコンテナは、audit.logを収集し、AIエンジンを用いてログを解析することで、異常なアクセスパターンや不審な振る舞いを検知し、迅速な対応を可能にします。

## 2. UEBAの重要性と重要インフラ事業者の責務

近年、サイバー攻撃は高度化・巧妙化しており、特に重要インフラ事業者には厳格なセキュリティ対策が求められています。UEBAは以下のような役割を担います。

- **audit.logの収集**：システムのアクセスログや操作ログを自動収集
- **AIエンジンによる解析**：機械学習を活用し、通常の挙動と異なる不審なアクセスを識別
- **リアルタイムでの異常検知**：不正アクセスや内部不正の兆候を迅速に検知
- **迅速な対応とインシデント管理**：管理者へのアラート通知および対策の支援

これにより、重要インフラ事業者は適切な監視体制を確立し、サイバー攻撃からシステムを防御することが可能になります。

## 3. インストール方法

本サイトからダウンロードした `install.sh` を実行することで、以下の2つのコンテナが自動的にインストールされます。

1. **UEBA ENGコンテナ**：AIエンジンを搭載し、audit.logを解析
2. **MSActivatorコンテナ**：SIEM基盤として動作し、UEBAとの連携を担う

### インストール手順

```bash
chmod +x install.sh
./install.sh
```

上記のコマンドを実行することで、必要なコンテナのダウンロードとセットアップが自動的に行われます。

## 4. 最小要件

本製品を稼働させるための推奨環境は以下の通りです。

- **対応OS**
  - Ubuntu 20.04 以降
  - CentOS 7 以降
  - RHEL 8 以降
  - Debian 11 以降
  - その他主要なLinuxディストリビューション
- **ハードウェア要件**
  - **メモリ**：最低16GB以上
  - **ディスク容量**：最低50GB以上
  - **対応環境**
    - 物理サーバ
    - オンプレミスの仮想マシン
    - クラウド環境（AWS, Azure, GCP等）

## 5. ライセンスおよびダウンロード要件

本製品のダウンロードおよび使用には、以下の要件を満たす必要があります。

- **イメージダウンロード時に必要なToken**
  - 本サイトで配布されるコンテナイメージを取得する際、事前に発行されたダウンロードTokenが必要です。
- **ライセンス要件**
  - **AIエンジンライセンス**：UEBAの解析機能を利用するために必要
  - **MSActivatorライセンス**：SIEM基盤を利用するために必要

## 6. 保守契約について

本製品の使用には、**アクロスゲートグローバルソフトウェア株式会社**との**保守契約**が必要です。

保守契約により、以下のサポートを受けることが可能です。

- 製品の技術サポート
- 定期的なアップデート・セキュリティパッチの提供
- システム運用に関するコンサルティング

詳細については、弊社サポート窓口までお問い合わせください。

## 7. お問い合わせ

本製品に関するご質問やサポート依頼は、以下の連絡先までお問い合わせください。

- **会社名**：アクロスゲートグローバルソフトウェア株式会社
- **サポート窓口**：[support@acrossgate.com](mailto:support@acrossgate.com)
- **ウェブサイト**：[https://www.acrossgate.com](https://www.acrossgate.com)

---

本READMEに記載されている内容は、予告なく変更される場合がありますので、最新の情報は弊社ウェブサイトをご確認ください。


