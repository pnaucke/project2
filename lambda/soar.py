import boto3
import os

# AWS client
ec2 = boto3.client('ec2', region_name=os.environ.get('AWS_REGION', 'eu-central-1'))

# Webserver instance IDs (pas aan met jouw echte instance IDs)
WEB_INSTANCES = [
    'i-0b92f57df1b307027',  # web1
    'i-03e0dfe0df4a8bba2'   # web2
]

def lambda_handler(event, context):
    """
    Check status of webservers and start/restart if needed.
    """
    response = ec2.describe_instance_status(InstanceIds=WEB_INSTANCES, IncludeAllInstances=True)
    for instance in response['InstanceStatuses']:
        instance_id = instance['InstanceId']
        state = instance['InstanceState']['Name']
        
        if state != 'running':
            print(f"Instance {instance_id} is {state}. Starting...")
            ec2.start_instances(InstanceIds=[instance_id])
        else:
            print(f"Instance {instance_id} is running.")
    
    return {
        'statusCode': 200,
        'body': 'SOAR check complete.'
    }