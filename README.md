# Terraform Serverless個人用アルバムアプリ

## 使用サービス

- API Gateway
- Lambda
- S3
- DynamoDB

## 構成図

## 使用方法

1. tfstateファイルを保存するS3バケットを作成\
   作成後は`provider.tf`の`backend`の値を置き換える

2. aws cliの認証情報を設定\
   `aws configure --profile terraform`コマンドでアクセスキー及びシークレットキーを設定する

3. デプロイ
   ```
   terraform plan # 作成されるリソースの確認
   terraform apply # デプロイ
   ```
