from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/validate', methods=['POST'])
def validate():
    admission_review = request.get_json()
    # Extract the UID from the incoming AdmissionReview request.
    uid = admission_review.get("request", {}).get("uid")
    
    # Default allow is true.
    allowed = True
    message = ""

    # Get the object under review.
    obj = admission_review.get("request", {}).get("object", {})

    # Navigate into the spec to locate ociBuild.
    spec = obj.get("spec", {})
    oci_build = spec.get("ociBuild", {})

    # If taggingStrategy is "custom", enforce that customTag is provided.
    if oci_build.get("taggingStrategy") == "custom":
        custom_tag = oci_build.get("customTag")
        if not custom_tag:
            allowed = False
            message = "Validation failed: When taggingStrategy is 'custom', customTag must be provided in ociBuild."

    # Build the AdmissionReview response.
    response = {
        "apiVersion": "admission.k8s.io/v1",
        "kind": "AdmissionReview",
        "response": {
            "uid": uid,
            "allowed": allowed,
        }
    }
    
    # If the request is denied, include a status message.
    if not allowed:
        response["response"]["status"] = {
            "message": message,
            "code": 400
        }
    
    return jsonify(response)

if __name__ == '__main__':
    # In production, serve over TLS with valid certificates.
    # Replace 'server.crt' and 'server.key' with your certificate and key files.
    app.run(host="0.0.0.0", port=443, ssl_context=('server.crt', 'server.key'))
