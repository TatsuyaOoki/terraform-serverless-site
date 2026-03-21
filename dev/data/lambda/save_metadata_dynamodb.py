import boto3
import uuid
import json
import os
from datetime import datetime, timezone

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

def lambda_handler(event, context):
    body = json.loads(event['body'])

    item = {
        "userId": "tatsuya",
        "photoId": body["photoId"],
        "imageUrl": body["imageUrl"],
        "title": body.get("title", ""),
        "createdAt": datetime.now(timezone.utc).isoformat()
    }

    table.put_item(Item=item)

    return {
        "statusCode": 200,
        "body": json.dumps({"message": "Saved metadata to DynamoDB"})
    }
