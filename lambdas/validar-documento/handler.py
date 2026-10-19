"""Lambda validar-documento (PLACEHOLDER, mock data permitido por la consigna).

Dispara con cada mensaje de cola-documentos (un ObjectCreated del bucket de
documentos envuelto en SQS). Revisa tipo y tamaño y "marca" el documento en
RDS. La escritura a RDS está simulada: ver README, sección "Qué es
placeholder".
"""
import json
import logging
import os

logging.getLogger().setLevel(logging.INFO)

MAX_SIZE_MB = float(os.environ.get("DOCUMENTO_MAX_SIZE_MB", "5"))


def handler(event, context):
    resultados = []

    for record in event.get("Records", []):
        body = json.loads(record["body"])
        for s3_record in body.get("Records", []):
            key = s3_record["s3"]["object"]["key"]
            size_bytes = s3_record["s3"]["object"].get("size", 0)
            size_mb = size_bytes / (1024 * 1024)
            es_pdf = key.lower().endswith(".pdf")
            estado = "verificado" if es_pdf and size_mb <= MAX_SIZE_MB else "rechazado"

            # PLACEHOLDER: "UPDATE documentos SET estado = %s WHERE clave = %s" en RDS.
            logging.info("Documento %s -> %s (%.2f MB)", key, estado, size_mb)
            resultados.append({"key": key, "estado": estado})

    return {"procesados": resultados}
