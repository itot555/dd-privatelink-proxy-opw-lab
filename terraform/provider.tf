# us-east-1: PrivateLinkネイティブ対応リージョン（プライマリ）
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = local.common_tags
  }
}

# ap-northeast-1: Cross-Region PrivateLink（enable_ap_northeast_1_network で制御）
provider "aws" {
  alias  = "ap_northeast_1"
  region = "ap-northeast-1"

  default_tags {
    tags = local.common_tags
  }
}

provider "archive" {}
provider "local" {}
provider "random" {}
provider "tls" {}

# api_key / app_key は環境変数 DD_API_KEY / DD_APP_KEY を使う
provider "datadog" {
  api_url = "https://api.${var.dd_site}/"
}
