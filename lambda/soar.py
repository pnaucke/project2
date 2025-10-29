import boto3
import json
import os

ec2 = boto3.client('ec2')

def lambda_handler(event, context):
    instance_id = event.get("instance_id")
    if instance_id:
        status = ec2.describe_instance_status(InstanceIds=[instance_id], IncludeAllInstances=True)
        state = status['InstanceStatuses'][0]['InstanceState']['Name']
        if state != 'running':
            ec2.start_instances(InstanceIds=[instance_id])
            return {"message": f"Instance {instance_id} started"}
    return {"message": "No action needed"}
