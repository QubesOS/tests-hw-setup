#!/usr/bin/python3
import importlib.util
import pathlib
import subprocess
import sys
import os
import re
import json
import time
import requests
import tempfile
import string
import hmac
from jinja2 import Environment, BaseLoader
from flask import Flask, request, Response, render_template_string

from testbed.control import Testbed, User

app = Flask(__name__)

@app.route('/api/render_file', methods=['GET'])
def render_file():
    template = request.args.get('template')
    if not template:
        return "Missing 'template' parameter", 400
    if not template.endswith('.jinja'):
        return "Wrong file", 403
    original_ip = request.headers.get('X-Forwarded-For')
    if not original_ip:
        return "Missing X-Forwarded-For", 403
    match = re.match(r"\A172\.16\.(\d+)\.\d+\Z", original_ip)
    if not match:
        return "Wrong X-Forwarded-For", 403
    hostid = match.group(1)
    host = Testbed(int(hostid))

    ssh_keys = host.get_selected_ssh_keys().splitlines()
    # always add CI user keys
    ci_user = User(f"ci-{hostid}")
    ssh_keys.extend(ci_user.get_user_ssh_keys())

    with open(template) as f:
        return render_template_string(f.read(), ssh_keys=ssh_keys)

if __name__ == '__main__':
    #main()
    app.run(debug=True)
