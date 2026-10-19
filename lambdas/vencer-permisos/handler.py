"""Lambda vencer-permisos (PLACEHOLDER, mock data permitido por la consigna).

La dispara EventBridge cada 15 minutos (reemplaza lo que hoy se corre a
mano). Marcaría como vencidas las solicitudes aprobadas y no usadas a
tiempo, y publica el evento en SNS para que notificar-mail avise. La
consulta/escritura en RDS está simulada: ver README, "Qué es placeholder".
"""
import datetime
import json
import logging
import os

import boto3

sns = boto3.client("sns")
logging.getLogger().setLevel(logging.INFO)

TOPIC_ARN = os.environ["SNS_EVENTOS_TOPIC_ARN"]


def handler(event, context):
    ahora = datetime.datetime.utcnow().isoformat()

    # PLACEHOLDER: "SELECT ... FROM solicitudes WHERE estado = 'aprobada'
    # AND vence_el < now()" contra RDS. Se simula un resultado para probar
    # el flujo de punta a punta.
    vencidas_mock = [
        {"solicitud_id": 1875, "empresa_id": "42", "transportista_mail": "transportista@ejemplo.com"},
    ]

    publicadas = 0
    for solicitud in vencidas_mock:
        sns.publish(
            TopicArn=TOPIC_ARN,
            Message=json.dumps(
                {
                    "tipo_evento": "vencida",
                    "solicitud_id": solicitud["solicitud_id"],
                    "empresa_id": solicitud["empresa_id"],
                    "destinatario": solicitud["transportista_mail"],
                    "timestamp": ahora,
                }
            ),
        )
        publicadas += 1

    logging.info("vencer-permisos corrió a las %s, publicó %d eventos", ahora, publicadas)
    return {"vencidas": publicadas}
