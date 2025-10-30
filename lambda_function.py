import os
import boto3

sns = boto3.client('sns')

def lambda_handler(event, context):
    message = f"Alarm triggered: {event}"
    topic_arn = os.environ['SNS_TOPIC_ARN']
    sns.publish(TopicArn=topic_arn, Message=message)
    # Eventueel kan hier EC2 upscale logic komen
    return {"status": "ok"}
