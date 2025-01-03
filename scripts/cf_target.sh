#!/bin/bash

## below are for standard output in script
Color_Off='\033[0m'       # Text Reset
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;93m'       # Yellow
Cyan='\033[0;36m'         # Cyan

function select_org () {

  ORGS=$(cf curl /v2/organizations | jq -r '.resources[].entity.name')
  declare -a CF_ORGS=(${ORGS})

  for index in ${!CF_ORGS[@]}; do
    printf "%4d: %s\n" $index ${CF_ORGS[$index]}
  done

  read -p 'Choose an org: ' org
  echo "You chose: ${CF_ORGS[$org]}"
  export CF_ORG=${CF_ORGS[$org]}
}

function select_space () {

  SPACES=$(cf curl /v2/organizations/$(cf org $CF_ORG --guid)/spaces | jq -r '.resources[].entity.name')
  declare -a CF_SPACES=(${SPACES} back)

  for index in ${!CF_SPACES[@]}; do
    printf "%4d: %s\n" $index ${CF_SPACES[$index]}
  done

  read -p 'Choose an space: ' space
  echo "You chose: ${CF_SPACES[$space]}"
  export CF_SPACE=${CF_SPACES[$space]}

  if [[ "$CF_SPACE" == "back" ]]; then
    select_org
    select_space
  fi
}

function select_app_or_service () {

  declare -a SELECT_APP_OR_SERVICE=(apps services back)

  for index in ${!SELECT_APP_OR_SERVICE[@]}; do
    printf "%4d: %s\n" $index ${SELECT_APP_OR_SERVICE[$index]}
  done

  read -p 'Choose: ' app_or_service 
  echo "You chose: ${SELECT_APP_OR_SERVICE[$app_or_service]}"
  export APP_OR_SERVICE=${SELECT_APP_OR_SERVICE[$app_or_service]}

  if [[ "$APP_OR_SERVICE" == "back" ]]; then
    select_space
    select_app_or_service
  elif [[ "$APP_OR_SERVICE" == "services" ]]; then
    fn_services
  fi
}

function fn_echo_apps () {
  # pretty print output for fn_services
  echo -e "${Cyan}$CF_ORG|$CF_SPACE|$service_name|$service_guid|$service_offering|$service_plan|$apps${Color_Off}"
}

function fn_services () {
  (
  echo -e "${Yellow}Organization|Space|Service|Service GUID|Service_Offering|Service_Plan|Applicaton(s)${Color_Off}"
  echo -e "${Yellow}============|=====|=======|============|================|============|=============${Color_Off}"
  service_instance_url=$(cf curl /v2/organizations/$(cf org $CF_ORG --guid)/spaces | jq -r '.resources[] | select(.entity.name == "'"$CF_SPACE"'") .entity.service_instances_url')
  services=$(cf curl $service_instance_url | jq -r '.resources[].entity | "\(.name):\(.service_guid):\(.service_url):\(.service_plan_url):\(.service_bindings_url)"')
  for service in $services; do
    service_name=$(echo $service | cut -d ':' -f1)
    service_guid=$(echo $service | cut -d ':' -f2)
    service_offering=$(cf curl $(echo $service | cut -d ':' -f3) | jq -r '.entity.label')
    service_plan=$(cf curl $(echo $service | cut -d ':' -f4) | jq -r '.entity.name')
    app_guids=$(cf curl $(echo $service | cut -d ':' -f5) | jq -r '.resources[].entity.app_guid')
    declare -a app_names=("")
    for app_guid in $app_guids; do
      app_name=$(cf curl /v2/apps/$app_guid | jq -r '.entity.name')
      app_names+=($app_name)
    done
    apps=$(printf '%s\n' "${app_names[@]}" | jq -R . | jq -sr 'join(",")' | cut -d ',' -f2-)
    if [[ $1 == "crunchy" ]] && [[ $service_offering == "postgresql-11-odb" ]]; then
      fn_echo_apps
    elif [[ $1 == "vmwarepg" ]] && [[ $service_offering == "postgres" ]]; then
      fn_echo_apps
    elif [[ $1 == "mysql" ]] && [[ $service_offering == *"mysql"* ]]; then
      fn_echo_apps
    elif [[ $1 == "redis" ]] && [[ $service_offering == *"redis"* ]]; then
      fn_echo_apps
    elif [[ $1 == "rabbitmq" ]] && [[ $service_offering == *"rabbitmq"* ]]; then
      fn_echo_apps
    elif [[ $1 == "all" ]] || [[ -z $1 ]]; then
      fn_echo_apps
    fi
  done
  ) | column -t -s '|'
}

select_org
select_space
select_app_or_service

#cf t -o $CF_ORG -s $CF_SPACE
#cf $APP_OR_SERVICE
