"""Lambda notificar-mail.

Dispara con cada mensaje de cola-notificaciones (suscripta al tópico SNS
eventos-solicitud). Elige la plantilla según el tipo de evento y manda el
mail con SES. El evento ya trae los datos del destinatario: no necesita
leer RDS.
"""
import json
import logging
import os
from collections import defaultdict

import boto3

ses = boto3.client("ses")
logging.getLogger().setLevel(logging.INFO)

SENDER = os.environ.get("SES_SENDER", "")

PLANTILLAS = {
    "nueva": "Tenés una solicitud pendiente de la empresa {empresa_id}.",
    "aprobada": "Tu solicitud fue aprobada: presentá tu DNI en la portería de la sede {sede_id}.",
    "rechazada": "Tu solicitud fue rechazada. Motivo: {motivo}",
    "vencida": "Tu permiso venció sin usarse; si todavía tenés que ir, pedí uno nuevo.",
}


def handler(event, context):
    enviados = 0

    for record in event.get("Records", []):
        sns_envelope = json.loads(record["body"])
        mensaje = sns_envelope.get("Message", sns_envelope)
        datos = json.loads(mensaje) if isinstance(mensaje, str) else mensaje

        tipo = datos.get("tipo_evento", "nueva")
        destinatario = datos.get("destinatario")
        plantilla = PLANTILLAS.get(tipo, "Hay novedades en tu solicitud de AccesoSeguro.")
        cuerpo = plantilla.format_map(defaultdict(str, datos))

        if not destinatario or not SENDER:
            logging.warning("Falta destinatario o remitente verificado; no se envía mail (tipo=%s)", tipo)
            continue

        ses.send_email(
            Source=SENDER,
            Destination={"ToAddresses": [destinatario]},
            Message={
                "Subject": {"Data": "AccesoSeguro: novedad en tu solicitud"},
                "Body": {"Text": {"Data": cuerpo}},
            },
        )
        enviados += 1

    return {"enviados": enviados}
