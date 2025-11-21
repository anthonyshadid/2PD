from flask import Flask, render_template, request, send_file, jsonify
from make_wheel import generate_wheel_stl
import tempfile, os
import io

app = Flask(__name__)

@app.get("/")
def index():
    return render_template("index.html")

@app.post("/generate")
def generate():
    # accept either key just in case
    distances_str = request.form.get("distances_mm") or request.form.get("distances") or ""
    try:
        distances = [float(x.strip()) for x in distances_str.split(",") if x.strip()]
    except ValueError:
        return jsonify(error="Distances must be numbers separated by commas."), 400

    distances = sorted(set(distances))

    if len(distances) < 2:
        return jsonify(error="Please enter at least two distances."), 400
    if any(d <= 0 for d in distances):
        return jsonify(error="All distances must be > 0."), 400
    if any(d > 30 for d in distances):
        return jsonify(error="Max allowed distance is 30mm."), 400

    tmpdir = tempfile.mkdtemp()
    output_path = os.path.join(tmpdir, "wheel.stl")

    generate_wheel_stl(distances, output_stl=output_path)

    return send_file(
        output_path,
        as_attachment=True,
        download_name="2pd_wheel.stl",
        mimetype="model/stl"
    )

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", 5000)), debug=False)
