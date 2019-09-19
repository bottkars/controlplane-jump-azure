curl "https://pcf.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}/download_root_ca_cert \
      -X GET \
      -H "Authorization: Bearer YOUR-UAA-ACCESS-TOKEN"



aliases:
      - domain: db.service.cf.internal
        targets:
        - deployment: control-plane
          domain: bosh
          instance_group: db
          network: ((network_name))
          query: '*'
      - domain: "_.pks.labbuildr.com"
      placeholder_type: index
      health_filter: all
