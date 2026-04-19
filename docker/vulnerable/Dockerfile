# Image obsolète
FROM python:3.6-slim

# Fuite de secrets
ENV AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
ENV AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
ENV DB_PASSWORD="MotDePasseEnClair123!"

WORKDIR /app

# On copie tout aveuglément
COPY . .

RUN pip install -r requirements.txt

EXPOSE 5000
CMD ["python", "app.py"]