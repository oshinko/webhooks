import subprocess

from flask import Flask

app = Flask(__name__)


@app.route('/shutdown', methods=['POST'])
def shutdown():
    subprocess.run('shutdown /s /t 120', shell=True)
    return '', 204
