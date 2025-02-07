Below is an example of a validating admission webhook written in Python using Flask. This webhook intercepts create and update requests for your `CIPipeline` custom resource and enforces the rule that if `ociBuild.taggingStrategy` is `"custom"`, then `ociBuild.customTag` must be provided. In production, you’d run this server with TLS and proper certificate management. Let’s walk through the code and then discuss how you might deploy it.

Because Kubernetes structural schemas do not support conditional validations (i.e., using constructs such as oneOf), the requirement that customTag must be provided when taggingStrategy is "custom" is only documented in the schema description. To enforce this rule, you should deploy a validating admission webhook that:

Intercepts create and update requests for your CIPipeline custom resource.
Checks the ociBuild section:
If taggingStrategy is set to "custom" and customTag is not provided, the webhook should reject the request.
Otherwise, the request should be allowed.
Returns a clear error message to the user when the validation fails.
This webhook can be implemented in any language or framework that supports Kubernetes admission controllers. It ensures that your custom business logic is enforced even when the CRD OpenAPI schema does not support conditional validation.


---

### Python Admission Webhook Example

```python
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
    # In a production environment, you must serve over TLS with proper certificates.
    # Replace 'server.crt' and 'server.key' with your certificate and key files.
    app.run(host="0.0.0.0", port=443, ssl_context=('server.crt', 'server.key'))
```

---

### How It Works

1. **Request Parsing:**  
   The webhook receives an AdmissionReview object (as a JSON payload) from the Kubernetes API server. The `uid` is extracted from the request to correlate the response with the original request.

2. **Validation Logic:**  
   The webhook checks the `spec.ociBuild` section of the custom resource. If `taggingStrategy` is `"custom"` and `customTag` is missing or empty, the webhook marks the request as not allowed and sets an appropriate error message.

3. **Response Construction:**  
   An AdmissionReview response is built with the same `uid` and the `allowed` field set accordingly. If the validation fails, a status message with an HTTP code (e.g., 400) is included.

4. **Serving the Webhook:**  
   The example uses Flask’s built-in server for simplicity, but for production, you’ll want to run the webhook server behind a more robust WSGI server (like Gunicorn) and serve over HTTPS with valid certificates.

---

### Deployment Considerations

- **TLS & Certificates:**  
  Ensure that your webhook server is running with a valid TLS certificate. In production, you might use Kubernetes Secrets to store certificates and configure your deployment to mount them.

- **Webhook Configuration:**  
  Create a `ValidatingWebhookConfiguration` in Kubernetes that points to your webhook service. This configuration tells the API server when and where to send admission requests for your `CIPipeline` resources.

- **Scaling & Reliability:**  
  For production usage, deploy the webhook as a Kubernetes Deployment and expose it via a Service. Use readiness and liveness probes to ensure the webhook remains healthy.

- **Error Handling & Logging:**  
  Enhance error handling and logging in your webhook so that debugging and operational issues can be addressed promptly.

---

This webhook example should give you a solid starting point to enforce your custom validation logic. You can adjust the logic, error messages, and deployment details based on your operational needs. Happy deploying!
