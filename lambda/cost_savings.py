#!/usr/bin/python

import boto3
import os

client = boto3.client('ec2')

def start_lambda_handler(event, context):
    _lambda_handler('start')

def stop_lambda_handler(event, context):
    _lambda_handler('stop')

def _lambda_handler(action):
    #Obtain all instances with "save_money" Tag in all region
    instances = []
    for region in client.describe_regions()['Regions']:
        ec2 = boto3.resource('ec2', region_name=region['RegionName'])
        instances = ec2.instances.filter(Filters=[{'Name': 'tag:Status', 'Values': ['save_money']}])
        for instance in instances:
          print("Instance id - ", instance.id)
          print("Instance public IP - ", instance.public_ip_address)
          print("Instance private IP ", instance.private_ip_address)
          print("Region of Machine ", region)
          print("---------------------------------------------------------------------------------------")
          _do_action_on_instances(instance, action)


def _do_action_on_instances(instance, action):
    print ("inicio")
    if action == 'start':
        print('Starting instance: %s ' % (instance ))
        instance.start()
    elif action == 'stop':
        print('Stopping instance: %s ' % (instance ))
        instance.stop()