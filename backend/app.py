from flask import Flask, jsonify
from flask_cors import CORS
from config import Config
from extensions import init_supabase
from routes.auth import auth_bp
from routes.menu import menu_bp
from routes.orders import orders_bp
from routes.payments import payments_bp
from routes.ai import ai_bp
from routes.admin import admin_bp
from routes.postal import postal_bp
from routes.tables import tables_bp
from routes.riders import riders_bp


def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    CORS(app, resources={
        r"/api/*": {
            "origins": Config.FRONTEND_ORIGIN,
            "methods": ["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
            "allow_headers": ["Content-Type", "Authorization", "X-Session-Token"]
        }
    })

    init_supabase()

    app.register_blueprint(auth_bp,    url_prefix="/api/v1/auth")
    app.register_blueprint(menu_bp,    url_prefix="/api/v1/menu")
    app.register_blueprint(orders_bp,  url_prefix="/api/v1/orders")
    app.register_blueprint(payments_bp, url_prefix="/api/v1/payments")
    app.register_blueprint(ai_bp,      url_prefix="/api/v1/ai")
    app.register_blueprint(admin_bp,   url_prefix="/api/v1/admin")
    app.register_blueprint(postal_bp,  url_prefix="/api/v1/postal")
    app.register_blueprint(tables_bp,  url_prefix="/api/v1/tables")
    app.register_blueprint(riders_bp,  url_prefix="/api/v1/riders")

    @app.errorhandler(404)
    def not_found(e):
        return jsonify({"success": False, "message": "Route not found"}), 404

    @app.errorhandler(405)
    def method_not_allowed(e):
        return jsonify({"success": False, "message": "Method not allowed"}), 405

    @app.errorhandler(500)
    def internal_error(e):
        return jsonify({"success": False, "message": "Internal server error"}), 500

    @app.route("/health", methods=["GET"])
    def health():
        return jsonify({"success": True, "service": "restaurant-hybrid-backend", "status": "ok"}), 200

    return app


if __name__ == "__main__":
    application = create_app()
    application.run(debug=False, host="0.0.0.0", port=5000)
