# Image récente et légère
FROM python:3.11-alpine

WORKDIR /app

# Copie propre
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# Création d'un utilisateur sans privilèges
RUN adduser -D appuser
USER appuser

EXPOSE 5000
CMD ["python", "app.py"]