import boto3
import os

ec2 = boto3.client('ec2', region_name='eu-central-1')
sns = boto3.client('sns', region_name='eu-central-1')

SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')

def lambda_handler(event, context):
    alarm_name = event['detail']['alarmName']
    new_state = event['detail']['state']['value']
    message = f"Alarm {alarm_name} changed state to {new_state}"

    print(message)

    if "cpu" in alarm_name.lower() and new_state == "ALARM":
        instance = ec2.run_instances(
            ImageId='ami-0c3088b424d041ad4',  # Vervang met jouw AMI
            InstanceType='t2.micro',
            KeyName='Project1',
            MinCount=1,
            MaxCount=1,
            SecurityGroupIds=['web-sg-6bfa'], # Vervang met jouw SG
            SubnetId='subnet-04f826d78af6d39df',       # Vervang met jouw subnet
            TagSpecifications=[{'ResourceType':'instance','Tags':[{'Key':'Name','Value':'web-auto-scaled'}]}]
        )
        message += f"\nLaunched new instance: {instance['Instances'][0]['InstanceId']}"

    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=f"[ALERT] {alarm_name}",
        Message=message
    )

    return {'statusCode': 200, 'body': message}
