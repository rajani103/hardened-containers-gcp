import os
import platform

from flask import Flask, jsonify

app = Flask(__name__)


@app.get("/")
def index():
    return jsonify(
        app="cve-demo",
        base_image=os.environ.get("BASE_IMAGE", "unknown"),
        python=platform.python_version(),
        uid=os.getuid(),
    )


@app.get("/healthz")
def healthz():
    return "ok"
