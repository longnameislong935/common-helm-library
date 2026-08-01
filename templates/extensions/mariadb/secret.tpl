{{- define "common-helm-library.extensions.mariadb.secret" }}
{{- /*
  Intentionally renders nothing.

  The MariaDB CR uses `rootPasswordSecretKeyRef ... generate: true`, so the
  operator CREATES and POPULATES the root-password secret itself. Pre-creating
  an empty secret here broke that: the operator won't write the key into a
  secret it didn't create, and ArgoCD kept self-healing it back to `data: {}`,
  wiping the generated password -> "couldn't find key root-password".

  Let the operator own the secret entirely. Nothing to render.
*/ -}}
{{- end }}