FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app.py .

ENV APP_PORT=3000
EXPOSE 3000

CMD ["python", "app.py"]
