"""API de AccesoSeguro.

Placeholder funcional (mock data en memoria, permitido por la consigna):
suficiente para justificar la arquitectura y que el pipeline/infra se
puedan probar de punta a punta. Falta conectar RDS de verdad (ver
README, sección "Qué es placeholder").

Variables de entorno: todas las inyecta ECS desde Terraform
(ver local.api_environment en infra/locals.tf).
"""
import base64
import datetime
import json
import os
import time
import uuid
from functools import wraps

import boto3
from flask import Flask, jsonify, request

app = Flask(__name__)
lambda_client = boto3.client("lambda", region_name=os.environ.get("COGNITO_REGION", "us-east-1"))

# "Base de datos" en memoria: placeholder hasta conectar RDS de verdad.
_SOLICITUDES = {}


def _decode_jwt_sin_verificar(token):
    """PLACEHOLDER: decodifica el payload del JWT sin validar la firma.

    En producción hay que validar firma, emisor y vencimiento contra las
    claves públicas (JWKS) del User Pool de Cognito, como describe el PDF
    de arquitectura (sección "Seguridad en cada pedido").
    """
    try:
        payload_b64 = token.split(".")[1]
        padding = "=" * (-len(payload_b64) % 4)
        payload = base64.urlsafe_b64decode(payload_b64 + padding)
        return json.loads(payload)
    except Exception:
        return None


def requiere_token(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        auth = request.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            return jsonify(error="falta token"), 401
        claims = _decode_jwt_sin_verificar(auth[len("Bearer "):])
        if not claims:
            return jsonify(error="token invalido"), 401
        if claims.get("exp", 0) < time.time():
            return jsonify(error="token vencido"), 401
        request.usuario = claims
        return f(*args, **kwargs)

    return wrapper


def requiere_grupo(*grupos):
    def decorador(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            claims = getattr(request, "usuario", {})
            grupos_usuario = claims.get("cognito:groups", [])
            if grupos and not any(g in grupos_usuario for g in grupos):
                return jsonify(error="no autorizado para este grupo"), 403
            return f(*args, **kwargs)

        return wrapper

    return decorador


@app.after_request
def cors(resp):
    resp.headers["Access-Control-Allow-Origin"] = os.environ.get("CORS_ALLOWED_ORIGIN", "*")
    resp.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type"
    resp.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
    return resp


@app.get("/health")
def health():
    return jsonify(status="ok")


@app.get("/api/info")
def info():
    return jsonify(
        app="AccesoSeguro",
        env=os.environ.get("APP_ENV"),
        db_host_configurado=bool(os.environ.get("DB_HOST")),
        cognito_pool=os.environ.get("COGNITO_USER_POOL_ID"),
    )


@app.get("/api/solicitudes")
@requiere_token
def listar_solicitudes():
    empresa_id = request.usuario.get("custom:empresa_id")
    grupos = request.usuario.get("cognito:groups", [])
    if "responsables_sede" in grupos or "porteria" in grupos:
        items = list(_SOLICITUDES.values())
    else:
        items = [s for s in _SOLICITUDES.values() if s["empresa_id"] == empresa_id]
    return jsonify(items)


@app.post("/api/solicitudes")
@requiere_token
def crear_solicitud():
    empresa_id = request.usuario.get("custom:empresa_id")
    if not empresa_id:
        return jsonify(error="tu usuario todavia no tiene una empresa asignada"), 403

    data = request.get_json(force=True, silent=True) or {}
    solicitud_id = str(uuid.uuid4())
    _SOLICITUDES[solicitud_id] = {
        "id": solicitud_id,
        "empresa_id": empresa_id,
        "sede_id": data.get("sede_id"),
        "motivo": data.get("motivo"),
        "estado": "pendiente",
        "creada": datetime.datetime.utcnow().isoformat(),
    }
    return jsonify(_SOLICITUDES[solicitud_id]), 201


@app.post("/api/solicitudes/<solicitud_id>/aprobar")
@requiere_token
@requiere_grupo("responsables_sede")
def aprobar_solicitud(solicitud_id):
    solicitud = _SOLICITUDES.get(solicitud_id)
    if not solicitud:
        return jsonify(error="no existe"), 404
    solicitud["estado"] = "aprobada"
    return jsonify(solicitud)


@app.get("/api/reportes")
@requiere_token
@requiere_grupo("responsables_sede")
def generar_reporte():
    nombre_lambda = os.environ.get("LAMBDA_REPORTES_NAME")
    if not nombre_lambda:
        return jsonify(error="la lambda de reportes no esta configurada"), 500

    payload = {
        "sede_id": request.args.get("sede_id"),
        "fecha_desde": request.args.get("desde"),
        "fecha_hasta": request.args.get("hasta"),
    }
    respuesta = lambda_client.invoke(
        FunctionName=nombre_lambda,
        InvocationType="RequestResponse",
        Payload=json.dumps(payload).encode("utf-8"),
    )
    resultado = json.loads(respuesta["Payload"].read())
    return jsonify(resultado)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "5000")))
