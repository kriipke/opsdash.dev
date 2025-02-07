from flask import Flask, request, jsonify
import base64
import json

app = Flask(__name__)

def mutate_pipeline(resource):
    # Remove the unified preBuildSteps array and redistribute its items
    spec = resource.get("spec", {})
    pre_build_steps = spec.pop("preBuildSteps", [])
    linters = []
    code_reviews = []
    custom_steps = []
    secret_scans = []
    job_number = 1

    for step in pre_build_steps:
        step["jobNumber"] = job_number
        job_number += 1
        step_type = step.get("type")
        if step_type == "Linter":
            linters.append(step)
        elif step_type == "CodeReview":
            code_reviews.append(step)
        elif step_type == "CustomStep":
            custom_steps.append(step)
        elif step_type == "SecretScan":
            secret_scans.append(step)

    if linters:
        spec["linters"] = linters
    if code_reviews:
        spec["codeReviews"] = code_reviews
    if custom_steps:
        spec["customSteps"] = custom_steps
    if secret_scans:
        spec["secretScans"] = secret_scans

    resource["spec"] = spec
    return resource

@app.route('/mutate', methods=['POST'])
def mutate():
    admission_review = request.get_json()
    uid = admission_review.get("request", {}).get("uid")
    resource = admission_review.get("request", {}).get("object", {})

    # Perform the mutation
    mutated_resource = mutate_pipeline(resource)

    # Log the mutated resource for debugging purposes
    app.logger.info("Mutated resource: %s", json.dumps(mutated_resource, indent=2))

    # In a real webhook, you would calculate and return a JSONPatch.
    # For simplicity, we return an empty patch and assume the webhook server applies the changes.
    response = {
        "apiVersion": "admission.k8s.io/v1",
        "kind": "AdmissionReview",
        "response": {
            "uid": uid,
            "allowed": True,
            "patchType": "JSONPatch",
            "patch": base64.b64encode(b'[]').decode('utf-8')
        }
    }
    return jsonify(response)

if __name__ == '__main__':
    # For production, serve over HTTPS with valid certificates.
    # Replace 'server.crt' and 'server.key' with your certificate and key files.
    app.run(host='0.0.0.0', port=443, ssl_context=('server.crt', 'server.key'))
