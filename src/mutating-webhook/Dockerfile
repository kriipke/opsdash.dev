FROM python:3.9-slim

WORKDIR /app

# Install Python dependencies
COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy the webhook application
COPY app.py app.py

# Expose port 443 (HTTPS)
EXPOSE 443

# Run the webhook server using gunicorn (for production, consider tuning parameters)
CMD ["gunicorn", "--bind", "0.0.0.0:443", "app:app"]
