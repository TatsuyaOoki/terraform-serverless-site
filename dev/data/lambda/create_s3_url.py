import boto3
import uuid
import os
import json

s3 = boto3.client('s3')
BUCKET = os.environ['BUCKET_NAME']


def lambda_handler(event, context):
    photo_id = str(uuid.uuid4())
    key = f"images/{photo_id}.jpg"

    url = s3.generate_presigned_url(
        'put_object',
        Params={
            'Bucket': BUCKET,
            'Key': key,
        },
        ExpiresIn=300
    )

    return {
        "statusCode": 200,
        "body": json.dumps(
            {
                "uploadUrl": url,
                "photoId": photo_id,
                "key": key
            }
        )
    }
