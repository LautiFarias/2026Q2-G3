"""Lambda archivar-auditoria.

Dispara con cada mensaje de cola-auditoria (suscripta al tópico SNS
eventos-solicitud). Guarda la copia de respaldo de cada evento como un
archivo JSON en el bucket de auditoría. No toca RDS: la auditoría oficial
ya se guardó ahí en la misma transacción que generó el evento.
"""
import json
import logging
import os
import uuid

import boto3

s3 = boto3.client("s3")
logging.getLogger().setLevel(logging.INFO)

BUCKET = os.environ["AUDITORIA_BUCKET"]


def handler(event, context):
    guardados = 0

    for record in event.get("Records", []):
        sns_envelope = json.loads(record["body"])
        mensaje = sns_envelope.get("Message", sns_envelope)
        if isinstance(mensaje, str):
            contenido = mensaje.encode("utf-8")
        else:
            contenido = json.dumps(mensaje).encode("utf-8")

        key = f"auditoria/{uuid.uuid4()}.json"
        s3.put_object(Bucket=BUCKET, Key=key, Body=contenido, ContentType="application/json")
        guardados += 1
        logging.info("Evento archivado en %s", key)

    return {"guardados": guardados}
