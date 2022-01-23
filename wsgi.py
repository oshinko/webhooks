import subprocess

from flask import Flask

app = Flask(__name__)


@app.route('/echo/<message>')
def echo(message):
    return message


@app.route('/shutdown', methods=['POST'])
def shutdown():
    subprocess.run('shutdown /s /t 10', shell=True)
    return '', 204
