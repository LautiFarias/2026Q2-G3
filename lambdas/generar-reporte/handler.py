"""Lambda generar-reporte (PLACEHOLDER, mock data permitido por la consigna).

La invoca la API en ECS (lambda.invoke, síncrono) cuando un responsable de
sede pide el reporte de un rango de fechas. Arma un CSV y devuelve una
presigned URL de descarga. La consulta real a RDS queda simulada: conectar
un driver de PostgreSQL necesita una Lambda Layer (ver README del repo,
sección "Qué es placeholder").
"""
import csv
import io
import os
import uuid

import boto3

s3 = boto3.client("s3")


def handler(event, context):
    sede_id = event.get("sede_id") or "desconocida"
    desde = event.get("fecha_desde") or "sin-desde"
    hasta = event.get("fecha_hasta") or "sin-hasta"

    # PLACEHOLDER: acá iría "SELECT ... FROM auditoria WHERE sede_id = %s
    # AND fecha BETWEEN %s AND %s" contra RDS.
    filas_mock = [
        {"solicitud_id": 1873, "empresa_id": "42", "estado": "aprobada", "fecha": desde},
        {"solicitud_id": 1874, "empresa_id": "17", "estado": "rechazada", "fecha": hasta},
    ]

    buffer = io.StringIO()
    writer = csv.DictWriter(buffer, fieldnames=["solicitud_id", "empresa_id", "estado", "fecha"])
    writer.writeheader()
    writer.writerows(filas_mock)

    bucket = os.environ["AUDITORIA_BUCKET"]
    key = f"reportes/{sede_id}/{uuid.uuid4()}.csv"
    s3.put_object(Bucket=bucket, Key=key, Body=buffer.getvalue().encode("utf-8"), ContentType="text/csv")

    url = s3.generate_presigned_url(
        "get_object",
        Params={"Bucket": bucket, "Key": key},
        ExpiresIn=300,
    )

    return {"reporte_url": url, "filas": len(filas_mock)}
