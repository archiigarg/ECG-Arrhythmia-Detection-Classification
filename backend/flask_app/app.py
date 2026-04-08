import os
from pathlib import Path
from functools import wraps

import requests
from authlib.integrations.flask_client import OAuth
from dotenv import load_dotenv
from flask import Flask, jsonify, redirect, request, send_from_directory, session, url_for


# -----------------------------
# Paths
# -----------------------------

APP_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = APP_DIR.parents[1]
DASHBOARD_DIR = PROJECT_ROOT / "frontend" / "dashboard"


# -----------------------------
# Load environment variables
# -----------------------------

load_dotenv(APP_DIR / ".env")
load_dotenv(PROJECT_ROOT / ".env")


# -----------------------------
# App factory
# -----------------------------

def create_app() -> Flask:
    app = Flask(__name__)

    app.secret_key = os.getenv("FLASK_SECRET_KEY", "change-this-in-production")

    # IMPORTANT: using localhost because plumber runs manually
    model_api_base = os.getenv("MODEL_API_BASE", "http://host.docker.internal:8000")

    allowed_email_domain = os.getenv("ALLOWED_EMAIL_DOMAIN")

    app.config.update(
        SESSION_COOKIE_HTTPONLY=True,
        SESSION_COOKIE_SAMESITE="Lax",
        SESSION_COOKIE_SECURE=False,
    )


    # -----------------------------
    # Google OAuth setup
    # -----------------------------

    oauth = OAuth(app)

    oauth.register(
        name="google",
        server_metadata_url=os.getenv(
            "GOOGLE_DISCOVERY_URL",
            "https://accounts.google.com/.well-known/openid-configuration",
        ),
        client_id=os.getenv("GOOGLE_CLIENT_ID"),
        client_secret=os.getenv("GOOGLE_CLIENT_SECRET"),
        client_kwargs={"scope": "openid email profile"},
    )


    # -----------------------------
    # Login required decorator
    # -----------------------------

    def login_required(view):
        @wraps(view)
        def wrapped(*args, **kwargs):
            if "user" not in session:
                if request.path.startswith("/api/"):
                    return jsonify({"error": "Unauthorized"}), 401
                return redirect(url_for("login"))
            return view(*args, **kwargs)

        return wrapped


    # -----------------------------
    # Routes
    # -----------------------------

    @app.get("/")
    def index():
        return send_from_directory(str(DASHBOARD_DIR), "index.html")


    @app.get("/healthz")
    def healthz():
        return jsonify({"status": "ok"})


    # -----------------------------
    # Google Login
    # -----------------------------

    @app.get("/login")
    def login():

        if not os.getenv("GOOGLE_CLIENT_ID") or not os.getenv("GOOGLE_CLIENT_SECRET"):
            return "Google OAuth not configured", 500

        redirect_uri = url_for("auth_callback", _external=True)

        return oauth.google.authorize_redirect(redirect_uri)


    @app.get("/auth/callback")
    def auth_callback():

        token = oauth.google.authorize_access_token()

        user_info = token.get("userinfo")

        if not user_info:
            user_info = oauth.google.parse_id_token(token)

        email = (user_info or {}).get("email")

        if not email:
            return "Unable to read Google account email.", 400

        if allowed_email_domain:
            domain = email.split("@")[-1].lower()
            if domain != allowed_email_domain.lower():
                return "This account is not allowed.", 403

        session["user"] = {
            "email": email,
            "name": (user_info or {}).get("name", ""),
            "picture": (user_info or {}).get("picture", ""),
        }

        return redirect(url_for("index"))


    @app.get("/logout")
    def logout():
        session.clear()
        return redirect(url_for("index"))


    @app.get("/api/me")
    def me():

        user = session.get("user")

        if not user:
            return jsonify({"authenticated": False}), 401

        return jsonify({"authenticated": True, "user": user})


    # -----------------------------
    # Prediction endpoint (FIXED)
    # -----------------------------

    @app.post("/api/predict")
    @login_required
    def predict():

        try:

            payload = request.get_json(silent=True)

            if not payload:
                return jsonify({"error": "Request body must be JSON"}), 400

            response = requests.post(
                f"{model_api_base}/predict",
                json=payload,
                timeout=30,
            )

            response.raise_for_status()

            try:
                data = response.json()
            except ValueError:
                return jsonify({
                    "error": "Invalid JSON returned from model API"
                }), 502

            return jsonify(data), response.status_code


        except requests.RequestException as exc:

            app.logger.error(f"Plumber API error: {exc}")

            return jsonify({
                "error": "Model service unreachable",
                "message": str(exc)
            }), 502


        except Exception as exc:

            app.logger.exception("Unexpected error in /api/predict")

            return jsonify({
                "error": "Prediction proxy failed",
                "message": str(exc)
            }), 500


    return app


# -----------------------------
# Run app
# -----------------------------

app = create_app()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)