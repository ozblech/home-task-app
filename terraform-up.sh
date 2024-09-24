#!/bin/bash

operation="apply"

while [[ "$1" != "" ]]; do
    case $1 in
    --destroy )          operation="destroy"
                             ;;
        * )                  echo "Invalid parameter: $1"
                             exit 1
    esac
    shift
done


if [ "$operation" != "destroy" ]; then
        echo -e "\033[1;32m********** ${operation^} **********\033[0m"
        make init
        make $operation
fi
if [ "$operation" == "destroy" ]; then
        echo -e "\033[1;32m********** ${operation^}  **********\033[0m"
        make init
        make $operation
fi