#!/bin/sh

cat >> wp_core_install.sh << EOF
#!/bin/sh

dom_name='${DOMAIN_NAME}'
localhost='https://localhost:42443'

wp_admin='${WP_ADMIN}'
wp_admin_pass='${WP_ADMIN_PASS}'
wp_admin_mail='${WP_ADMIN_MAIL}'

wp_user='${WP_USER}'
wp_user_pass='${WP_USER_PASS}'
wp_user_mail='${WP_USER_MAIL}'

if ! wp core is-installed; then
    wp core install \\
        --url="\$localhost" \\
        --title="Inception" \\
        --admin_user="\$wp_admin" \\
        --admin_password="\$wp_admin_pass" \\
        --admin_email="\$wp_admin_mail"

    wp user create \\
        "\$wp_user" \\
	"\$wp_user_mail" \\
	--user_pass="\$wp_user_pass"
fi
EOF

cat >> entrypoint.sh << EOF
#!/bin/sh

sh wp_core_install.sh
rm wp_core_install.sh
exec "\$@"

EOF

chmod +x wp_core_install.sh entrypoint.sh
