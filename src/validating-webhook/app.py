from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/validate', methods=['POST'])
def validate():
    admission_review = request.get_json()
    uid = admission_review.get("request", {}).get("uid")
    
    allowed = True
    messages = []

    obj = admission_review.get("request", {}).get("object", {})
    spec = obj.get("spec", {})

    # Validate ociBuild: if taggingStrategy is "custom", customTag must be provided.
    oci_build = spec.get("ociBuild", {})
    if oci_build.get("taggingStrategy") == "custom":
        if not oci_build.get("customTag"):
            allowed = False
            messages.append("Validation failed: When taggingStrategy is 'custom', customTag must be provided in ociBuild.")

    # Validate srcRepository: exactly one of externalSecret or existingSecret must be provided.
    src_repo = spec.get("srcRepository", {})
    repo_external = src_repo.get("externalSecret")
    repo_existing = src_repo.get("existingSecret")
    if (repo_external and repo_existing) or (not repo_external and not repo_existing):
        allowed = False
        messages.append("Validation failed: In srcRepository, exactly one of externalSecret or existingSecret must be provided.")

    # Validate ociRegistry: exactly one of externalSecret or existingSecret must be provided.
    oci_registry = spec.get("ociRegistry", {})
    reg_external = oci_registry.get("externalSecret")
    reg_existing = oci_registry.get("existingSecret")
    if (reg_external and reg_existing) or (not reg_external and not reg_existing):
        allowed = False
        messages.append("Validation failed: In ociRegistry, exactly one of externalSecret or existingSecret must be provided.")

    # Build the AdmissionReview response.
    response = {
        "apiVersion": "admission.k8s.io/v1",
        "kind": "AdmissionReview",
        "response": {
            "uid": uid,
            "allowed": allowed,
        }
    }
    
    if not allowed:
        response["response"]["status"] = {
            "message": "; ".join(messages),
            "code": 400
        }
    
    return jsonify(response)

if __name__ == '__main__':
    # In production, serve over TLS with valid certificates.
    app.run(host="0.0.0.0", port=443, ssl_context=('server.crt', 'server.key'))