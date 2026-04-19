from flask import Flask, jsonify
import os

app = Flask(__name__)

# Mauvaise pratique : mot de passe en dur
DB_PASSWORD = os.environ.get("DB_PASSWORD", "SuperSecretAdmin123!")

@app.route('/')
def home():
    return "Bienvenue sur l'API des Dossiers Médicaux (Version Vulnérable)"

@app.route('/patients')
def get_patients():
    return jsonify([
        {"id": 1, "nom": "Jean Dupont", "maladie": "Diabète type 2"},
        {"id": 2, "nom": "Marie Curie", "maladie": "Irradiation"}
    ])

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)