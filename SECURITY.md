# Política de Seguridad

## Reporte responsable de vulnerabilidades

Si encuentras una vulnerabilidad de seguridad en este proyecto, repórtala de forma responsable contactando al mantenedor (por ejemplo, vía mensaje directo) o abriendo un issue solicitando un canal privado.

Este proyecto:

- NO almacena credenciales.
- NO requiere Access Keys dentro del código.
- NO persiste información sensible de Billing.
- Opera en modo **solo lectura** usando AWS Cost Explorer.

Responsabilidad del usuario:

- Proteger sus credenciales y perfiles AWS (AWS_PROFILE / SSO / credenciales temporales).
- Usar IAM con principio de mínimo privilegio.
- Evitar subir archivos de salida (CSV/JSON/logs) con datos internos.

Permisos IAM mínimos recomendados:

- ce:GetCostAndUsage
- sts:GetCallerIdentity

Gracias por ayudar a mantener este proyecto seguro.
