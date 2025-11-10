from flask import Flask, render_template, request, send_file
from make_wheel import generate_wheel_stl
import tempfile, os

app = Flask(__name__)

@app.route("/", methods=["GET", "POST"])
def index():
    if request.method == "POST":
        distances_str = request.form["distances"]
        distances = [float(x.strip()) for x in distances_str.split(",") if x.strip()]
        tmpdir = tempfile.mkdtemp()
        output_path = os.path.join(tmpdir, "wheel.stl")
        generate_wheel_stl(distances, output_stl=output_path)
        return send_file(output_path, as_attachment=True, download_name="wheel.stl")
    return render_template("index.html")

if __name__ == "__main__":
    # local dev only; Render uses gunicorn from Dockerfile CMD
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", 5000)), debug=False)
