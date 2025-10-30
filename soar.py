import json
import boto3
import os

# AWS clients
sns = boto3.client('sns')
autoscaling = boto3.client('autoscaling')
ses = boto3.client('ses')

# Environment variables (instellen in Lambda)
# ALERT_EMAIL = email waar meldingen naartoe gaan
# SCALE_UP_GROUP = naam van autoscaling group
ALERT_EMAIL = os.environ.get('ALERT_EMAIL', 'beheerder@example.com')
SCALE_UP_GROUP = os.environ.get('SCALE_UP_GROUP', '')

def lambda_handler(event, context):
    """
    Lambda SOAR handler:
    - Webserver down -> stuur mail
    - CPU > 80% -> schaal op & stuur mail
    """
    print("Event received:", json.dumps(event))

    alarm_name = event.get('detail', {}).get('alarmName', '')
    new_state = event.get('detail', {}).get('state', {}).get('value', '')

    # Als alarm niet in event, exit
    if not alarm_name or not new_state:
        print("Geen alarm details gevonden")
        return

    # Bepaal actie op basis van alarm
    if 'cpu-high' in alarm_name.lower() and new_state == 'ALARM':
        message = f"CPU alarm: {alarm_name} - CPU > 80%"
        print(message)
        send_email("CPU Alarm", message)
        scale_up()
    elif 'down' in alarm_name.lower() and new_state == 'ALARM':
        message = f"Webserver down alarm: {alarm_name}"
        print(message)
        send_email("Webserver Down", message)
    else:
        print("Geen actie nodig voor alarm:", alarm_name)

def send_email(subject, body):
    """
    Verstuur e-mail via AWS SES
    """
    try:
        response = ses.send_email(
            Source=ALERT_EMAIL,
            Destination={'ToAddresses': [ALERT_EMAIL]},
            Message={
                'Subject': {'Data': subject},
                'Body': {'Text': {'Data': body}}
            }
        )
        print("E-mail verzonden:", response['MessageId'])
    except Exception as e:
        print("Fout bij verzenden e-mail:", e)

def scale_up():
    """
    Schaal de autoscaling group op met 1 instance
    """
    if not SCALE_UP_GROUP:
        print("Geen autoscaling group ingesteld, scaling skipped")
        return
    try:
        response = autoscaling.set_desired_capacity(
            AutoScalingGroupName=SCALE_UP_GROUP,
            DesiredCapacity=get_current_capacity(SCALE_UP_GROUP) + 1,
            HonorCooldown=False
        )
        print("Autoscaling verhoogd:", response)
    except Exception as e:
        print("Fout bij autoscaling:", e)

def get_current_capacity(asg_name):
    """
    Huidige capaciteit ophalen van ASG
    """
    try:
        response = autoscaling.describe_auto_scaling_groups(
            AutoScalingGroupNames=[asg_name]
        )
        current = response['AutoScalingGroups'][0]['DesiredCapacity']
        print(f"Huidige capaciteit {asg_name}: {current}")
        return current
    except Exception as e:
        print("Fout bij ophalen ASG capaciteit:", e)
        return 0
