from flask import Flask, jsonify
import os

app = Flask(__name__)

# Bonne pratique : lecture depuis variable d'environnement, sans valeur par défaut
DB_PASSWORD = os.environ.get("DB_PASSWORD")
if not DB_PASSWORD:
    raise RuntimeError("La variable d'environnement DB_PASSWORD est requise")

@app.route('/')
def home():
    return "Bienvenue sur l'API des Dossiers Médicaux (Version Sécurisée)"

@app.route('/patients')
def get_patients():
    return jsonify([
        {"id": 1, "nom": "Jean Dupont", "maladie": "Diabète type 2"},
        {"id": 2, "nom": "Marie Curie", "maladie": "Irradiation"}
    ])

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)