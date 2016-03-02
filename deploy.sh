#!/usr/bin/env bash

source ../CIS-US-VIRGINIA-1-DEV-05-61696-openrc.sh

action=$1

case $action in

apply)
    echo "Pangea cluster provisioning started..."

    terraform apply \
        -var "auth_url=${OS_AUTH_URL}" \
        -var "tenant_name=${OS_TENANT_NAME}" \
        -var "user_name=${OS_USERNAME}" \
        -var "password=${OS_PASSWORD}" \
        -parallelism=2
    ;;

destroy)
    echo "Pangea cluster destroy..."

    terraform destroy \
        -var "auth_url=${OS_AUTH_URL}" \
        -var "tenant_name=${OS_TENANT_NAME}" \
        -var "user_name=${OS_USERNAME}" \
        -var "password=${OS_PASSWORD}"
    ;;

*)
    echo "Usage: $0 [apply | destroy]"
    ;;
esac