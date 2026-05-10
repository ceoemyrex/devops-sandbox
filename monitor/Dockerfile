FROM python:3.11-slim

WORKDIR /app
RUN pip install requests

COPY health_poller.py .

CMD ["python", "health_poller.py"]
