import boto3
import uuid
import os

s3 = boto3.client('s3')
BUCKET = os.environ['BUCKET_NAME']


def lambda_handler(event, context):
    key = f"images/{uuid.uuid4()}.jpg"

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
        "body": url
    }
