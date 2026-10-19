# Módulo `network`

VPC en 3 capas (pública, aplicación, datos) x 2 zonas de disponibilidad, con
tablas de ruteo separadas por capa y una NACL sobre las subredes de datos.

## Uso

```hcl
module "network" {
  source      = "../modules/network"
  name_prefix = "accesoseguro-dev"
  vpc_cidr    = "10.0.0.0/16"
  azs         = ["us-east-1a", "us-east-1b"]
  tags        = local.common_tags
}
```

## Entradas principales

| Variable | Descripción | Default |
|---|---|---|
| `name_prefix` | Prefijo de nombre para los recursos | — |
| `vpc_cidr` | CIDR de la VPC (validado con `cidrhost`/`can`) | `10.0.0.0/16` |
| `azs` | Lista de 2 zonas de disponibilidad | — |
| `create_public_subnets` | Si es `false`, no crea IGW ni ruta pública | `true` |

## Salidas principales

`vpc_id`, `subnet_ids` (mapa completo), `public_subnet_ids`, `app_subnet_ids`,
`data_subnet_ids`, `app_route_table_id`, `datos_route_table_id`.
