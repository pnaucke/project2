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
        print("CPU alarm triggered, provisioning new webserver...")
        instance = ec2.run_instances(
            ImageId='ami-0abcdef1234567890',
            InstanceType='t2.micro',
            KeyName='Project1',
            MinCount=1,
            MaxCount=1,
            SecurityGroupIds=['sg-xxxxxxxx'],
            SubnetId='subnet-xxxxxxxx',
            TagSpecifications=[{'ResourceType':'instance','Tags':[{'Key':'Name','Value':'web-auto-scaled'}]}]
        )
        message += f"\nLaunched new instance: {instance['Instances'][0]['InstanceId']}"

    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=f"[ALERT] {alarm_name}",
        Message=message
    )

    return {'statusCode': 200, 'body': message}
