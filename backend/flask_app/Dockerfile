FROM python:3.13-slim

WORKDIR /app

COPY backend/flask_app/requirements.txt /app/backend/flask_app/requirements.txt
RUN pip install --no-cache-dir -r /app/backend/flask_app/requirements.txt

COPY . /app

EXPOSE 5000

CMD ["python", "backend/flask_app/app.py"]
