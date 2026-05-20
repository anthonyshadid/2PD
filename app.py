from flask import Flask, render_template, request, send_file, jsonify
from make_wheel import generate_wheel_stl
import tempfile, os

app = Flask(__name__)

@app.get("/")
def index():
    return render_template("index.html")

@app.post("/generate")
def generate():
    # Allow JSON or form POST
    data = request.get_json(silent=True) or {}
    distances_str = (
        data.get("distances") or
        request.form.get("distances_mm") or
        request.form.get("distances") or
        ""
    )

    try:
        distances = [float(x.strip()) for x in distances_str.split(",") if x.strip()]
    except ValueError:
        return jsonify(error="Distances must be numbers separated by commas."), 400

    if len(distances) != len(set(distances)):
        return jsonify(error="Remove duplicate distance values."), 400

    distances = sorted(distances)

    if len(distances) != 8:
        return jsonify(error="Please enter exactly 8 distances."), 400
    if any(d < 0 for d in distances):
        return jsonify(error="Distances must be 0mm or greater."), 400
    if any(d > 17 for d in distances):
        return jsonify(error="Max allowed distance is 17mm."), 400

    tmpdir = tempfile.mkdtemp()
    output_path = os.path.join(tmpdir, "wheel.stl")

    try:
        generate_wheel_stl(distances, output_stl=output_path)
    except Exception as exc:
        app.logger.exception("Custom STL generation failed")
        return jsonify(error=str(exc)), 500

    return send_file(
        output_path,
        as_attachment=True,
        download_name="2pd_wheel_custom.stl",
        mimetype="model/stl"
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", 5000)), debug=False)
