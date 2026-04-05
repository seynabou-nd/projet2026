"""
VenteBot — Squelette Backend FastAPI
Projet SRT L3 — ESP/UCAD
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import mysql.connector
import os
import re
import httpx
import json

app = FastAPI(title="VenteBot API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Configuration ──────────────────────────────────────────────
DB_CONFIG = {
    "host":     os.getenv("DB_HOST", "localhost"),
    "user":     os.getenv("DB_USER", "root"),
    "password": os.getenv("DB_PASSWORD", ""),
    "database": os.getenv("DB_NAME", "ventebot"),
}

LLM_API_KEY  = os.getenv("OPENAI_API_KEY", "")
LLM_MODEL    = os.getenv("LLM_MODEL", "gpt-4o-mini")
LLM_BASE_URL = os.getenv("LLM_BASE_URL", "https://api.openai.com/v1")

# ── Schéma de la base ──────────────────────────────────────────
DB_SCHEMA = """
Tables MySQL disponibles :

categories(id, nom, description)
produits(id, reference, nom, categorie_id, prix_achat, prix_vente, stock_actuel, stock_minimum, unite, actif)
fournisseurs(id, nom, email, telephone, delai_livraison_jours, actif)
clients(id, nom, email, telephone, ville, type_client[particulier/entreprise/grossiste], credit_max)
commandes(id, reference, client_id, date_commande, date_livraison, statut[en_attente/confirmee/expediee/livree/annulee], mode_paiement[cash/virement/credit/mobile_money], statut_paiement[non_paye/partiel/paye], total)
lignes_commande(id, commande_id, produit_id, quantite, prix_unitaire, remise_pct)
mouvements_stock(id, produit_id, type[entree/sortie/ajustement], quantite, reference_doc, motif, date_mouvement)
"""

SYSTEM_PROMPT = f"""Tu es VenteBot, l'assistant IA d'une PME commerciale sénégalaise.
Tu aides les gestionnaires à interroger la base de données et à effectuer des actions métier.

{DB_SCHEMA}

Tu peux répondre à deux types de demandes :
1. CONSULTATION : Requête SQL pour afficher des données
2. ACTION : Créer/modifier des enregistrements (commandes, etc.)

Réponds TOUJOURS en JSON :
Pour une consultation :
{{"type": "query", "sql": "SELECT ...", "explication": "..."}}

Pour une action :
{{"type": "action", "action": "create_order|update_stock", "data": {{}}, "explication": "..."}}

Pour une question sans données :
{{"type": "info", "sql": null, "explication": "Réponse directe..."}}

RÈGLES :
- Requêtes SELECT : LIMIT 100 maximum
- Calcul du CA : SUM(total) sur commandes WHERE statut_paiement='paye'
- Rupture de stock : WHERE stock_actuel <= stock_minimum
- Toujours en français, ton professionnel mais accessible
"""

# ── Connexion MySQL ────────────────────────────────────────────
def get_db():
    return mysql.connector.connect(**DB_CONFIG)

def execute_query(sql: str):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute(sql)
        return cursor.fetchall()
    finally:
        cursor.close()
        conn.close()

def execute_write(sql: str, params: tuple = ()):
    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute(sql, params)
        conn.commit()
        return cursor.lastrowid
    finally:
        cursor.close()
        conn.close()

# ── Appel LLM ─────────────────────────────────────────────────
async def ask_llm(question: str, history: list = []) -> dict:
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    messages += history
    messages.append({"role": "user", "content": question})

    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{LLM_BASE_URL}/chat/completions",
            headers={"Authorization": f"Bearer {LLM_API_KEY}"},
            json={"model": LLM_MODEL, "messages": messages, "temperature": 0},
            timeout=30,
        )
        response.raise_for_status()
        content = response.json()["choices"][0]["message"]["content"]
        match = re.search(r'\{.*\}', content, re.DOTALL)
        if match:
            return json.loads(match.group())
        raise ValueError("Réponse LLM invalide")

# ── Routes API ─────────────────────────────────────────────────
class ChatMessage(BaseModel):
    question: str
    history: list = []

@app.post("/api/chat")
async def chat(msg: ChatMessage):
    """Point d'entrée principal : question → SQL/Action → résultats"""
    try:
        llm_response = await ask_llm(msg.question, msg.history)
        response_type = llm_response.get("type", "info")
        explication = llm_response.get("explication", "")

        if response_type == "query":
            sql = llm_response.get("sql")
            if not sql:
                return {"answer": explication, "data": [], "type": "info"}
            data = execute_query(sql)
            return {"answer": explication, "data": data, "sql": sql, "count": len(data), "type": "query"}

        elif response_type == "action":
            # TODO : implémenter les actions (créer commande, ajuster stock...)
            return {"answer": f"Action détectée : {llm_response.get('action')} — {explication}", "type": "action"}

        else:
            return {"answer": explication, "data": [], "type": "info"}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/dashboard")
def dashboard():
    """Indicateurs clés du tableau de bord"""
    stats = {}
    queries = {
        "ca_total":          "SELECT COALESCE(SUM(total),0) as n FROM commandes WHERE statut_paiement='paye'",
        "commandes_en_cours":"SELECT COUNT(*) as n FROM commandes WHERE statut IN ('en_attente','confirmee','expediee')",
        "ruptures_stock":    "SELECT COUNT(*) as n FROM produits WHERE stock_actuel <= stock_minimum AND actif=TRUE",
        "nb_clients":        "SELECT COUNT(*) as n FROM clients",
        "ca_mois":           "SELECT COALESCE(SUM(total),0) as n FROM commandes WHERE MONTH(date_commande)=MONTH(NOW()) AND statut_paiement='paye'",
    }
    for key, sql in queries.items():
        result = execute_query(sql)
        stats[key] = result[0]["n"] if result else 0
    return stats

@app.get("/api/produits/ruptures")
def ruptures():
    """Produits en rupture ou proche du seuil"""
    return execute_query("""
        SELECT p.*, c.nom as categorie
        FROM produits p
        LEFT JOIN categories c ON p.categorie_id = c.id
        WHERE p.stock_actuel <= p.stock_minimum AND p.actif = TRUE
        ORDER BY p.stock_actuel ASC
    """)

@app.get("/api/commandes/recentes")
def commandes_recentes():
    return execute_query("""
        SELECT c.*, cl.nom as client_nom, cl.type_client
        FROM commandes c
        JOIN clients cl ON c.client_id = cl.id
        ORDER BY c.date_commande DESC
        LIMIT 20
    """)

@app.get("/api/clients/top")
def top_clients():
    return execute_query("""
        SELECT cl.nom, cl.type_client, cl.ville,
               COUNT(c.id) as nb_commandes,
               SUM(c.total) as total_achats
        FROM clients cl
        LEFT JOIN commandes c ON cl.id = c.client_id AND c.statut_paiement='paye'
        GROUP BY cl.id
        ORDER BY total_achats DESC
        LIMIT 10
    """)

@app.get("/health")
def health():
    return {"status": "ok", "app": "VenteBot"}

# ── Lancement ─────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="0.0.0.0", port=8001, reload=True)
