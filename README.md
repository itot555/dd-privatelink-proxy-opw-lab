# dd-privatelink-proxy-opw-lab

AWS 上で Datadog を検証するための、Terraform `apply` 一回で完結する Sandbox です。

Git 操作（init / commit / push）と実 AWS への apply は、この README を読んだ利用者が行います。

構成図: [architecture.html](architecture.html)

> **apply の前に [利用上の注意](#利用上の注意) を必ず読んでください。** 実際の AWS 課金が発生し、放置すると月額数百 USD 規模になります。

## 再現対象

- Tenant VPC + Proxy VPC（二層）
- Datadog US1 PrivateLink
- Squid Proxy（Metrics / DBM / Process）
- Observability Pipelines Worker（Logs / Traces、オプション）
- CloudFront → ALB → Frontend / Java / Python → RDS
- Java SSI、Python OTel SDK + DDOT、Synthetics Private Location、任意の banking demo

公式ドキュメント:

- [Connect to Datadog over AWS PrivateLink](https://docs.datadoghq.com/agent/guide/private-link/?site=us)
- [Agent proxy (Squid)](https://docs.datadoghq.com/agent/configuration/proxy_squid/?tab=linux)
- [Datadog Agent as Observability Pipelines source](https://docs.datadoghq.com/observability_pipelines/sources/datadog_agent/)

## アーキテクチャ概要

```text
[Browser] --HTTPS--> [CloudFront] --> [Internet ALB]          Tenant VPC 10.100.0.0/16
                           |                |
                    [Frontend]  [Java] --> [Python] --> [RDS]
                                         | PL Worker
                                         v
                              [Tenant Interface VPC EP DNS]
                                         |  PrivateLink
                              [Proxy NLB :3128 / :8282 / :8484]  Proxy VPC 10.110.0.0/16
                                   /          |          \
                            Squid :3128    OPW :8282   OPW :8484
                                   \          |          /
                              Datadog US1 PrivateLink
                                        |
                                     Datadog SaaS
```

| 信号 | 経路 | NLB ポート | 制御変数 |
|------|------|-----------|---------|
| Metrics / DBM / Process | Agent `proxy.*` → Squid → PrivateLink | 3128 | 常時 |
| Logs | Agent OPW → OPW Worker → PrivateLink | 8282 | `enable_opw_logs` |
| Traces (APM) | Agent OPW → OPW Worker → PrivateLink | 8484 | `enable_opw_traces` |

## 識別子

| 用途 | 値 |
|------|-----|
| GitHub レポ | `dd-privatelink-proxy-opw-lab`（AWS リソース名には使わない） |
| `project_name` | 未指定時 `dd-` + 英小文字 3 文字（例: `dd-k7m`）。最大 12 文字 |
| `dd_env` | `dd-lab`（hostname 例: `dd-lab-java-0`） |
| DB / ユーザー | `demodb` / `dbadmin` / `dbapp` |
| Java パッケージ | `com.example.ddlab` |
| banking ログイン | `demo_user`（パスワードは tfvars の `demo_bank_password`） |

`project_name` にレポ名を入れると ALB / NLB / Target Group の 32 文字上限を超えます。

出典: [CreateLoadBalancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/APIReference/API_CreateLoadBalancer.html)

## 利用上の注意

### 位置づけと免責

このリポジトリは Datadog の機能検証を目的とした **Sandbox** です。本番環境の参照アーキテクチャではありません。現状有姿で提供し、動作・可用性・セキュリティについて保証しません。実行によって生じた AWS / Datadog の課金や障害は、利用者の責任となります。自分が管理する検証用アカウントで実行してください。

**Datadog の公式製品ではありません。** Datadog のサポート対象外であり、内容について Datadog は一切の責任を負いません。不具合や質問を Datadog サポートへ問い合わせないでください。

法的な利用条件は [LICENSE](LICENSE)（Apache License 2.0）に従います。無保証（Section 7）と責任制限（Section 8）が定められています。

### AWS コスト

トラフィックが無くても、リソースが存在するだけで課金される要素があります。主な固定費は次のとおりです。

| 要素 | 数量（default） | 備考 |
|------|----------------|------|
| Datadog PrivateLink Interface Endpoint | 16 サービス × 2 AZ = 32 ENI | 最大の固定費 |
| Tenant → Proxy Interface Endpoint | 1 サービス × 2 AZ = 2 ENI | |
| NAT Gateway | 2 基（Tenant / Proxy 各 1） | `single_nat_gateway = true` |
| ALB / NLB | 各 1 | LCU 課金あり |
| CloudFront | 1 ディストリビューション | |
| RDS | `db.t4g.micro` × 1 | Single-AZ |
| EC2 | 4〜5 台（`t3.small` / `t3.medium`） | OPW 有効時に増加 |

us-east-1 の Interface Endpoint は **1 ENI × 1 AZ あたり $0.01/時間** なので、PrivateLink の 34 ENI だけで約 $0.34/時間（月額 $240 前後）になります。NAT Gateway・ロードバランサ・EC2・RDS を合わせると、24 時間稼働で **月額数百 USD 規模** です。

コストを抑える方法:

- 使わない間は `terraform destroy` する（この Lab は `enable_force_destroy = true` が default なので削除しやすい構成です）
- `enable_opw_logs` / `enable_opw_traces` を `false` のままにする（OPW EC2 を作らない）
- `dd_privatelink_services` を tfvars で上書きし、検証に必要なサービスだけに絞る（16 個すべては通常不要）

出典: [AWS PrivateLink Pricing](https://aws.amazon.com/privatelink/pricing/) / [Amazon VPC Pricing（NAT Gateway）](https://aws.amazon.com/vpc/pricing/) / [Elastic Load Balancing Pricing](https://aws.amazon.com/elasticloadbalancing/pricing/) / [Amazon EC2 On-Demand Pricing](https://aws.amazon.com/ec2/pricing/on-demand/)

### Datadog コスト

Agent を入れた EC2 はインフラホストとして課金対象になります。APM / Logs / RUM / Synthetics / DBM も、それぞれインジェスト量やテスト実行数に応じて課金されます。Synthetics Private Location は Worker が常駐し、テストが継続実行されます。検証が終わったら `terraform destroy` でまとめて削除してください。

出典: [Billing](https://docs.datadoghq.com/account_management/billing/) / [Synthetics Private Locations](https://docs.datadoghq.com/synthetics/private_locations/)

### 制約

- **Datadog Site は US1（`datadoghq.com`）のみ**。他 Site の VPC Endpoint Service ID は異なるため、そのままでは動作しません
- **メインリージョンは `us-east-1` 固定**。Datadog US1 の PrivateLink エンドポイントサービスが us-east-1 に提供されているためです
- `ap-northeast-1` は Cross-Region PrivateLink のネットワーク基盤のみで、コンピュートは未実装です（`enable_ap_northeast_1_compute`）
- Tenant VPC `10.100.0.0/16` と Proxy VPC `10.110.0.0/16` を使います。既存 VPC と CIDR が重なる場合は `vpc_cidr_us_east_1` / `vpc_cidr_proxy_us_east_1` を変更してください
- EIP・VPC・Interface Endpoint などは AWS のサービスクォータ上限に達すると apply が失敗します

出典: [Connect to Datadog over AWS PrivateLink](https://docs.datadoghq.com/agent/guide/private-link/?site=us)

### 本番構成との違い

検証を簡単にするため、本番では推奨されない選択をしている箇所があります。そのまま本番へ流用しないでください。

- Datadog **API Key を `terraform.tfvars` に平文で記載**します（Secrets Manager へ保存されますが、tfvars 自体はローカルの平文ファイルです）
- ALB は CloudFront からの **HTTP のみ**を受けます（ALB 自体に ACM 証明書を付けていません）
- RDS は `multi_az = false`、`backup_retention_period = 1`、`deletion_protection = false`、`skip_final_snapshot = true` です。destroy 時に最終スナップショットを取らずに消えます
- `enable_force_destroy = true` が default です。削除は容易ですが、誤操作でデータが消えます
- Terraform state は **ローカルファイル**です。`project_name` は apply ごとにランダムな接尾辞が付くため、state を失うと孤児リソースの特定が困難になります。共有・継続利用するならリモートバックエンドを設定してください
- banking demo は、マスキング検証のため架空の個人情報を**意図的にテレメトリへ送信**します
- banking demo の RDS は `bank_users.password_plain` に**パスワードを平文で保存**します。ログイン処理と DBM のクエリサンプルをそのまま観測できるようにするための意図的な設計です。ハッシュ化していないため、実在のパスワードを `demo_bank_password` に設定しないでください

出典: [Terraform Backend Configuration](https://developer.hashicorp.com/terraform/language/backend)

## 前提

- AWS アカウントと `us-east-1` への権限
- AWS CLI（認証情報のローカル設定に使用）
- Datadog Site **US1**（`datadoghq.com`）
- Terraform CLI **1.10 以上**（`terraform/terraform.tf` の `required_version = "~> 1.10"`）
- Datadog **Application Key** は Provider 用に環境変数へ設定する
- Datadog **API Key** は Agent 用に `terraform.tfvars` へ記載する（推奨ではないが、この Lab は簡単に始められる方法を選ぶ）

### Terraform CLI

未導入の場合は、公式手順でインストールします。この Lab は Terraform **1.10 以上** を想定しています。

出典: [Install Terraform](https://developer.hashicorp.com/terraform/install)

macOS（Homebrew）の例:

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

確認:

```bash
terraform version
```

`Terraform v1.10` 以上であれば進めてください。Linux / Windows は上記公式ページのインストーラまたはパッケージ手順を使います。

### AWS 認証情報（ローカル）

Terraform AWS Provider は、AWS CLI と同じ認証チェーンを使います。この Lab では **アクセスキーを `terraform.tfvars` に書かず**、マシン上の共有認証ファイルへ置きます。

出典:

- [Configuration and credential file settings](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)
- [Environment variables to configure the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html)
- [Terraform AWS Provider: Authentication](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration)

```bash
aws configure
```

対話入力の例:

| 項目 | 値 |
|------|-----|
| AWS Access Key ID | IAM ユーザーまたは SSO から発行したアクセスキー |
| AWS Secret Access Key | 対応するシークレットアクセスキー |
| Default region name | `us-east-1` |
| Default output format | `json`（任意） |

これで `~/.aws/credentials` と `~/.aws/config` に保存されます。このファイルは Git に含めないでください。

プロファイルを分ける場合:

```bash
aws configure --profile dd-lab
export AWS_PROFILE=dd-lab
```

一時クレデンシャル（SSO / assume role）を使う場合は、セッション後に次のいずれかで渡せます。

```bash
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."   # 一時キーのときのみ
export AWS_DEFAULT_REGION=us-east-1
```

設定確認:

```bash
aws sts get-caller-identity --region us-east-1
```

### Datadog 認証情報

```bash
export DD_API_KEY="..."
export DD_APP_KEY="..."
```

Provider は環境変数 `DD_API_KEY` / `DD_APP_KEY` を読みます。Agent 側キーは `dd_api_key` として Secrets Manager に保存されます。

## セットアップ

```bash
cd terraform
cp locals.tf.example locals.tf
cp terraform.tfvars.example terraform.tfvars
```

`locals.tf` で AWS タグ（`Owner` など）を必要なら調整します。計算用 local は消さないでください。

`terraform.tfvars` で少なくとも次を設定します。

- `dd_api_key`
- `allowed_ip` / `office_ip`（`0.0.0.0/32` はプレースホルダ。自分のグローバル IP に置き換える）
- `private_location_team`（自組織の Datadog Team handle）
- `demo_bank_password`

RUM を使う場合は、apply の前に [RUM](#rum) の事前準備が必要です。

```bash
terraform init
terraform apply
```

通常手順に手動 SSH や apply 後の設定編集は含めません。確認手順は `terraform output`（`verification_steps` など）を使います。

適用後の接頭辞は次で確認できます。

```bash
terraform output project_name
```

## Sandbox サイジング（本番推奨値ではない）

この Lab は検証用に縮小しています。Datadog 本番の Agent / OPW / Proxy サイジングは公式ドキュメントに従ってください。

| コンポーネント | default | 備考 |
|---------------|---------|------|
| Frontend EC2 | `t3.small` | Agent |
| Java EC2 | `t3.medium` | SSI + Private Location Worker |
| Python EC2 | `t3.medium` | OTel SDK + DDOT + DBM |
| Squid | `t3.small` × 1（最大 10） | Metrics / DBM / Process |
| OPW | `t3.medium` × 1（最大 10） | Logs / Traces（オプション） |
| RDS | `db.t4g.micro` Single-AZ | 暗号化あり |

## 削除

`enable_force_destroy` の default は `true` です。

```bash
cd terraform
terraform destroy
```

Datadog 側に残る Synthetics / Private Location は、Terraform が作成したものなら destroy で消えます。手動作成した Pipeline は Datadog UI で別途削除してください。

## セキュリティ上の注意

- `terraform.tfvars`、`locals.tf`、`*.tfstate`、`terraform/keys/` は Git 管理しません
- AWS アクセスキーは `~/.aws/credentials` または環境変数に置き、リポジトリへ書かないでください
- 顧客名・個人のメールや IP・API Key をソースに書かないでください
- ALB は CloudFront プレフィックスリストからの HTTP のみ許可します

## banking demo

`enable_banking_demo = true`（default）のとき、ログイン ID は `demo_user` です。パスワードは `demo_bank_password` です。名義は `デモ太郎` / 振込先 `デモ花子` の架空データで、APM / Logs のマスキング検証用に意図的にテレメトリへ載せます。

## RUM

RUM は default で無効（`enable_rum = false`）です。有効化する場合は、**apply の前に Datadog UI で RUM アプリケーションを作成する必要があります**。Browser SDK の `applicationId` と `clientToken` はアプリケーションを作らないと発行されないためです（OPW を使う場合の `opw_pipeline_id` と同様、事前作成が必要な値です）。

### 1. Datadog で RUM アプリケーションを作成する

1. Datadog にログインし、[**Digital Experience > Add an Application**](https://app.datadoghq.com/rum/list) を開く
2. アプリケーションタイプで **JavaScript (JS)** を選ぶ
3. 任意の名前（例: `dd-lab-banking-ui`）を入力して **Create Application** をクリックする
4. 発行された **Application ID** と **Client Token** を控える

この後に SDK のインストール手順が表示されますが、**コードへの組み込みは実装済み**（`apps/banking-ui/src/rum.ts`）なので、コピーする必要はありません。ID と Token だけ使います。

出典: [Browser Monitoring Setup](https://docs.datadoghq.com/real_user_monitoring/browser/setup/)

### 2. tfvars に設定する

```hcl
enable_banking_demo = true
enable_rum          = true
rum_application_id  = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
rum_client_token    = "pubxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

`enable_banking_demo = true` が前提です。RUM の計測対象は banking demo の React SPA なので、`false` のままだと `enable_rum = true` にしても RUM は組み込まれません。

### 3. apply して確認する

```bash
terraform apply
```

Frontend EC2 は `user_data_replace_on_change = true` のため置き換えられ、userdata 内の Vite ビルド時に `VITE_RUM_APPLICATION_ID` などとして値が埋め込まれます。apply 後に CloudFront の URL をブラウザで開き、[RUM Explorer](https://app.datadoghq.com/rum/list) にセッションが届けば成功です。

```bash
terraform output application_urls
```

Datadog 上では `service:dd-lab-banking-ui`、`env` は `dd_env`、`version` は `dd_version` の値で送信されます。

### 注意

- **RUM のデータは PrivateLink を通りません。** Browser SDK は利用者のブラウザ（VPC 外）で動くため、`rum.browser-intake-datadoghq.com` へ公衆インターネット経由で直接送信されます。この Lab の PrivateLink 経路の検証対象は、あくまで VPC 内の Agent が送るテレメトリです
- Client Token はブラウザに埋め込まれる公開前提の値ですが、Application ID ともども `terraform.tfvars`（Git 管理外）に置いてください
- **Session Replay が有効**です（`sessionReplaySampleRate: 20`）。セッションの録画が Datadog に送られ、課金対象になります。不要なら `apps/banking-ui/src/rum.ts` の値を `0` にしてください
- `defaultPrivacyLevel: "mask-user-input"` で入力値はマスクされますが、banking demo は架空の個人情報を意図的に送信します
- RUM から APM へのトレース相関は `allowedTracingUrls` で同一 origin に `tracecontext` を注入して実現しています。CloudFront 経由で `/api/*` を叩く構成が前提です

## ライセンス

[Apache License 2.0](LICENSE) で公開しています。利用・改変・再配布が可能ですが、**無保証**であり、利用によって生じた損害について作者は責任を負いません。詳細は [利用上の注意](#利用上の注意) を参照してください。

出典: [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0)
