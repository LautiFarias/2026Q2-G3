"""Lambda auth-login: login/registro contra Cognito detrás del ALB.

El ALB reenvía /auth/* a esta función (target group de tipo lambda), sin API
Gateway. Rutas:
  POST /auth/login    {email, password}  -> tokens (InitiateAuth USER_PASSWORD_AUTH)
  POST /auth/signup   {email, password}  -> alta del usuario (Cognito manda el código por mail)
  POST /auth/confirm  {email, code}      -> confirma el código del mail
No va en la VPC: llega a Cognito por su endpoint público (las tasks de ECS sí
están aisladas, esta función no maneja datos de la base).
"""
import base64
import json
import os

import boto3
from botocore.exceptions import ClientError

cognito = boto3.client("cognito-idp")
CLIENT_ID = os.environ["COGNITO_CLIENT_ID"]
CORS_ORIGIN = os.environ.get("CORS_ALLOWED_ORIGIN", "*")


def _resp(status, body=None):
    return {
        "statusCode": status,
        "statusDescription": f"{status} OK" if status < 400 else f"{status} Error",
        "isBase64Encoded": False,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": CORS_ORIGIN,
            "Access-Control-Allow-Headers": "Authorization, Content-Type",
            "Access-Control-Allow-Methods": "POST, OPTIONS",
        },
        "body": json.dumps(body) if body is not None else "",
    }


def _json_body(event):
    raw = event.get("body") or "{}"
    if event.get("isBase64Encoded"):
        raw = base64.b64decode(raw).decode("utf-8")
    try:
        return json.loads(raw)
    except ValueError:
        return {}


def handler(event, context):
    method = event.get("httpMethod", "")
    path = event.get("path", "")

    if method == "OPTIONS":
        return _resp(204)
    if method != "POST":
        return _resp(405, {"error": "metodo no permitido"})

    data = _json_body(event)
    email = (data.get("email") or "").strip()

    try:
        if path.endswith("/login"):
            result = cognito.initiate_auth(
                ClientId=CLIENT_ID,
                AuthFlow="USER_PASSWORD_AUTH",
                AuthParameters={"USERNAME": email, "PASSWORD": data.get("password", "")},
            )
            tokens = result["AuthenticationResult"]
            return _resp(200, {
                "id_token": tokens["IdToken"],
                "access_token": tokens["AccessToken"],
                "expires_in": tokens["ExpiresIn"],
            })

        if path.endswith("/signup"):
            cognito.sign_up(
                ClientId=CLIENT_ID,
                Username=email,
                Password=data.get("password", ""),
                UserAttributes=[{"Name": "email", "Value": email}],
            )
            return _resp(200, {"mensaje": "registrado: revisa tu mail y confirma el codigo"})

        if path.endswith("/confirm"):
            cognito.confirm_sign_up(
                ClientId=CLIENT_ID,
                Username=email,
                ConfirmationCode=data.get("code", ""),
            )
            return _resp(200, {"mensaje": "confirmado"})

    except ClientError as exc:
        err = exc.response["Error"]
        return _resp(400, {"error": err.get("Code"), "mensaje": err.get("Message")})
    except KeyError:
        # Cognito pidió un desafío (ej. cambio de contraseña): no está soportado acá.
        return _resp(400, {"error": "ChallengeNoSoportado"})

    return _resp(404, {"error": "ruta no encontrada"})
